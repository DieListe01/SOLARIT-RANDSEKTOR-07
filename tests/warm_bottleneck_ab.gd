extends SceneTree

## GPU-backed, repeatable isolation run for the warm 40-unit battlefield.
## Run without --headless: Godot's Null renderer is not a valid performance baseline.
const WARMUP_FRAMES := 240
const CACHE_STABILITY_FRAMES := 120
const CACHE_STABILITY_MAX_PASSES := 10
const SAMPLE_FRAMES := 300
var game: Control
var rows: Array[String] = []
var trace_rows: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int) -> void:
	for _index in frames:
		await process_frame
		suppress_low_fps_file_logging()

func wait_for_warm_pose_cache(label: String) -> void:
	for pass_index in CACHE_STABILITY_MAX_PASSES:
		var before_created: int=game.renderer.vehicle_cache_new_poses_total
		var before_misses: int=game.renderer.vehicle_cache_misses_total
		await settle(CACHE_STABILITY_FRAMES)
		var created: int=game.renderer.vehicle_cache_new_poses_total-before_created
		var misses: int=game.renderer.vehicle_cache_misses_total-before_misses
		var pending: int=game.renderer.pending_pose_keys.size()+game.renderer.vehicle_cache_queue.size()
		print("POSE_WARM %s pass %d | created %d misses %d pending %d cached %d" % [label,pass_index+1,created,misses,pending,game.renderer.vehicle_texture_cache.size()])
		if created==0 and misses==0 and pending==0: return

func suppress_low_fps_file_logging() -> void:
	# Keep the game's adaptive profiler enabled explicitly while preventing its
	# persistent low-FPS event logger from writing into the user's AppData during
	# a benchmark (this sandbox intentionally cannot create that folder).
	if not is_instance_valid(game): return
	game.low_fps_seconds=0.0
	game.low_fps_critical_seconds=0.0
	game.low_fps_active=false
	game.fps_auto_profile=false
	game.renderer.profile_enabled=true

func build_scene() -> void:
	game.paused=true
	game.renderer.visual_paused=true
	game.sim.ai_timer=999999.0
	game.sim.profile_enabled=true
	game.renderer.profile_enabled=true
	game.renderer.benchmark_disabled_categories.clear()
	game.renderer.selected.clear()
	game.renderer.health_mode="always"
	game.sim.path_requests.clear()
	var remove_ids: Array[int]=[]
	for id in game.sim.entities:
		if not game.sim.entities[id].building: remove_ids.append(id)
	for id in remove_ids: game.sim.entities.erase(id)
	game.sim.projectiles.clear(); game.sim.effects.clear()
	game.renderer.combat_fx.reset()
	game.renderer.tracks.clear(); game.renderer.visual_bursts.clear()
	game.renderer.previous_positions.clear(); game.renderer.previous_speeds.clear()
	game.renderer.track_timer=0.0; game.renderer.track_age_timer=0.0
	game.renderer.camera=Vector2(game.sim.grid.width*game.sim.grid.tile*0.5,game.sim.grid.height*game.sim.grid.tile*0.5)
	game.renderer.zoom=0.82
	game.renderer.queue_redraw()
	var ids: Array[int]=[]
	for i in 40:
		var pos: Vector2=game.renderer.camera+Vector2(-220+(i%5)*110,-238+floori(float(i)/5.0)*68)
		var id: int=game.sim.spawn("tank",0,pos,false)
		var unit: Dictionary=game.sim.entities[id]
		unit.order="hold"; unit.path.clear(); unit.path_pending=false; unit.velocity=Vector2.ZERO
		unit.angle=float((i%8))*TAU/8.0; unit.turret=unit.angle; unit.hp=unit.max_hp
		ids.append(id)
	game.sim.update_fog(false)
	var center: Vector2i=game.sim.grid.cell(game.renderer.camera)
	for y in range(maxi(0,center.y-20),mini(game.sim.grid.height,center.y+21)):
		for x in range(maxi(0,center.x-26),mini(game.sim.grid.width,center.x+27)):
			game.sim.fog[0][y*game.sim.grid.width+x]=1
	game.sim.rebuild_movement_buckets()
	game.renderer.selected=ids.slice(0,10)
	# Static warm-cache battlefield: 40 held units with eight fixed headings,
	# so cache churn cannot masquerade as a steady-state renderer bottleneck.
	for i in 24:
		var pos: Vector2=game.renderer.camera+Vector2(-420+(i%8)*120,-250+floori(float(i)/8.0)*145)
		game.renderer.combat_fx.ruins.append({"pos":pos,"building":false,"core":false,"angle":float(i)*0.37,"age":24.0,"radius":27.0,"variant":i%4,"object_kind":"tank","footprint":[2,2]})
	for i in 900:
		var pos: Vector2=game.renderer.camera+Vector2(-440+(i%90)*10,-270+floori(float(i)/90.0)*30)
		game.renderer.tracks.append({"a":pos,"b":pos+Vector2(7,2),"angle":0.08,"life":35.0})
	for i in 24:
		var pos: Vector2=game.renderer.camera+Vector2(-380+(i%8)*105,-190+floori(float(i)/8.0)*80)
		game.sim.effects.append({"pos":pos,"life":1000.0,"max_life":1000.0,"radius":18.0,"event_backed":false})
		game.renderer.combat_fx.emit_effect("hit",{"id":ids[i%ids.size()],"pos":pos,"angle":0.2})
	for particle in game.renderer.combat_fx.particles: particle.duration=1000.0
	game.renderer.combat_fx.visual_rng.seed=101
	game.paused=false
	game.renderer.visual_paused=false
	game.accumulator=0.0
	game.renderer.queue_redraw()

func percentile_low(frames: Array[float]) -> float:
	var ordered:=frames.duplicate()
	ordered.sort()
	var count:=maxi(1,ceili(float(ordered.size())*0.01))
	var total:=0.0
	for i in range(ordered.size()-count,ordered.size()): total+=ordered[i]
	return total/float(count)

func run_variant(label: String, disabled: Array[String], sim_paused: bool=false, world_reduced: bool=false, hide_hud: bool=false) -> void:
	await build_scene()
	game.renderer.benchmark_disabled_categories=disabled.duplicate()
	if world_reduced: game.renderer.benchmark_disabled_categories.append("world")
	var hud_visibility: Dictionary={}
	if hide_hud:
		for child in game.get_children():
			if child is CanvasItem and child!=game.view_container:
				hud_visibility[child]=child.visible
				child.visible=false
	await settle(WARMUP_FRAMES)
	await wait_for_warm_pose_cache(label)
	# Let the first scene redraw and any driver-side deferred work finish before
	# starting the timed window. This also keeps the first variant comparable to
	# later variants, which otherwise inherit an already-running render loop.
	await settle(120)
	# Keep effects present and stable while simulation/rendering variants run.
	for effect in game.sim.effects: effect.life=1000.0
	for particle in game.renderer.combat_fx.particles: particle.duration=1000.0
	# Every recorded variant keeps identical viewport, camera, simulation and
	# pose-cache settings. Reset counters after its identical warmup interval.
	game.renderer.vehicle_cache_hits=0; game.renderer.vehicle_cache_misses=0
	game.sim.profile_pathfinding_ms=0.0; game.sim.profile_separation_ms=0.0; game.sim.profile_ai_ms=0.0
	if sim_paused:
		game.paused=true
		game.renderer.visual_paused=false
	var intervals: Array[float]=[]
	var sums: Dictionary={"terrain":0.0,"ground":0.0,"wrecks":0.0,"buildings":0.0,"vehicles":0.0,"tracks":0.0,"projectiles":0.0,"impacts":0.0,"explosions":0.0,"smoke":0.0,"fog":0.0,"ui":0.0,"world":0.0,"sim":0.0,"path":0.0,"separation":0.0,"ai":0.0,"draws":0.0,"primitives":0.0,"misses":0.0,"hits":0.0}
	var previous:=Time.get_ticks_usec()
	var old_created: int=game.renderer.vehicle_cache_new_poses_total
	var old_readbacks: int=game.renderer.vehicle_cache_readbacks_total
	for sample_index in SAMPLE_FRAMES:
		await process_frame
		suppress_low_fps_file_logging()
		var now:=Time.get_ticks_usec()
		var frame_ms:=float(now-previous)/1000.0
		intervals.append(frame_ms)
		previous=now
		var renderer=game.renderer
		var trace_values: Array[String]=[
			label,str(sample_index),"%.3f"%frame_ms,"%.2f"%(1000.0/maxf(frame_ms,0.001)),
			"%.3f"%renderer.profile_total_ms,"%.3f"%renderer.profile_terrain_ms,"%.3f"%renderer.profile_buildings_ms,
			"%.3f"%renderer.profile_vehicles_ms,"%.3f"%renderer.profile_wrecks_ms,"%.3f"%renderer.profile_tracks_ms,
			"%.3f"%renderer.profile_projectiles_ms,"%.3f"%renderer.profile_impacts_ms,"%.3f"%renderer.profile_explosions_ms,
			"%.3f"%renderer.profile_smoke_ms,"%.3f"%renderer.profile_fog_ms,"%.3f"%renderer.profile_ui_ms,
			"%.3f"%renderer.profile_sim_ms,"%.3f"%game.sim.profile_pathfinding_ms,"%.3f"%game.sim.profile_separation_ms,
			str(renderer.vehicle_cache_hits),str(renderer.vehicle_cache_misses),str(renderer.vehicle_texture_cache.size()),
			str(renderer.vehicle_cache_new_poses_total-old_created),str(renderer.vehicle_cache_readbacks_total-old_readbacks),
			str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
			str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))]
		trace_rows.append(",".join(trace_values))
		old_created=renderer.vehicle_cache_new_poses_total; old_readbacks=renderer.vehicle_cache_readbacks_total
		sums.terrain+=renderer.profile_terrain_ms; sums.ground+=renderer.profile_ground_fx_ms; sums.wrecks+=renderer.profile_wrecks_ms
		sums.buildings+=renderer.profile_buildings_ms; sums.vehicles+=renderer.profile_vehicles_ms; sums.tracks+=renderer.profile_tracks_ms
		sums.projectiles+=renderer.profile_projectiles_ms; sums.impacts+=renderer.profile_impacts_ms
		sums.explosions+=renderer.profile_explosions_ms; sums.smoke+=renderer.profile_smoke_ms; sums.fog+=renderer.profile_fog_ms
		sums.ui+=renderer.profile_ui_ms; sums.world+=renderer.profile_total_ms; sums.sim+=renderer.profile_sim_ms
		sums.path+=game.sim.profile_pathfinding_ms; sums.separation+=game.sim.profile_separation_ms; sums.ai+=game.sim.profile_ai_ms
		sums.draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sums.primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		sums.misses+=renderer.vehicle_cache_misses; sums.hits+=renderer.vehicle_cache_hits
	var frame_sum:=0.0
	var max_frame:=0.0
	for frame_ms in intervals: frame_sum+=frame_ms; max_frame=maxf(max_frame,frame_ms)
	var avg_frame:=frame_sum/float(intervals.size())
	var fps:=1000.0/avg_frame
	var low_frame:=percentile_low(intervals)
	var keys: Array[String]=["terrain","ground","wrecks","buildings","vehicles","tracks","projectiles","impacts","explosions","smoke","fog","ui","world","sim","path","separation","ai","draws","primitives","misses","hits"]
	var row: Array[String]=[label,"%.2f"%fps,"%.3f"%avg_frame,"%.3f"%low_frame,"%.3f"%max_frame,str(game.renderer.visible_mobile_count),str(game.sim.entities.size()),str(game.renderer.combat_fx.ruins.size()),str(game.renderer.tracks.size())]
	for key in keys: row.append("%.3f"%(float(sums[key])/float(SAMPLE_FRAMES)))
	rows.append(",".join(row))
	print("WARM_AB %s | %.2f FPS avg %.3f ms p1-tail %.3f ms max %.3f ms | world %.3f ms terrain %.3f vehicles %.3f buildings %.3f wrecks %.3f tracks %.3f combat %.3f fog %.3f | sim path %.3f separation %.3f AI %.3f" % [label,fps,avg_frame,low_frame,max_frame,float(sums.world)/SAMPLE_FRAMES,float(sums.terrain)/SAMPLE_FRAMES,float(sums.vehicles)/SAMPLE_FRAMES,float(sums.buildings)/SAMPLE_FRAMES,float(sums.wrecks)/SAMPLE_FRAMES,float(sums.tracks)/SAMPLE_FRAMES,(float(sums.projectiles)+float(sums.impacts)+float(sums.explosions)+float(sums.smoke))/SAMPLE_FRAMES,float(sums.fog)/SAMPLE_FRAMES,float(sums.path)/SAMPLE_FRAMES,float(sums.separation)/SAMPLE_FRAMES,float(sums.ai)/SAMPLE_FRAMES])
	game.paused=true; game.renderer.visual_paused=true
	for child in hud_visibility: child.visible=hud_visibility[child]

func run_simulation_pair() -> void:
	# A/B the simulation on the same warmed scene so device drift and scene
	# recreation cannot be mistaken for a simulation cost.
	await build_scene()
	await settle(WARMUP_FRAMES)
	await wait_for_warm_pose_cache("simulation_pair")
	await settle(120)
	var result_rows: Array[String]=["phase,fps,avg_frame_ms,1pct_worst_frame_ms,max_frame_ms,sim_ms,pathfinding_ms,separation_ms,ai_ms,cache_misses,readbacks"]
	for phase in ["active_1","paused_1","active_2","paused_2"]:
		game.paused=phase.begins_with("paused")
		game.renderer.visual_paused=false
		await settle(30)
		game.sim.profile_pathfinding_ms=0.0; game.sim.profile_separation_ms=0.0; game.sim.profile_ai_ms=0.0
		var frames: Array[float]=[]
		var sim_sum:=0.0; var path_sum:=0.0; var separation_sum:=0.0; var ai_sum:=0.0
		var misses:=0; var readbacks:=0
		var last_readback_count: int=game.renderer.vehicle_cache_readbacks_total
		var previous:=Time.get_ticks_usec()
		for _sample in SAMPLE_FRAMES:
			await process_frame
			suppress_low_fps_file_logging()
			var now:=Time.get_ticks_usec()
			frames.append(float(now-previous)/1000.0); previous=now
			sim_sum+=game.renderer.profile_sim_ms
			path_sum+=game.sim.profile_pathfinding_ms; separation_sum+=game.sim.profile_separation_ms; ai_sum+=game.sim.profile_ai_ms
			misses+=game.renderer.vehicle_cache_misses
			readbacks+=game.renderer.vehicle_cache_readbacks_total-last_readback_count
			last_readback_count=game.renderer.vehicle_cache_readbacks_total
		var frame_sum:=0.0; var frame_max:=0.0
		for frame_ms in frames: frame_sum+=frame_ms; frame_max=maxf(frame_max,frame_ms)
		var avg:=frame_sum/float(frames.size())
		var low:=percentile_low(frames)
		var row: Array[String]=[phase,"%.2f"%(1000.0/avg),"%.3f"%avg,"%.3f"%low,"%.3f"%frame_max,"%.3f"%(sim_sum/SAMPLE_FRAMES),"%.3f"%(path_sum/SAMPLE_FRAMES),"%.3f"%(separation_sum/SAMPLE_FRAMES),"%.3f"%(ai_sum/SAMPLE_FRAMES),str(misses),str(readbacks)]
		result_rows.append(",".join(row))
		print("SIM_AB %s | %.2f FPS avg %.3f ms p1-tail %.3f max %.3f | sim %.3f path %.3f separation %.3f AI %.3f" % [phase,1000.0/avg,avg,low,frame_max,sim_sum/SAMPLE_FRAMES,path_sum/SAMPLE_FRAMES,separation_sum/SAMPLE_FRAMES,ai_sum/SAMPLE_FRAMES])
	game.paused=true; game.renderer.visual_paused=true
	var file:=FileAccess.open("res://test-output/warm_bottleneck_sim_ab.csv",FileAccess.WRITE)
	file.store_string("\n".join(result_rows)+"\n"); file.close()

func measure_phase(label: String, sample_frames: int=240) -> Array[String]:
	await settle(30)
	var frames: Array[float]=[]
	var cache_misses:=0; var readbacks:=0
	var last_readback_count: int=game.renderer.vehicle_cache_readbacks_total
	var previous:=Time.get_ticks_usec()
	for _sample in sample_frames:
		await process_frame
		suppress_low_fps_file_logging()
		var now:=Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0); previous=now
		cache_misses+=game.renderer.vehicle_cache_misses
		readbacks+=game.renderer.vehicle_cache_readbacks_total-last_readback_count
		last_readback_count=game.renderer.vehicle_cache_readbacks_total
	var total:=0.0; var maximum:=0.0
	for frame_ms in frames: total+=frame_ms; maximum=maxf(maximum,frame_ms)
	var average:=total/float(frames.size())
	return [label,"%.2f"%(1000.0/average),"%.3f"%average,"%.3f"%percentile_low(frames),"%.3f"%maximum,str(cache_misses),str(readbacks)]

func run_paired_render_ab() -> void:
	# Keep one exact scene alive and alternate each switch with its own baseline.
	# The first startup/shader-compilation window is discarded before any pair.
	await build_scene()
	game.paused=false; game.renderer.visual_paused=false
	await settle(WARMUP_FRAMES)
	await wait_for_warm_pose_cache("paired_render_ab")
	await settle(180)
	game.renderer.combat_fx.ruins.clear(); game.renderer.tracks.clear()
	for i in 24:
		var pos: Vector2=game.renderer.camera+Vector2(-420+(i%8)*120,-250+floori(float(i)/8.0)*145)
		game.renderer.combat_fx.ruins.append({"pos":pos,"building":false,"core":false,"angle":float(i)*0.37,"age":1.0,"radius":27.0,"variant":i%4,"object_kind":"tank","footprint":[2,2]})
	for i in 900:
		var pos: Vector2=game.renderer.camera+Vector2(-440+(i%90)*10,-270+floori(float(i)/90.0)*30)
		game.renderer.tracks.append({"a":pos,"b":pos+Vector2(7,2),"angle":0.08,"life":1000.0})
	for effect in game.sim.effects: effect.life=1000.0
	for particle in game.renderer.combat_fx.particles: particle.duration=1000.0
	var original_hud: Dictionary={}
	var variants: Array[Array]=[
		["combat_vfx",["combat_vfx"],false], ["fog",["fog"],false],
		["health_selection",["health_selection"],false], ["hud",[],true],
		["buildings",["buildings"],false], ["terrain_detail",["terrain_detail"],false],
		["vehicles",["vehicles"],false], ["tracks",["tracks"],false], ["wrecks",["wrecks"],false]
	]
	var output: Array[String]=["category,phase,fps,avg_frame_ms,1pct_worst_frame_ms,max_frame_ms,cache_misses,readbacks,vehicles,ruins,tracks"]
	for variant in variants:
		var category: String=variant[0]
		var disabled: Array=variant[1]
		var hide_hud: bool=variant[2]
		for child in game.get_children():
			if child is CanvasItem and child!=game.view_container:
				if not original_hud.has(child): original_hud[child]=child.visible
				child.visible=bool(original_hud[child]) and not hide_hud
		game.renderer.benchmark_disabled_categories.clear()
		var baseline:Array[String]=await measure_phase(category+"_on_1")
		output.append(",".join([category]+baseline+[str(game.renderer.visible_mobile_count),str(game.renderer.combat_fx.ruins.size()),str(game.renderer.tracks.size())]))
		game.renderer.benchmark_disabled_categories.clear()
		for disabled_category in disabled: game.renderer.benchmark_disabled_categories.append(disabled_category)
		var disabled_a:Array[String]=await measure_phase(category+"_off_1")
		output.append(",".join([category]+disabled_a+[str(game.renderer.visible_mobile_count),str(game.renderer.combat_fx.ruins.size()),str(game.renderer.tracks.size())]))
		game.renderer.benchmark_disabled_categories.clear()
		for child in game.get_children():
			if child is CanvasItem and child!=game.view_container: child.visible=bool(original_hud[child])
		var baseline_b:Array[String]=await measure_phase(category+"_on_2")
		output.append(",".join([category]+baseline_b+[str(game.renderer.visible_mobile_count),str(game.renderer.combat_fx.ruins.size()),str(game.renderer.tracks.size())]))
		for child in game.get_children():
			if child is CanvasItem and child!=game.view_container: child.visible=bool(original_hud[child]) and not hide_hud
		game.renderer.benchmark_disabled_categories.clear()
		for disabled_category in disabled: game.renderer.benchmark_disabled_categories.append(disabled_category)
		var disabled_b:Array[String]=await measure_phase(category+"_off_2")
		output.append(",".join([category]+disabled_b+[str(game.renderer.visible_mobile_count),str(game.renderer.combat_fx.ruins.size()),str(game.renderer.tracks.size())]))
	game.renderer.benchmark_disabled_categories.clear()
	for child in game.get_children():
		if child is CanvasItem and child!=game.view_container: child.visible=bool(original_hud[child])
	game.paused=true; game.renderer.visual_paused=true
	var file:=FileAccess.open("res://test-output/warm_bottleneck_paired_ab.csv",FileAccess.WRITE)
	file.store_string("\n".join(output)+"\n"); file.close()

func run() -> void:
	rows.append("variant,fps,avg_frame_ms,1pct_worst_frame_ms,max_frame_ms,visible_mobile,entities,ruins,tracks,terrain_profile_ms,ground_fx_ms,wrecks_ms,buildings_ms,vehicles_ms,tracks_ms,projectiles_ms,impacts_ms,explosions_ms,smoke_ms,fog_ms,ui_update_ms,world_renderer_ms,sim_profile_ms,pathfinding_ms,separation_ms,ai_ms,draw_calls,primitives,cache_misses,cache_hits")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(5)
	game.skip_intro(); game.start_game()
	game.paused=true; game.renderer.visual_paused=true
	# Baseline then one controlled switch per pass; cache remains warm and intact.
	await run_variant("baseline_warm_40",[])
	await run_variant("no_wrecks",["wrecks"])
	await run_variant("no_combat_vfx",["combat_vfx"])
	await run_variant("no_fog",["fog"])
	await run_variant("no_healthbars_selection",["health_selection"])
	await run_variant("no_hud",[],false,false,true)
	await run_variant("no_buildings",["buildings"])
	await run_variant("no_terrain_detail",["terrain_detail"])
	await run_variant("no_vehicle_detail",["vehicles"])
	await run_variant("no_tracks",["tracks"])
	await run_variant("simulation_paused_render_on",[],true)
	await run_variant("world_render_reduced_sim_on",[],false,true)
	await run_variant("baseline_repeat_warm_40",[])
	await run_simulation_pair()
	await run_paired_render_ab()
	var file:=FileAccess.open("res://test-output/warm_bottleneck_ab.csv",FileAccess.WRITE)
	file.store_string("\n".join(rows)+"\n"); file.close()
	var trace:=FileAccess.open("res://test-output/warm_bottleneck_ab_frames.csv",FileAccess.WRITE)
	trace.store_string("variant,frame,frame_ms,fps,world_renderer_ms,terrain_ms,buildings_ms,vehicles_ms,wrecks_ms,tracks_ms,projectiles_ms,impacts_ms,explosions_ms,smoke_ms,fog_ms,ui_update_ms,sim_ms,pathfinding_ms,separation_ms,cache_hits,cache_misses,cache_size,poses_created,readbacks,draw_calls,primitives\n"+"\n".join(trace_rows)+"\n"); trace.close()
	game.music.shutdown(); game.queue_free(); await process_frame
	quit(0)
