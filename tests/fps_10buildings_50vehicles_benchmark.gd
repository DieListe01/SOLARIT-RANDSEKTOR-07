extends SceneTree

## Local scale benchmark: 10 buildings and 50 mixed vehicles, normal Vulkan renderer.
const WARMUP_FRAMES := 900
const SAMPLE_FRAMES := 900
const MAX_CACHE_WARM_PASSES := 8
var cache_warm_pass_limit := MAX_CACHE_WARM_PASSES
const WARM_CHECK_FRAMES := 90
var game: Control
var benchmark_factions: Array[String]=[]
var side_units: Array = [[],[],[],[]]
var trace_lines: Array[String] = []
var benchmark_contract_failed := false
var summary_lines: Array[String] = ["variant,frames,fps,avg_frame_ms,1pct_worst_frame_ms,max_frame_ms,visible_vehicles,entities,projectiles,effects,particles,wrecks,tracks,pose_hits,pose_misses,poses_created,poses_recreated,readbacks,cache_size,active_subviewports,production_preview_views,moving_vehicles_min,moving_vehicles_avg,motion_active_percent,world_ms,terrain_ms,buildings_ms,vehicles_ms,wrecks_ms,combat_vfx_ms,projectiles_render_ms,impacts_render_ms,explosions_render_ms,smoke_render_ms,tracks_render_ms,fog_ms,hud_ms,simulation_ms,pathfinding_ms,separation_ms,target_search_ms,combat_ms,movement_ms,projectile_sim_ms,ai_ms,draw_calls,primitives,phase_setup_ms,phase_ground_ms,phase_cull_sort_ms,phase_entities_ms,phase_combat_and_fog_ms,phase_overlays_ms,phase_post_ms,phase_unattributed_ms,visible_track_segments_avg,pose_queue_peak,pose_queue_end,pending_keys_end,stale_drops,fallback_lookups,fallback_memo_hits,fallback_candidates,fallback_empty,procedural_fallbacks,fallback_lookup_ms,evictions,readbacks_during_sample,cache_generation_frozen,frames_over_33ms,frames_over_50ms,frames_over_100ms,retained_viewports,video_mem_mb"]

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		suppress_low_fps_logging()

func suppress_low_fps_logging() -> void:
	if not is_instance_valid(game): return
	game.low_fps_seconds=0.0
	game.low_fps_critical_seconds=0.0
	game.low_fps_active=false
	game.fps_auto_profile=false
	game.renderer.profile_enabled=true

func reset_world() -> void:
	game.paused=true
	game.renderer.visual_paused=true
	game.sim.profile_enabled=true
	game.renderer.profile_enabled=true
	game.renderer.benchmark_disabled_categories.clear()
	game.renderer.benchmark_vfx_tier_floor=-1
	game.renderer.benchmark_vfx_tier_override=0
	game.renderer.benchmark_track_cap=1800
	game.renderer.benchmark_track_min_distance=3.0
	game.renderer.benchmark_track_lifetime=50.0
	game.renderer.benchmark_compact_wrecks=false
	game.renderer.selected.clear()
	game.renderer.elapsed=0.0
	game.renderer.health_mode="damaged"
	game.sim.configure_versus({"host_faction":str(benchmark_factions[0]),"client_faction":str(benchmark_factions[1]),"start_credits":20000},0)
	game.sim.online_mode=""
	game.sim.path_requests.clear()
	game.sim.projectiles.clear(); game.sim.effects.clear()
	game.renderer.combat_fx.reset()
	game.renderer.tracks.clear(); game.renderer.visual_bursts.clear()
	game.renderer.previous_positions.clear(); game.renderer.previous_speeds.clear()
	game.renderer.track_timer=0.0; game.renderer.track_age_timer=0.0
	game.sim.known=[{},{}]
	for owner in 2:
		game.sim.fog[owner].fill(0)
		game.sim.explored[owner].fill(0)
	var center:=Vector2(game.sim.grid.width*game.sim.grid.tile*0.5,game.sim.grid.height*game.sim.grid.tile*0.5)
	game.renderer.camera=center
	game.renderer.zoom=0.92
	game.sim.db.mission["ai_enabled"]=false
	game.sim.time=0.0; game.sim.result=""; game.sim.ai_timer=999999.0
	game.sim.rng.seed=731904
	game.renderer.combat_fx.visual_rng.seed=731904
	side_units=[[],[],[],[]]
	# The catalog has eight building archetypes. Keep the two required cores and add one of each available non-core type, plus a second power plant.
	var building_kinds: Array[String]=["power","refinery","factory","tower","radar","repair","armory","power"]
	for i in building_kinds.size():
		var cell:=Vector2i(16+(i%4)*8,12 if i<4 else 50)
		game.sim.spawn(building_kinds[i],i%2,game.sim.grid.center(cell),true)
	# configure_versus supplies one scout per side; add 24 mixed units per side for exactly 50 total mobile vehicles.
	for unit in game.sim.entities.values():
		if not unit.building:
			side_units[int(unit.owner)*2].append(int(unit.id))
	var unit_kinds: Array[String]=["scout","tank","siege","harvester","raider","lancer","scorcher","bulwark"]
	for owner in 2:
		var side_sign:= -1.0 if owner==0 else 1.0
		for i in 24:
			var kind:=unit_kinds[posmod(i+owner*4,unit_kinds.size())]
			var row:=float(i/5)-2.0
			var column:=float(i%5)-2.0
			var p:=center+Vector2(side_sign*355.0+column*34.0,row*48.0)
			var id: int=game.sim.spawn(kind,owner,p,false)
			if id>0:
				side_units[owner*2+(1 if i>=12 else 0)].append(id)
				var unit: Dictionary=game.sim.entities[id]
				unit.max_hp=50000.0; unit.hp=50000.0
		for squad in range(owner*2,owner*2+2):
			var squad_offset:= -100.0 if squad%2==0 else 100.0
			game.sim.command(side_units[squad],center+Vector2(-side_sign*300.0,squad_offset),"attack_move")
	game.sim.update_fog(false)
	for i in 39:
		var wreck_pos:=center+Vector2(-520.0+float(i%13)*86.0,-330.0+float(i/13)*330.0)
		game.renderer.combat_fx.ruins.append({"pos":wreck_pos,"building":false,"core":false,"angle":float(i)*0.37,"age":24.0,"radius":21.0,"variant":i%4,"object_kind":"tank","footprint":[1,1]})
	game.sim.rebuild_movement_buckets()
	game.accumulator=0.0
	game.paused=false
	game.renderer.visual_paused=false
	game.renderer.queue_redraw()
func retask_if_needed(next_order_time: float) -> float:
	if game.sim.time<next_order_time: return next_order_time
	var phase:=int(floor(game.sim.time/4.0))
	var y_offset:= -145.0 if phase%2==0 else 145.0
	for squad in 4:
		var owner:=int(squad/2)
		var sign_value:= -1.0 if owner==0 else 1.0
		var squad_offset:= -90.0 if squad%2==0 else 90.0
		var destination: Vector2=game.renderer.camera+Vector2(-sign_value*300.0,y_offset+squad_offset)
		# Attack-move correctly stops vehicles to fight once they reach weapon
		# range. Keep half the groups on attack-move for live combat while the
		# other half use move orders and continue crossing the battle. Swap roles
		# on each re-task so all four groups make sustained direction changes.
		var order: String="attack_move" if (phase+squad)%2==0 else "move"
		game.sim.command(side_units[squad],destination,order)
	return next_order_time+4.0

func wait_pose_cache(label: String) -> void:
	for pass_index in cache_warm_pass_limit:
		var old_misses: int=game.renderer.vehicle_cache_misses_total
		var old_created: int=game.renderer.vehicle_cache_new_poses_total
		await settle(WARM_CHECK_FRAMES)
		var queued: int=game.renderer.vehicle_cache_queue.size()
		var in_flight: int=1 if game.renderer.vehicle_cache_worker_active else 0
		var misses: int=game.renderer.vehicle_cache_misses_total-old_misses
		var created: int=game.renderer.vehicle_cache_new_poses_total-old_created
		print("MOVE_WARM %s pass=%d created=%d misses=%d queued=%d in_flight=%d pending_keys=%d entries=%d"%[label,pass_index+1,created,misses,queued,in_flight,game.renderer.pending_pose_keys.size(),game.renderer.vehicle_texture_cache.size()])
		if queued==0 and in_flight==0 and misses==0 and created==0: return

func warm_moving_scenario(label: String) -> void:
	var next_order_time: float=game.sim.time+0.1
	for frame in WARMUP_FRAMES:
		next_order_time=retask_if_needed(next_order_time)
		await process_frame
		suppress_low_fps_logging()
		if frame%90==89: print("MOVE_WARMUP %s frame=%d/%d mission_time=%.1f visible=%d moving=%d queued=%d pending_keys=%d in_flight=%s"%[label,frame+1,WARMUP_FRAMES,game.sim.time,game.renderer.visible_mobile_count,game.sim.entities.values().filter(func(e): return not e.building and e.velocity.length()>2.0).size(),game.renderer.vehicle_cache_queue.size(),game.renderer.pending_pose_keys.size(),game.renderer.vehicle_cache_worker_active])

func percentile_worst_1pct(frames: Array[float]) -> float:
	var sorted:=frames.duplicate()
	sorted.sort()
	var count:=maxi(1,ceili(float(sorted.size())*0.01))
	var total:=0.0
	for i in range(sorted.size()-count,sorted.size()): total+=sorted[i]
	return total/float(count)

func capture_quality_image(name: String) -> void:
	await process_frame
	var image:=game.get_viewport().get_texture().get_image()
	image.save_png("res://test-output/moving_%s.png"%name)

func apply_treatment(treatment: String) -> void:
	match treatment:
		"adaptive": game.renderer.benchmark_vfx_tier_override=-1
		"vfx": game.renderer.benchmark_vfx_tier_override=1
		"live_cache_256":
			game.renderer.vehicle_cache_resolution=256
			game.renderer.vehicle_cache_msaa=Viewport.MSAA_DISABLED
		"live_cache_256_prewarmed":
			game.renderer.vehicle_cache_resolution=256
			game.renderer.vehicle_cache_msaa=Viewport.MSAA_DISABLED
		"live_cache_384":
			game.renderer.vehicle_cache_resolution=384
			game.renderer.vehicle_cache_msaa=Viewport.MSAA_2X
		"tracks":
			game.renderer.benchmark_track_cap=900
			game.renderer.benchmark_track_min_distance=7.0
			game.renderer.benchmark_track_lifetime=30.0
		"wrecks": game.renderer.benchmark_compact_wrecks=true
		"terrain_base_off": game.renderer.benchmark_disabled_categories.append("terrain_base")
		"track_visibility_count": game.renderer.benchmark_track_visibility_diagnostics=true
		"combined":
			game.renderer.benchmark_vfx_tier_override=1
			game.renderer.benchmark_track_cap=900
			game.renderer.benchmark_track_min_distance=7.0
			game.renderer.benchmark_track_lifetime=30.0
			game.renderer.benchmark_compact_wrecks=true

func run_variant(label: String, treatment: String) -> void:
	var live_cache_diagnostic := treatment.begins_with("live_cache")
	game.renderer.vehicle_cache_generation_frozen=false
	await reset_world()
	apply_treatment(treatment)
	var baseline_only:=OS.get_cmdline_user_args().has("--baseline-only")
	if baseline_only: game.renderer.freeze_vehicle_pose_generation(true)
	await warm_moving_scenario(label)
	if baseline_only:
		print("MOVE_WARM %s baseline-only: generated no moving/combat poses"%label)
	else:
		await wait_pose_cache(label)
	# Exercise the production path: misses stay on the nearest cached texture;
	# active gameplay never starts an expensive pose SubViewport render.
	# Compare the current behavior against an otherwise identical control where
	# active pose generation is explicitly allowed.
	var active_bakes_allowed:=OS.get_cmdline_user_args().has("--allow-active-pose-bakes")
	if not active_bakes_allowed:
		game.renderer.freeze_vehicle_pose_generation(true)
		for _frame in 60:
			if not game.renderer.vehicle_cache_worker_active: break
			await process_frame
		if game.renderer.vehicle_cache_worker_active or not game.renderer.vehicle_cache_queue.is_empty() or not game.renderer.pending_pose_keys.is_empty():
			benchmark_contract_failed=true
			push_error("POSE-CACHE WARMUP FAILED %s: work remained after cache freeze"%label)
	# Pose generation is warmed above. Restore the exact same opening state before every sample.
	await reset_world()
	apply_treatment(treatment)
	# The world object is fresh after reset. Run an identical stabilization window
	# before timing so resource/state initialization does not contaminate the tail.
	await settle(30)
	var next_order_time: float=game.sim.time+0.1
	game.renderer.vehicle_cache_hits=0; game.renderer.vehicle_cache_misses=0
	var old_created: int=game.renderer.vehicle_cache_new_poses_total
	var old_recreated: int=game.renderer.vehicle_cache_recreated_poses_total
	var old_readbacks: int=game.renderer.vehicle_cache_readbacks_total
	var old_building_readbacks: int=game.renderer.building_cache_readbacks_total
	var starting_created:=old_created
	var old_readback_ms: float=game.renderer.vehicle_cache_readback_ms_total
	var old_building_readback_ms: float=game.renderer.building_cache_readback_ms_total
	var old_completion_latency_ms: float=game.renderer.vehicle_cache_completion_latency_ms_total
	var old_fallback_lookups: int=game.renderer.vehicle_cache_fallback_lookups_total
	var old_fallback_memo_hits: int=game.renderer.vehicle_cache_fallback_index_hits_total
	var old_fallback_candidates: int=game.renderer.vehicle_cache_fallback_candidates_examined_total
	var old_fallback_empty: int=game.renderer.vehicle_cache_fallback_empty_total
	var old_procedural_fallbacks: int=game.renderer.vehicle_cache_procedural_fallback_total
	var old_fallback_lookup_us: int=game.renderer.vehicle_cache_fallback_search_usec_total
	var old_evictions: int=game.renderer.vehicle_cache_evictions_total
	var old_stale_drops: int=game.renderer.vehicle_cache_stale_requests_dropped_total
	game.renderer.vehicle_cache_queue_peak=0
	game.renderer.vehicle_cache_peak_subviewports=0
	var previous:=Time.get_ticks_usec()
	var frames: Array[float]=[]
	var minimum_moving_vehicles:=40
	var total_moving_vehicles:=0
	var active_motion_frames:=0
	var frames_over_33ms:=0
	var frames_over_50ms:=0
	var frames_over_100ms:=0
	var vram_mb_sum:=0.0
	var vram_samples:=0
	var visible_track_segment_sum:=0
	var track_segment_sum:=0
	var sums: Array[float]=[]
	for _column in 31: sums.append(0.0)
	var total_misses:=0; var total_hits:=0; var total_readbacks:=0; var max_created_per_frame:=0
	for sample_index in SAMPLE_FRAMES:
		next_order_time=retask_if_needed(next_order_time)
		await process_frame
		suppress_low_fps_logging()
		var now:=Time.get_ticks_usec()
		var frame_ms:=float(now-previous)/1000.0
		previous=now
		frames.append(frame_ms)
		if frame_ms>33.333: frames_over_33ms+=1
		if frame_ms>50.0: frames_over_50ms+=1
		if frame_ms>100.0: frames_over_100ms+=1
		var video_mem_bytes:=float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		if video_mem_bytes>0.0: vram_mb_sum+=video_mem_bytes/1048576.0; vram_samples+=1
		var r=game.renderer; var s=game.sim
		visible_track_segment_sum+=int(r.profile_track_segments_in_view)
		track_segment_sum+=r.tracks.size()
		var moving_vehicles: int=s.entities.values().filter(func(e): return not e.building and e.velocity.length()>2.0).size()
		minimum_moving_vehicles=mini(minimum_moving_vehicles,moving_vehicles)
		total_moving_vehicles+=moving_vehicles
		if moving_vehicles>=8: active_motion_frames+=1
		var hits:=int(r.vehicle_cache_hits); var misses:=int(r.vehicle_cache_misses)
		var created:=int(r.vehicle_cache_new_poses_total-old_created)
		var recreated:=int(r.vehicle_cache_recreated_poses_total-old_recreated)
		var building_readbacks:=int(r.building_cache_readbacks_total-old_building_readbacks)
		var readbacks:=int(r.vehicle_cache_readbacks_total-old_readbacks)+building_readbacks
		max_created_per_frame=maxi(max_created_per_frame,created)
		total_hits+=hits; total_misses+=misses; total_readbacks+=readbacks
		var vals: Array[float]=[
			r.profile_total_ms,r.profile_terrain_ms,r.profile_buildings_ms,r.profile_vehicles_ms,r.profile_wrecks_ms,
			r.profile_combat_fx_ms,r.profile_projectiles_ms,r.profile_impacts_ms,r.profile_explosions_ms,r.profile_smoke_ms,
			r.profile_tracks_ms,r.profile_fog_ms,r.profile_ui_ms,r.profile_sim_ms,s.profile_pathfinding_ms,
			s.profile_separation_ms,s.profile_target_search_ms,s.profile_combat_ms,s.profile_movement_ms,s.profile_projectile_sim_ms,
			s.profile_ai_ms,float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			r.profile_phase_setup_ms,r.profile_phase_ground_ms,r.profile_phase_cull_sort_ms,r.profile_phase_entities_ms,
			r.profile_phase_combat_ms,r.profile_phase_overlays_ms,r.profile_phase_post_ms,r.profile_phase_unattributed_ms]
		for vi in vals.size(): sums[vi]+=vals[vi]
		var counts: Array[int]=[r.visible_mobile_count,s.entities.size(),s.projectiles.size(),s.effects.size(),r.combat_fx.particles.size(),r.combat_fx.ruins.size(),r.tracks.size(),hits,misses,created,recreated,readbacks,moving_vehicles]
		var row: Array[String]=[label,str(sample_index),"%.3f"%frame_ms]
		row.append_array(format_floats(vals))
		for count_index in 12: row.append(str(counts[count_index]))
		var readback_ms: float=(r.vehicle_cache_readback_ms_total-old_readback_ms)+(r.building_cache_readback_ms_total-old_building_readback_ms)
		var building_readback_ms: float=r.building_cache_readback_ms_total-old_building_readback_ms
		var completion_latency_ms: float=r.vehicle_cache_completion_latency_ms_total-old_completion_latency_ms
		row.append("%.4f"%readback_ms); row.append(str(building_readbacks)); row.append("%.4f"%building_readback_ms); row.append("%.4f"%completion_latency_ms)
		row.append(str(r.vehicle_texture_cache.size())); row.append(str(r.vehicle_cache_active_subviewports))
		row.append(str(r.production_preview_cache.viewports.size() if r.production_preview_cache!=null else 0))
		row.append(str(counts[12]))
		row.append(str(r.profile_track_segments_in_view))
		trace_lines.append(",".join(row))
		old_created=r.vehicle_cache_new_poses_total; old_recreated=r.vehicle_cache_recreated_poses_total; old_readbacks=r.vehicle_cache_readbacks_total
		old_readback_ms=r.vehicle_cache_readback_ms_total; old_building_readbacks=r.building_cache_readbacks_total
		old_building_readback_ms=r.building_cache_readback_ms_total; old_completion_latency_ms=r.vehicle_cache_completion_latency_ms_total
	var frame_total:=0.0; var max_frame:=0.0
	for x in frames: frame_total+=x; max_frame=maxf(max_frame,x)
	var avg:=frame_total/frames.size()
	var average_moving_vehicles:=float(total_moving_vehicles)/float(frames.size())
	var motion_active_percent:=100.0*float(active_motion_frames)/float(frames.size())
	if motion_active_percent<80.0:
		benchmark_contract_failed=true
		push_error("MOVING BATTLE CONTRACT FAILED %s: only %.1f%% of samples had at least 8 moving vehicles (minimum %d, average %.1f)"%[label,motion_active_percent,minimum_moving_vehicles,average_moving_vehicles])
	var preview_view_count: int=game.renderer.production_preview_cache.viewports.size() if game.renderer.production_preview_cache!=null else 0
	var counts_summary: Array[int]=[game.renderer.visible_mobile_count,game.sim.entities.size(),game.sim.projectiles.size(),game.sim.effects.size(),game.renderer.combat_fx.particles.size(),game.renderer.combat_fx.ruins.size(),game.renderer.tracks.size(),total_hits,total_misses,game.renderer.vehicle_cache_new_poses_total-starting_created,game.renderer.vehicle_cache_recreated_poses_total-old_recreated,total_readbacks,game.renderer.vehicle_texture_cache.size(),game.renderer.vehicle_cache_active_subviewports,preview_view_count]
	var created_poses: int=game.renderer.vehicle_cache_new_poses_total-starting_created
	if not OS.get_cmdline_user_args().has("--allow-active-pose-bakes") and (total_readbacks!=0 or created_poses!=0 or max_created_per_frame>0 or max_frame>100.0):
		benchmark_contract_failed=true
		push_error("LIVE POSE-CACHE CONTRACT FAILED %s: poses=%d poses_per_frame=%d readbacks=%d max_frame=%.3fms"%[label,created_poses,max_created_per_frame,total_readbacks,max_frame])
	if OS.get_cmdline_user_args().has("--live-prewarmed-256") and (created_poses!=0 or max_created_per_frame!=0):
		benchmark_contract_failed=true
		push_error("PREWARMED LIVE-CACHE CONTRACT FAILED %s: expected zero active-play pose bakes, got %d (max per frame %d)"%[label,created_poses,max_created_per_frame])
	var fallback_lookups: int=game.renderer.vehicle_cache_fallback_lookups_total-old_fallback_lookups
	var fallback_memo_hits: int=game.renderer.vehicle_cache_fallback_index_hits_total-old_fallback_memo_hits
	var fallback_candidates: int=game.renderer.vehicle_cache_fallback_candidates_examined_total-old_fallback_candidates
	var fallback_empty: int=game.renderer.vehicle_cache_fallback_empty_total-old_fallback_empty
	var procedural_fallbacks: int=game.renderer.vehicle_cache_procedural_fallback_total-old_procedural_fallbacks
	var fallback_lookup_ms:=float(game.renderer.vehicle_cache_fallback_search_usec_total-old_fallback_lookup_us)/1000.0
	var evictions: int=game.renderer.vehicle_cache_evictions_total-old_evictions
	var stale_drops: int=game.renderer.vehicle_cache_stale_requests_dropped_total-old_stale_drops
	var queue_end: int=game.renderer.vehicle_cache_queue.size()
	var pending_end: int=game.renderer.pending_pose_keys.size()
	if not OS.get_cmdline_user_args().has("--allow-active-pose-bakes") and (queue_end!=0 or pending_end!=0 or not game.renderer.vehicle_cache_generation_frozen):
		benchmark_contract_failed=true
		push_error("FROZEN CACHE CONTRACT FAILED %s: queue=%d pending=%d frozen=%s"%[label,queue_end,pending_end,game.renderer.vehicle_cache_generation_frozen])
	var averages: Array[float]=[]
	for i in 31: averages.append(sums[i]/frames.size())
	var summary: Array[String]=[label,str(SAMPLE_FRAMES),"%.2f"%(1000.0/avg),"%.3f"%avg,"%.3f"%percentile_worst_1pct(frames),"%.3f"%max_frame]
	for n in counts_summary: summary.append(str(n))
	summary.append(str(minimum_moving_vehicles)); summary.append("%.2f"%average_moving_vehicles); summary.append("%.2f"%motion_active_percent)
	for v in averages: summary.append("%.4f"%v)
	summary.append("%.2f"%(float(visible_track_segment_sum)/float(frames.size())))
	summary.append(str(game.renderer.vehicle_cache_queue_peak)); summary.append(str(queue_end)); summary.append(str(pending_end)); summary.append(str(stale_drops))
	summary.append(str(fallback_lookups)); summary.append(str(fallback_memo_hits)); summary.append(str(fallback_candidates)); summary.append(str(fallback_empty)); summary.append(str(procedural_fallbacks)); summary.append("%.4f"%fallback_lookup_ms)
	summary.append(str(evictions)); summary.append(str(total_readbacks)); summary.append(str(game.renderer.vehicle_cache_generation_frozen))
	summary.append(str(frames_over_33ms)); summary.append(str(frames_over_50ms)); summary.append(str(frames_over_100ms))
	summary.append(str(game.renderer.vehicle_cache_viewports.size())); summary.append("unavailable" if vram_samples==0 else "%.2f"%(vram_mb_sum/float(vram_samples)))
	summary_lines.append(",".join(summary))
	print("MOVE_RESULT %s %.2f FPS avg %.3fms p1-tail %.3fms max %.3fms | >33 %.0f >50 %.0f >100 %.0f | moving min %d avg %.1f active %.1f%% | world %.3fms vehicles %.3fms sim %.3f path %.3f sep %.3f | hits %d misses %d created %d readbacks %d cache %d viewports %d VRAM_MB %s fallback %d memo %d examined %d empty %d procedural %d fallback_ms %.3f evictions %d queue %d/%d frozen %s"%[label,1000.0/avg,avg,percentile_worst_1pct(frames),max_frame,float(frames_over_33ms),float(frames_over_50ms),float(frames_over_100ms),minimum_moving_vehicles,average_moving_vehicles,motion_active_percent,averages[0],averages[3],averages[13],averages[14],averages[15],total_hits,total_misses,game.renderer.vehicle_cache_new_poses_total-starting_created,total_readbacks,game.renderer.vehicle_texture_cache.size(),game.renderer.vehicle_cache_viewports.size(),("unavailable" if vram_samples==0 else "%.1f"%(vram_mb_sum/float(vram_samples))),fallback_lookups,fallback_memo_hits,fallback_candidates,fallback_empty,procedural_fallbacks,fallback_lookup_ms,evictions,queue_end,pending_end,game.renderer.vehicle_cache_generation_frozen])
	await capture_quality_image(label)
	game.renderer.vehicle_cache_queue.clear(); game.renderer.pending_pose_keys.clear()
	game.paused=true; game.renderer.visual_paused=true
	await settle(30)

func format_floats(values: Array[float]) -> Array[String]:
	var result: Array[String]=[]
	for value in values: result.append("%.4f"%value)
	return result

func run() -> void:
	root.size=Vector2i(1920,1080)
	root.content_scale_size=Vector2i(1920,1080)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle(5)
	game.skip_intro(); game.start_game()
	for _frame in 3000:
		await process_frame
		suppress_low_fps_logging()
		if not game.vehicle_pose_warmup_active: break
	if game.vehicle_pose_warmup_active or not game.renderer.vehicle_cache_generation_frozen:
		push_error("STARTUP POSE BASELINE FAILED: cache warm-up did not finish before 3000 frames")
		benchmark_contract_failed=true
	game.playing=true; game.paused=false
	# Match the normal 3D vehicle renderer regardless of a user's persisted
	# classic-mode preference; otherwise no pose-cache measurements are valid.
	game.renderer.classic=false
	benchmark_factions=[]
	for faction_value in game.sim.factions: benchmark_factions.append(str(faction_value))
	if benchmark_factions.size()<2:
		push_error("FPS BENCHMARK SETUP FAILED: expected two active factions, got %s"%[benchmark_factions])
		benchmark_contract_failed=true
	else:
		print("FPS BENCHMARK factions=%s"%[benchmark_factions])
	if OS.get_cmdline_user_args().has("--live-prewarmed-256"):
		# Diagnostic capacity experiment: test whether a 256px / no-MSAA cache
		# can retain the repeated moving-battle working set without active bakes.
		game.renderer.vehicle_cache_capacity=1024
		cache_warm_pass_limit=16
	game.renderer.vehicle_cache_diagnostics_enabled=true
	for _frame in 300:
		await process_frame
		if game.renderer.vehicle_cache_generation_frozen: break
	trace_lines.append("variant,frame,frame_ms,world_ms,terrain_ms,buildings_ms,vehicles_ms,wrecks_ms,combat_vfx_ms,projectiles_render_ms,impacts_render_ms,explosions_render_ms,smoke_ms,tracks_ms,fog_ms,hud_ms,simulation_ms,pathfinding_ms,separation_ms,target_search_ms,combat_ms,movement_ms,projectile_sim_ms,ai_ms,draw_calls,primitives,phase_setup_ms,phase_ground_ms,phase_cull_sort_ms,phase_entities_ms,phase_combat_and_fog_ms,phase_overlays_ms,phase_post_ms,phase_unattributed_ms,visible_vehicles,entities,projectiles,effects,particles,wrecks,tracks,pose_hits,pose_misses,poses_created,poses_recreated,readbacks,readback_ms,building_readbacks,building_readback_ms,subviewport_completion_latency_ms,cache_size,active_subviewports,production_preview_views,moving_vehicles,track_segments_in_view")
	var variants := [["scale_active_cache","live_cache"]]
	if OS.get_cmdline_user_args().has("--moving-polish-ab"):
		# Warm production-path ABBA sequence. The sampled frames are log-silent so
		# console I/O cannot manufacture apparent frame-time spikes.
		variants=variants.slice(0,8)
	elif OS.get_cmdline_user_args().has("--live-256"):
		variants=[["baseline_live_cache_256","live_cache_256"]]
	elif OS.get_cmdline_user_args().has("--live-384"):
		variants=[["baseline_live_cache_384","live_cache_384"]]
	elif OS.get_cmdline_user_args().has("--live-only"):
		variants=[["baseline_live_cache","live_cache"]]
	elif OS.get_cmdline_user_args().has("--live-prewarmed-256"):
		variants=[["baseline_live_prewarmed_256","live_cache_256_prewarmed"]]
	elif OS.get_cmdline_user_args().has("--terrain-base-ab"):
		# ABBA order reduces GPU/thermal drift; all four runs use the same warmed
		# moving-battle setup and change only the diagnostic terrain base pass.
		variants=[["baseline_terrain_base_1",""],["terrain_base_off_1","terrain_base_off"],["terrain_base_off_2","terrain_base_off"],["baseline_terrain_base_2",""]]
	elif OS.get_cmdline_user_args().has("--track-visibility-count"):
		variants=[["track_visibility_count","track_visibility_count"]]
	for pair in variants:
		await run_variant(str(pair[0]),str(pair[1]))
	var run_suffix: String="baseline_only" if OS.get_cmdline_user_args().has("--baseline-only") else ("active_bakes_control" if OS.get_cmdline_user_args().has("--allow-active-pose-bakes") else "frozen_cache")
	var summary_file:=FileAccess.open("res://test-output/fps_10buildings_50vehicles_%s.csv"%run_suffix,FileAccess.WRITE)
	summary_file.store_string("\n".join(summary_lines)+"\n"); summary_file.close()
	var trace_file:=FileAccess.open("res://test-output/fps_10buildings_50vehicles_%s_frames.csv"%run_suffix,FileAccess.WRITE)
	trace_file.store_string("\n".join(trace_lines)+"\n"); trace_file.close()
	var key_file:=FileAccess.open("res://test-output/fps_10buildings_50vehicles_%s_pose_keys.csv"%run_suffix,FileAccess.WRITE)
	key_file.store_line("kind,faction,owner,team_color,heading_frame,turret_frame,damage_state,cargo_state,animation_state,drive_frame")
	for key in game.renderer.vehicle_cache_created_keys:
		key_file.store_line(str(key))
	key_file.close()
	game.music.shutdown(); game.queue_free(); await process_frame
	quit(1 if benchmark_contract_failed else 0)
