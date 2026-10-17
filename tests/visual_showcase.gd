extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")

func core_region(game: Control, core: Dictionary) -> PackedByteArray:
	var image: Image = game.viewport.get_texture().get_image()
	if image == null or image.get_width() != 1530 or image.get_height() != 944:
		push_error("VISUAL SHOWCASE: expected a 1530x944 world SubViewport")
		return PackedByteArray()
	var world_rect := Rect2(Vector2.ZERO,Vector2(1530,944))
	var center: Vector2 = world_rect.position + world_rect.size * 0.5 + (core.pos - game.renderer.camera) * game.renderer.zoom
	var region := Rect2i(Vector2i(roundi(center.x)-190,roundi(center.y)-190),Vector2i(380,380))
	region = region.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	return image.get_region(region).get_data() if region.size.x > 0 and region.size.y > 0 else PackedByteArray()

func save_core_region(game: Control, core: Dictionary, path: String) -> void:
	var image: Image = game.viewport.get_texture().get_image()
	if image == null: return
	var world_rect := Rect2(Vector2.ZERO,Vector2(1530,944))
	var center: Vector2 = world_rect.position + world_rect.size * 0.5 + (core.pos - game.renderer.camera) * game.renderer.zoom
	var region := Rect2i(Vector2i(roundi(center.x)-190,roundi(center.y)-190),Vector2i(380,380))
	region = region.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if region.size.x > 0 and region.size.y > 0:
		image.get_region(region).save_png(ProjectSettings.globalize_path(path))

func verify_main_game_placement(game: Control, core: Dictionary) -> bool:
	game.renderer.camera = core.pos
	game.renderer.zoom = 1.25
	game.renderer.visual_paused = true
	var shimmer_was_visible: bool = game.renderer.heat_layer.visible
	game.renderer.heat_layer.visible = false
	# Adaptive VFX tiering changes the number of wind streaks and displayed track
	# segments at live-FPS thresholds. Hold the highest tier constant so the
	# byte-exact comparison isolates placement rendering rather than FPS noise.
	var previous_vfx_tier_override: int = game.renderer.benchmark_vfx_tier_override
	game.renderer.benchmark_vfx_tier_override = 0
	var failures := 0
	var origin: Vector2i = game.sim.grid.cell(core.pos)
	for mode in [2,1]:
		game.set_display_mode(mode)
		await process_frame
		var expected_2d: bool = mode == 1
		var display_valid: bool = root.size == Vector2i(1920,1080) and game.viewport.size == Vector2i(1530,944) and game.view_container.size == Vector2(1530,944) and game.view_container.stretch_shrink == 1 and is_equal_approx(game.scale.x,1.0) and is_equal_approx(game.scale.y,1.0) and game.classic == expected_2d and game.classic_hd == expected_2d
		if not display_valid:
			printerr("VISUAL SHOWCASE FAIL: mode %d display configuration invalid (root=%s viewport=%s container=%s shrink=%d classic=%s classic_hd=%s scale=%s)" % [mode,str(root.size),str(game.viewport.size),str(game.view_container.size),game.view_container.stretch_shrink,str(game.classic),str(game.classic_hd),str(game.scale)])
			failures += 1
		game.renderer.placement = ""
		game.renderer.queue_redraw()
		await RenderingServer.frame_post_draw
		var baseline := core_region(game,core)
		var stable_samples := 0
		for settle_frame in 8:
			await process_frame
			await RenderingServer.frame_post_draw
			var settled_region := core_region(game,core)
			if settled_region == baseline:
				stable_samples += 1
			else:
				baseline = settled_region
				stable_samples = 0
			if stable_samples >= 2: break
		if stable_samples < 2:
			printerr("VISUAL SHOWCASE FAIL: mode %d core region did not settle for two consecutive frames" % mode)
			failures += 1
		var stable_elapsed: float = float(game.renderer.elapsed)
		var stable_vfx_tier: int = game.renderer.vfx_budget_tier
		print("VISUAL SHOWCASE SAMPLE: mode %d baseline frame %d FPS %d VFX tier %d" % [mode,Engine.get_process_frames(),Engine.get_frames_per_second(),stable_vfx_tier])
		if baseline.is_empty():
			printerr("VISUAL SHOWCASE FAIL: mode %d Full-HD core baseline was empty" % mode)
			failures += 1
		save_core_region(game,core,"res://test-output/main_placement_baseline_mode_%d.png" % mode)
		for offset in [Vector2i(15,-10),Vector2i(15,10),Vector2i(-8,-10),Vector2i(-8,10)]:
			var target_cell: Vector2i=origin+offset
			if not game.sim.grid.inside(target_cell):
				printerr("VISUAL SHOWCASE FAIL: mode %d placement target %s is outside the map" % [mode,str(target_cell)])
				failures+=1
				continue
			game.renderer.placement = "factory"
			game.renderer.placement_rotation = posmod(offset.x + offset.y,4)
			game.renderer.placement_cell = target_cell
			game.renderer.placement_cell_valid = true
			game.renderer.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var preview := core_region(game,core)
			print("VISUAL SHOWCASE SAMPLE: mode %d placement %s frame %d FPS %d VFX tier %d equal %s" % [mode,str(offset),Engine.get_process_frames(),Engine.get_frames_per_second(),game.renderer.vfx_budget_tier,str(preview==baseline)])
			if preview != baseline:
				var changed_bytes := 0
				for byte_index in baseline.size():
					if baseline[byte_index] != preview[byte_index]: changed_bytes += 1
				var sample_index := failures
				save_core_region(game,core,"res://test-output/main_placement_failure_mode_%d_sample_%d.png" % [mode,sample_index])
				printerr("VISUAL SHOWCASE FAIL: mode %d placement at %s changed core pixels (%d/%d bytes; evidence saved)" % [mode,str(offset),changed_bytes,baseline.size()])
				printerr("VISUAL SHOWCASE DIAGNOSTIC: elapsed %.6f -> %.6f; frame %d; paused %s; renderer_visual_paused %s; mode %d; vfx tier %d -> %d; FPS %d" % [stable_elapsed,game.renderer.elapsed,Engine.get_process_frames(),str(game.paused),str(game.renderer.visual_paused),mode,stable_vfx_tier,game.renderer.vfx_budget_tier,Engine.get_frames_per_second()])
				failures += 1
	game.renderer.placement = ""
	game.renderer.placement_cell_valid = false
	game.set_display_mode(1)
	await capture("industrial_2d_full_hd_placement_review")
	game.set_display_mode(2)
	await process_frame
	game.renderer.benchmark_vfx_tier_override = previous_vfx_tier_override
	game.renderer.heat_layer.visible = shimmer_was_visible
	game.renderer.queue_redraw()
	if failures > 0:
		push_error("VISUAL SHOWCASE: %d full-game placement stability check(s) failed" % failures)
		quit(1)
		return false
	return true

func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	# Isolated art fixture: uses the shipped renderer and all shipped entity definitions.
	for e in game.sim.entities.values():
		if e.building: game.sim.grid.reserve(e.cell,game.sim.definition(e).footprint,0,false)
	game.sim.entities.clear(); game.sim.known=[{},{}]
	var building_ids: Dictionary={}
	var index := 0
	for kind in ["core","power","factory","refinery","repair","radar","tower","armory"]:
		var cell := Vector2i(10+(index%4)*5,37+floori(index/4.0)*6)
		var building_id: int=game.sim.spawn(kind,0,Vector2(cell)*32,true)
		building_ids[kind]=building_id
		if kind in ["factory","refinery","radar"]: game.sim.entities[building_id].upgrade_level=1
		if kind=="armory": game.sim.entities[building_id].upgrade_level=2
		if kind=="factory": game.sim.entities[building_id].queue.append({"kind":"tank"})
		if kind=="repair":
			game.sim.entities[building_id].repair=true
			game.sim.entities[building_id].hp-=120
		if kind=="tower": game.sim.entities[building_id].turret=1.1
		index+=1
	index=0
	for kind in ["scout","tank","siege","harvester","raider","lancer","scorcher","bulwark"]:
		var id: int = game.sim.spawn(kind,0,Vector2(330+(index%4)*150,1460+floori(index/4.0)*70),false)
		game.sim.entities[id].angle=-0.35; game.sim.entities[id].turret=-0.65
		game.sim.entities[id].cargo=160.0
		if kind=="harvester":
			game.sim.entities[id].harvest_state="UNLOAD"
			game.selected=[id]
			game.renderer.selected=[id]
			game.sim.entities[id].pos=game.sim.entities[building_ids["refinery"]].pos+Vector2(25,18)
		index+=1
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=Vector2(636,1394); game.renderer.zoom=2.15
	game.renderer.fog_timer=0
	game.category="buildings"; game.build_hud()
	# Let the real in-game cache render each authored model and settle its active
	# phase before saving visual QA, instead of capturing temporary 2D fallbacks.
	await create_timer(3.0).timeout
	game.renderer.queue_redraw()
	await process_frame
	var core_entity: Dictionary = game.sim.entities[building_ids["core"]]
	var placement_stable: bool = await verify_main_game_placement(game,core_entity)
	if not placement_stable: return
	await capture("industrial_showcase_v0.38.0")
	var standard_zoom:float=game.renderer.zoom
	for zoom_factor in [1.25,1.5]:
		game.renderer.zoom=standard_zoom*zoom_factor
		game.renderer.queue_redraw()
		await create_timer(0.9).timeout
		await capture("industrial_detail_zoom_%d_v0.38.0"%roundi(zoom_factor*100.0))
	game.renderer.zoom=standard_zoom
	game.renderer.queue_redraw()
	game.sim.effects.append({"pos":Vector2(820,1480),"life":0.65,"max_life":0.8,"radius":55.0})
	game.sim.effects.append({"pos":Vector2(720,1510),"life":0.22,"max_life":0.35,"radius":24.0})
	var tank: Dictionary = game.sim.entities.values().filter(func(e):return e.kind=="tank")[0]
	game.renderer.visual_event("shot",tank.pos)
	game.sim.projectiles.append({"pos":tank.pos+Vector2(70,-40),"last":Vector2(820,1480),"owner":0,"weapon":"cannon","target":0,"life":1.0})
	# Weapon identifiers come from the catalog, not an assumed hard-coded name.
	game.sim.projectiles[0].weapon=game.sim.definition(tank).weapon
	await capture("modern_effects_v0.38.0")
	game.set_classic(true)
	await capture("industrial_classic_v0.38.0")
	game.music.shutdown(); game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("VISUAL SHOWCASE: all 8 buildings and 8 vehicles rendered in Modern and Classic")
	quit()
