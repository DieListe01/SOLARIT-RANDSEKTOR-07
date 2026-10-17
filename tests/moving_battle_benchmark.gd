extends SceneTree

## Moving 40-unit combat benchmark. Run on the normal Vulkan renderer, never --headless.
const WARMUP_FRAMES := 900
const SAMPLE_FRAMES := 900
const MAX_CACHE_WARM_PASSES := 8
var cache_warm_pass_limit := MAX_CACHE_WARM_PASSES
const WARM_CHECK_FRAMES := 90
var game: Control
var side_units: Array = [[],[],[],[]]
var trace_lines: Array[String] = []
var benchmark_contract_failed := false
var summary_lines: Array[String] = ["variant,frames,fps,avg_frame_ms,1pct_worst_frame_ms,max_frame_ms,visible_vehicles,entities,projectiles,effects,particles,wrecks,tracks,pose_hits,pose_misses,poses_created,poses_recreated,readbacks,cache_size,active_subviewports,production_preview_views,moving_vehicles_min,moving_vehicles_avg,motion_active_percent,world_ms,terrain_ms,buildings_ms,vehicles_ms,wrecks_ms,combat_vfx_ms,projectiles_render_ms,impacts_render_ms,explosions_render_ms,smoke_render_ms,tracks_render_ms,fog_ms,hud_ms,simulation_ms,pathfinding_ms,separation_ms,target_search_ms,combat_ms,movement_ms,projectile_sim_ms,ai_ms,draw_calls,primitives,phase_setup_ms,phase_ground_ms,phase_cull_sort_ms,phase_entities_ms,phase_combat_and_fog_ms,phase_overlays_ms,phase_post_ms,phase_unattributed_ms,visible_track_segments_avg"]

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
	# Replaying the same seed/order path from the same visual animation phase
	# makes the warmed corpus exactly match the measured moving battle.
	game.renderer.elapsed=0.0
	game.renderer.health_mode="damaged"
	game.sim.path_requests.clear()
	var erase_ids: Array[int]=[]
	for id in game.sim.entities:
		if not game.sim.entities[id].building: erase_ids.append(id)
	for id in erase_ids: game.sim.entities.erase(id)
	var next_entity_id:=1
	for id in game.sim.entities: next_entity_id=maxi(next_entity_id,int(id)+1)
	game.sim.next_id=next_entity_id
	game.sim.projectiles.clear(); game.sim.effects.clear()
	game.renderer.combat_fx.reset()
	game.renderer.tracks.clear(); game.renderer.visual_bursts.clear()
	game.renderer.previous_positions.clear(); game.renderer.previous_speeds.clear()
	game.renderer.track_timer=0.0; game.renderer.track_age_timer=0.0
	game.sim.mobile_entity_count=0
	game.sim.rebuild_movement_buckets()
	game.sim.known=[{},{}]
	for owner in 2:
		game.sim.fog[owner].fill(0)
		game.sim.explored[owner].fill(0)
	var center:=Vector2(game.sim.grid.width*game.sim.grid.tile*0.5,game.sim.grid.height*game.sim.grid.tile*0.5)
	game.renderer.camera=center
	game.renderer.zoom=0.92
	game.sim.db.mission["ai_enabled"]=false # Hostile mobile forces remain fully active; suppress unbounded AI production.
	game.sim.time=0.0; game.sim.result=""; game.sim.ai_timer=999999.0
	game.sim.rng.seed=731904
	game.renderer.combat_fx.visual_rng.seed=731904
	side_units=[[],[],[],[]]
	# Matched 20 vs 20 mixed forces: 14 tanks, 4 siege vehicles and 2 raiders per side.
	for owner in 2:
		var side_sign:= -1.0 if owner==0 else 1.0
		for i in 20:
			var kind: String="tank" if i<14 else ("siege" if i<18 else "raider")
			var row:=float(i/5)-1.5
			var column:=float(i%5)-2.0
			var p:=center+Vector2(side_sign*270.0+column*39.0,row*46.0)
			var id: int=game.sim.spawn(kind,owner,p,false)
			if id>0:
				side_units[owner*2+int(i/10)].append(id)
				var unit: Dictionary=game.sim.entities[id]
				# Keep the large moving fight populated throughout cache warm-up and sampling.
				# Two forward vehicles per side remain destructible to produce genuine wrecks.
				if i>=2:
					unit.max_hp=25000.0
					unit.hp=25000.0
		for squad in range(owner*2,owner*2+2):
			var squad_offset:= -90.0 if squad%2==0 else 90.0
			game.sim.command(side_units[squad],center+Vector2(-side_sign*260.0,squad_offset),"attack_move")
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
		var pending: int=game.renderer.vehicle_cache_queue.size()+game.renderer.pending_pose_keys.size()
		var misses: int=game.renderer.vehicle_cache_misses_total-old_misses
		var created: int=game.renderer.vehicle_cache_new_poses_total-old_created
		print("MOVE_WARM %s pass=%d created=%d misses=%d pending=%d entries=%d"%[label,pass_index+1,created,misses,pending,game.renderer.vehicle_texture_cache.size()])
		if pending==0 and misses==0 and created==0: return

func warm_moving_scenario(label: String) -> void:
	var next_order_time: float=game.sim.time+0.1
	for frame in WARMUP_FRAMES:
		next_order_time=retask_if_needed(next_order_time)
		await process_frame
		suppress_low_fps_logging()
		if frame%90==89: print("MOVE_WARMUP %s frame=%d/%d mission_time=%.1f visible=%d moving=%d pose_queue=%d"%[label,frame+1,WARMUP_FRAMES,game.sim.time,game.renderer.visible_mobile_count,game.sim.entities.values().filter(func(e): return not e.building and e.velocity.length()>2.0).size(),game.renderer.vehicle_cache_queue.size()+game.renderer.pending_pose_keys.size()])

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
	await warm_moving_scenario(label)
	await wait_pose_cache(label)
	# Exercise the production path: misses stay on the nearest cached texture;
	# active gameplay never starts an expensive pose SubViewport render.
	if not live_cache_diagnostic:
		game.renderer.vehicle_cache_generation_frozen=true
		# Freezing prevents new jobs, but an already-rendering request is allowed to
		# finish. Drain that one in-flight job before starting the measured window.
		for _frame in 60:
			if not game.renderer.vehicle_cache_worker_active: break
			await process_frame
		if game.renderer.vehicle_cache_worker_active:
			benchmark_contract_failed=true
			push_error("POSE-CACHE WARMUP FAILED %s: worker stayed active after generation was frozen"%label)
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
	var previous:=Time.get_ticks_usec()
	var frames: Array[float]=[]
	var minimum_moving_vehicles:=40
	var total_moving_vehicles:=0
	var active_motion_frames:=0
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
	if total_readbacks!=0 or max_frame>100.0 or (not live_cache_diagnostic and (created_poses!=0 or max_created_per_frame>1)):
		benchmark_contract_failed=true
		push_error("LIVE POSE-CACHE CONTRACT FAILED %s: poses=%d poses_per_frame=%d readbacks=%d max_frame=%.3fms"%[label,created_poses,max_created_per_frame,total_readbacks,max_frame])
	if OS.get_cmdline_user_args().has("--live-prewarmed-256") and (created_poses!=0 or max_created_per_frame!=0):
		benchmark_contract_failed=true
		push_error("PREWARMED LIVE-CACHE CONTRACT FAILED %s: expected zero active-play pose bakes, got %d (max per frame %d)"%[label,created_poses,max_created_per_frame])
	var averages: Array[float]=[]
	for i in 31: averages.append(sums[i]/frames.size())
	var summary: Array[String]=[label,str(SAMPLE_FRAMES),"%.2f"%(1000.0/avg),"%.3f"%avg,"%.3f"%percentile_worst_1pct(frames),"%.3f"%max_frame]
	for n in counts_summary: summary.append(str(n))
	summary.append(str(minimum_moving_vehicles)); summary.append("%.2f"%average_moving_vehicles); summary.append("%.2f"%motion_active_percent)
	for v in averages: summary.append("%.4f"%v)
	summary.append("%.2f"%(float(visible_track_segment_sum)/float(frames.size())))
	summary_lines.append(",".join(summary))
	print("MOVE_RESULT %s %.2f FPS avg %.3fms p1-tail %.3fms max %.3fms | moving min %d avg %.1f active %.1f%% | world %.3fms sim %.3f path %.3f sep %.3f target %.3f combat %.3f move %.3f projectile_sim %.3f tracks %.3f wrecks %.3f VFX %.3f | tracks in view %.1f / %.1f | hits %d misses %d created %d recreated %d readbacks %d cache %d"%[label,1000.0/avg,avg,percentile_worst_1pct(frames),max_frame,minimum_moving_vehicles,average_moving_vehicles,motion_active_percent,averages[0],averages[13],averages[14],averages[15],averages[16],averages[17],averages[18],averages[19],averages[10],averages[4],averages[5],float(visible_track_segment_sum)/float(frames.size()),float(track_segment_sum)/float(frames.size()),total_hits,total_misses,game.renderer.vehicle_cache_new_poses_total-starting_created,game.renderer.vehicle_cache_recreated_poses_total-old_recreated,total_readbacks,game.renderer.vehicle_texture_cache.size()])
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
	# Match the normal 3D vehicle renderer regardless of a user's persisted
	# classic-mode preference; otherwise no pose-cache measurements are valid.
	game.renderer.classic=false
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
	var variants := [["baseline_adaptive","adaptive"],["vfx_limited","vfx"],["baseline_fullquality_1",""],["tracks_optimized","tracks"],["baseline_fullquality_2",""],["wrecks_compact","wrecks"],["baseline_fullquality_3",""],["combined","combined"],["baseline_live_cache","live_cache"]]
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
	var summary_file:=FileAccess.open("res://test-output/moving_battle_benchmark.csv",FileAccess.WRITE)
	summary_file.store_string("\n".join(summary_lines)+"\n"); summary_file.close()
	var trace_file:=FileAccess.open("res://test-output/moving_battle_benchmark_frames.csv",FileAccess.WRITE)
	trace_file.store_string("\n".join(trace_lines)+"\n"); trace_file.close()
	var key_file:=FileAccess.open("res://test-output/moving_battle_pose_keys.csv",FileAccess.WRITE)
	key_file.store_line("kind,faction,owner,team_color,heading_frame,turret_frame,damage_state,cargo_state,animation_state,drive_frame")
	for key in game.renderer.vehicle_cache_created_keys:
		key_file.store_line(str(key))
	key_file.close()
	game.music.shutdown(); game.queue_free(); await process_frame
	quit(1 if benchmark_contract_failed else 0)
