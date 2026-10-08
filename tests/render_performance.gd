extends SceneTree

var game: Control
var rows: Array[String] = ["scenario,vehicles,average_fps,frame_ms,draw_calls,primitives"]

func _initialize() -> void:
	call_deferred("run")

func settle_frames(count: int) -> void:
	for _i in count: await process_frame

func remove_mobile_units() -> void:
	var remove_ids: Array[int] = []
	for id in game.sim.entities:
		if not game.sim.entities[id].building: remove_ids.append(id)
	for id in remove_ids: game.sim.entities.erase(id)

func create_vehicles(count: int) -> Array[int]:
	remove_mobile_units()
	var camera: Vector2=game.renderer.camera
	var ids: Array[int]=[]
	for i in count:
		var pos: Vector2=camera+Vector2(-320+(i%8)*78,145+floori(i/8.0)*62)
		ids.append(game.sim.spawn("tank",0,pos,false))
	game.render_previous=game.capture_render_state()
	game.render_current=game.render_previous.duplicate(true)
	game.renderer.set_interpolation(game.render_previous,game.render_current,1.0)
	game.renderer.queue_redraw()
	return ids

func measure(count: int) -> void:
	create_vehicles(count)
	await settle_frames(75)
	var started := Time.get_ticks_usec()
	var draws_total := 0.0
	var primitives_total := 0.0
	var profile_totals := {"total":0.0,"terrain":0.0,"ground":0.0,"buildings":0.0,"vehicles":0.0,"combat":0.0,"solarit":0.0}
	for _i in 120:
		await process_frame
		draws_total+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives_total+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		profile_totals.total+=game.renderer.profile_total_ms
		profile_totals.terrain+=game.renderer.profile_terrain_ms
		profile_totals.ground+=game.renderer.profile_ground_fx_ms
		profile_totals.buildings+=game.renderer.profile_buildings_ms
		profile_totals.vehicles+=game.renderer.profile_vehicles_ms
		profile_totals.combat+=game.renderer.profile_combat_fx_ms
		profile_totals.solarit+=game.renderer.profile_solarit_count
	var elapsed_seconds := float(Time.get_ticks_usec()-started)/1000000.0
	var fps := 120.0/maxf(elapsed_seconds,0.001)
	var frame_ms := 1000.0/maxf(fps,0.01)
	var draws := int(round(draws_total/120.0))
	var primitives := int(round(primitives_total/120.0))
	rows.append("stationary,%d,%.2f,%.2f,%d,%d" % [count,fps,frame_ms,draws,primitives])
	print("RENDER PERF stationary: %d vehicles | %.2f FPS | %.2f ms | %d draw calls | %d primitives" % [count,fps,frame_ms,draws,primitives])
	print("RENDER BREAKDOWN stationary: total %.2f ms | terrain %.2f | ground/debris %.2f | buildings %.2f | vehicles %.2f | combat %.2f | solarit cells %.0f" % [profile_totals.total/120.0,profile_totals.terrain/120.0,profile_totals.ground/120.0,profile_totals.buildings/120.0,profile_totals.vehicles/120.0,profile_totals.combat/120.0,profile_totals.solarit/120.0])
	if count in [1,40]:
		await settle_frames(3)
		root.get_texture().get_image().save_png("res://test-output/render_vehicles_%d.png" % count)

func measure_moving_combat() -> void:
	var ids := create_vehicles(40)
	await settle_frames(75)
	game.sim.command(ids,game.renderer.camera+Vector2(400,180),"move")
	game.paused=false
	game.renderer.visual_paused=false
	var draws_total := 0.0
	var primitives_total := 0.0
	var profile_totals := {"total":0.0,"terrain":0.0,"ground":0.0,"buildings":0.0,"vehicles":0.0,"combat":0.0}
	var started := Time.get_ticks_usec()
	for i in 120:
		if i%8==0:
			game.renderer.combat_fx.emit_effect("shot",{"pos":game.renderer.camera+Vector2(i%7*30,40),"angle":0.0,"weapon":"cannon"})
		await process_frame
		draws_total+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives_total+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		profile_totals.total+=game.renderer.profile_total_ms
		profile_totals.terrain+=game.renderer.profile_terrain_ms
		profile_totals.ground+=game.renderer.profile_ground_fx_ms
		profile_totals.buildings+=game.renderer.profile_buildings_ms
		profile_totals.vehicles+=game.renderer.profile_vehicles_ms
		profile_totals.combat+=game.renderer.profile_combat_fx_ms
	game.paused=true
	game.renderer.visual_paused=true
	var elapsed_seconds := float(Time.get_ticks_usec()-started)/1000000.0
	var fps := 120.0/maxf(elapsed_seconds,0.001)
	var draws := int(round(draws_total/120.0))
	var primitives := int(round(primitives_total/120.0))
	rows.append("moving_vfx,40,%.2f,%.2f,%d,%d" % [fps,1000.0/fps,draws,primitives])
	print("RENDER PERF moving + combat VFX: 40 vehicles | %.2f FPS | %.2f ms | %d draw calls | %d primitives" % [fps,1000.0/fps,draws,primitives])
	print("RENDER BREAKDOWN moving + VFX: total %.2f ms | terrain %.2f | ground/debris %.2f | buildings %.2f | vehicles %.2f | combat %.2f" % [profile_totals.total/120.0,profile_totals.terrain/120.0,profile_totals.ground/120.0,profile_totals.buildings/120.0,profile_totals.vehicles/120.0,profile_totals.combat/120.0])

func measure_building_crowd() -> bool:
	remove_mobile_units()
	game.sim.projectiles.clear()
	game.sim.effects.clear()
	game.renderer.combat_fx.reset()
	game.renderer.visual_bursts.clear()
	game.renderer.tracks.clear()
	var building_ids: Array[int]=[]
	var previous_camera: Vector2=game.renderer.camera
	game.renderer.camera=Vector2(33*32,42*32)
	for i in 4:
		building_ids.append(game.sim.spawn("power",0,Vector2((20+i*4)*32,38*32),true))
	await settle_frames(75)
	var static_cache_times: Dictionary=game.renderer.building_texture_times.duplicate(true)
	var baseline_total := 0.0
	var baseline_buildings := 0.0
	var baseline_started := Time.get_ticks_usec()
	for _i in 60:
		await process_frame
		baseline_total+=game.renderer.profile_total_ms
		baseline_buildings+=game.renderer.profile_buildings_ms
	var baseline_fps := 60.0/maxf(0.001,float(Time.get_ticks_usec()-baseline_started)/1000000.0)
	print("RENDER BUILDINGS 4 added: %.1f FPS | draw submission %.2f ms | building pass %.2f ms/frame | cache hits/misses %d/%d" % [baseline_fps,baseline_total/60.0,baseline_buildings/60.0,game.renderer.building_cache_hits,game.renderer.building_cache_misses])
	var static_cache_ok: bool=not static_cache_times.is_empty() and game.renderer.building_texture_times.size()==static_cache_times.size()
	for key in static_cache_times:
		if not is_equal_approx(float(game.renderer.building_texture_times.get(key,-1.0)),float(static_cache_times[key])): static_cache_ok=false
	if not static_cache_ok: push_error("BUILDING CACHE REGRESSION: unchanged buildings were rasterized again")
	await settle_frames(3)
	root.get_texture().get_image().save_png("res://test-output/render_buildings_4.png")
	for id in building_ids: game.sim.entities.erase(id)
	building_ids.clear()
	for row in 5:
		for column in 10:
			building_ids.append(game.sim.spawn("power",0,Vector2((15+column*4)*32,(34+row*4)*32),true))
	game.renderer.queue_redraw()
	await settle_frames(75)
	var total := 0.0
	var buildings := 0.0
	var draws_total := 0.0
	var crowd_started := Time.get_ticks_usec()
	for _i in 120:
		await process_frame
		total+=game.renderer.profile_total_ms
		buildings+=game.renderer.profile_buildings_ms
		draws_total+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var crowd_fps := 120.0/maxf(0.001,float(Time.get_ticks_usec()-crowd_started)/1000000.0)
	print("RENDER BUILDINGS 50 added: %.1f FPS | draw submission %.2f ms | building pass %.2f ms/frame | visible buildings %d | average draw calls %.0f | cache hits/misses %d/%d" % [crowd_fps,total/120.0,buildings/120.0,game.renderer.visible_building_count,draws_total/120.0,game.renderer.building_cache_hits,game.renderer.building_cache_misses])
	var cache_ok: bool=game.renderer.visible_building_count>=50 and game.renderer.building_cache_hits>=50 and game.renderer.building_cache_misses==0
	if not cache_ok: push_error("BUILDING CACHE REGRESSION: 50 visible buildings did not resolve from cache")
	for id in building_ids: game.sim.entities.erase(id)
	game.renderer.camera=previous_camera
	return cache_ok and static_cache_ok

func measure_destruction_debris() -> void:
	game.renderer.combat_fx.ruins.clear()
	game.renderer.combat_fx.particles.clear()
	var origin: Vector2=game.renderer.camera
	for i in 24:
		var offset := Vector2((i%6-3)*80,floori(i/6.0)*68-100)
		game.renderer.combat_fx.emit_effect("destroy",{"pos":origin+offset,"angle":float(i)*0.3,"building":false,"kind":"tank"})
	for i in 12:
		var offset := Vector2((i%4-2)*105,floori(i/4.0)*105+100)
		game.renderer.combat_fx.emit_effect("destroy",{"pos":origin+offset,"angle":float(i)*0.25,"building":true,"kind":"factory","visual_size":3.0,"visual_footprint":[3,3]})
	await settle_frames(5)
	var ground := 0.0
	var combat := 0.0
	var total := 0.0
	for _i in 60:
		await process_frame
		ground+=game.renderer.profile_ground_fx_ms
		combat+=game.renderer.profile_combat_fx_ms
		total+=game.renderer.profile_total_ms
	print("RENDER BREAKDOWN 36 simultaneous destruction effects: total %.2f ms | wreck layer %.2f | combat FX %.2f ms/frame | draw calls %d | visible ruins %d | particles %d" % [total/60.0,ground/60.0,combat/60.0,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),game.renderer.combat_fx.ruins.size(),game.renderer.combat_fx.particles.size()])

func compare_vehicle_sharpness() -> bool:
	var one := Image.load_from_file("res://test-output/render_vehicles_1.png")
	var forty := Image.load_from_file("res://test-output/render_vehicles_40.png")
	if one==null or forty==null or one.get_size()!=forty.get_size():
		push_error("VISUAL REGRESSION: reference screenshots missing or have different sizes")
		return false
	var point := Vector2i(game.WORLD_RECT.position+game.WORLD_RECT.size*0.5+Vector2(-320,145)*game.renderer.zoom)
	var roi := Rect2i(point-Vector2i(38,31),Vector2i(76,62)).intersection(Rect2i(Vector2i.ZERO,one.get_size()))
	var difference := 0.0
	for y in range(roi.position.y,roi.end.y):
		for x in range(roi.position.x,roi.end.x):
			var a := one.get_pixel(x,y); var b := forty.get_pixel(x,y)
			difference+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
	var mean_difference := difference/maxf(1.0,float(roi.size.x*roi.size.y))
	print("SHARPNESS REGRESSION: reference vehicle ROI mean RGB difference %.3f%%" % (mean_difference*100.0))
	if mean_difference>0.03:
		push_error("VISUAL REGRESSION: one vs forty vehicle reference differs by more than 3%")
		return false
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle_frames(3)
	game.skip_intro(); game.start_game(); game.paused=true
	game.renderer.profile_enabled=true
	game.sim.ai_timer=999999
	await settle_frames(3)
	var fog_buffer: Image=game.renderer.fog_image
	await settle_frames(45)
	var fog_cache_ok: bool=fog_buffer!=null and game.renderer.fog_image==fog_buffer and game.renderer.fog_texture!=null
	if not fog_cache_ok: push_error("FOG CACHE REGRESSION: stable map fog did not reuse its image buffer")
	print("RENDER FOG CACHE: reused image buffer across scheduled visibility updates: %s" % fog_cache_ok)
	game.renderer.tracks.clear()
	game.renderer.tracks.append({"a":Vector2.ZERO,"b":Vector2.ONE,"angle":0.0,"life":0.1})
	game.renderer.tracks.append({"a":Vector2.ZERO,"b":Vector2.ONE,"angle":0.0,"life":1.0})
	game.renderer.age_ground_tracks(0.25)
	var track_aging_ok: bool=game.renderer.tracks.size()==1 and is_equal_approx(float(game.renderer.tracks[0].life),0.75)
	if not track_aging_ok: push_error("TRACK LIFETIME REGRESSION: batched track aging did not expire and retain the correct tracks")
	game.renderer.tracks.clear()
	print("RENDER TRACK AGING: batched aging retains lifetimes and removes expired tracks: %s" % track_aging_ok)
	for count in [1,10,20,40]: await measure(count)
	var quality_ok := compare_vehicle_sharpness()
	await measure_moving_combat()
	var buildings_ok := await measure_building_crowd()
	await measure_destruction_debris()
	var file := FileAccess.open("res://test-output/render_performance.csv",FileAccess.WRITE)
	file.store_string("\n".join(rows)+"\n")
	file.close()
	game.music.shutdown(); game.queue_free()
	await process_frame
	quit(0 if quality_ok and buildings_ok and fog_cache_ok and track_aging_ok else 1)
