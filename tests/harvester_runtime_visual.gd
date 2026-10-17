extends SceneTree

var failures: Array[String] = []
var checks := 0
var game: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("HARVESTER VISUAL FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	game.renderer.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(),"Rendered match capture is available: "+name_value)
	if image != null and not image.is_empty():
		var path := "res://test-output/%s.png" % name_value
		check(image.save_png(ProjectSettings.globalize_path(path)) == OK,"Rendered match capture is saved: "+name_value)

func capture_closeup(name_value: String) -> void:
	var previous_camera: Vector2 = game.renderer.camera
	var previous_zoom: float = game.renderer.zoom
	game.renderer.camera = Vector2(508,1440)
	game.renderer.zoom = 2.3
	await capture(name_value+"_closeup")
	game.renderer.camera = previous_camera
	game.renderer.zoom = previous_zoom
	game.renderer.queue_redraw()

func capture_motion_sequence(name_value: String, frame_count: int = 24) -> void:
	# Keep adjacent rendered frames from the live match so the runtime acceptance
	# can be inspected as motion, not inferred from one still per state.
	var sequence_dir := "res://test-output/harvester_motion_%s" % name_value
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sequence_dir))
	var telemetry_path := ProjectSettings.globalize_path(sequence_dir.path_join("frames.csv"))
	var telemetry := FileAccess.open(telemetry_path, FileAccess.WRITE)
	check(telemetry != null, "Motion capture telemetry opens for %s" % name_value)
	if telemetry == null: return
	telemetry.store_line("frame,harvest_state,cargo,x,y,angle,speed")
	for frame_index in frame_count:
		await process_frame
		await RenderingServer.frame_post_draw
		var entity: Dictionary = game.sim.entities.get(game.get_meta("motion_capture_entity_id", 0), {})
		var texture := root.get_texture()
		var image := texture.get_image() if texture != null else null
		check(image != null and image.get_width() == 1920 and image.get_height() == 1080, "Motion frame is rendered at Full HD: %s %02d" % [name_value, frame_index])
		if image != null and image.get_width() == 1920 and image.get_height() == 1080:
			var crop := image.get_region(Rect2i(330, 250, 900, 700))
			var frame_path := ProjectSettings.globalize_path(sequence_dir.path_join("frame_%04d.png" % frame_index))
			check(crop.save_png(frame_path) == OK, "Adjacent motion frame is saved: %s %02d" % [name_value, frame_index])
		var position: Vector2 = entity.get("pos", Vector2.ZERO)
		var velocity: Vector2 = entity.get("velocity", Vector2.ZERO)
		telemetry.store_line("%d,%s,%.3f,%.3f,%.3f,%.5f,%.3f" % [frame_index, str(entity.get("harvest_state", "missing")), float(entity.get("cargo", 0.0)), position.x, position.y, float(entity.get("angle", 0.0)), velocity.length()])
	telemetry.close()

func advance_ticks(count: int) -> void:
	for _tick in count:
		game.sim.tick(1.0/30.0)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro()
	game.start_game()
	game.sim.ai_timer = 99999.0
	game.sim.ai_production_timer = 99999.0
	for _frame in 360:
		if not game.vehicle_pose_warmup_active: break
		await process_frame
	var sim: Simulation = game.sim
	var refinery_cell := Vector2i(14,47)
	var collector_cell := Vector2i(17,43)
	var refinery_id: int = sim.spawn("refinery",0,sim.grid.center(refinery_cell),true)
	var collector_id: int = sim.spawn("harvester",0,sim.grid.center(collector_cell),false)
	check(refinery_id > 0 and collector_id > 0,"A live refinery and collector are placed in the mission")
	var collector: Dictionary = sim.entities[collector_id]
	game.set_meta("motion_capture_entity_id", collector_id)
	game.selected = [collector_id]
	game.renderer.selected = [collector_id]
	game.renderer.camera = Vector2(528,1440)
	game.renderer.zoom = 1.1
	sim.view_owner = 0
	sim.update_fog()
	# This fixture inserts a refinery directly, so the mission's initial
	# "build an Impulswerk" toast is misleading in these screenshots.
	game.set("notice_timer", 0.0)
	var notice_label := game.get("notification") as Label
	if notice_label != null: notice_label.text = ""
	game.update_hud()
	await create_timer(0.8).timeout
	await capture("harvester_runtime_idle")
	var capacity := float(sim.db.rules.harvest_capacity)
	var saw_cargo := false
	var saw_loaded_return := false
	var saw_loaded_approach := false
	var saw_unload := false
	var saw_resumed_work := false
	var captured_harvest_motion := false
	var captured_unload_motion := false
	for _tick in 3000:
		sim.tick(1.0/30.0)
		if not sim.entities.has(collector_id): break
		collector = sim.entities[collector_id]
		if not captured_harvest_motion and str(collector.harvest_state) == "HARVEST":
			captured_harvest_motion = true
			await capture_motion_sequence("harvesting")
		if not saw_cargo and float(collector.cargo) >= capacity*0.2:
			saw_cargo = true
			game.update_hud()
			await capture("harvester_runtime_loaded")
			await capture_closeup("harvester_runtime_loaded")
		if str(collector.harvest_state) == "RETURN_TO_BASE" and float(collector.cargo) > 0.0:
			saw_loaded_return = true
			var refinery_pos: Vector2 = sim.entities[refinery_id].pos
			if not saw_loaded_approach and collector.pos.distance_to(refinery_pos) < 120.0:
				saw_loaded_approach = true
				game.update_hud()
				await capture("harvester_runtime_returning")
				await capture_closeup("harvester_runtime_returning")
		if str(collector.harvest_state) == "UNLOAD" and not saw_unload:
			saw_unload = true
			captured_unload_motion = true
			game.update_hud()
			await capture("harvester_runtime_unloading")
			await capture_closeup("harvester_runtime_unloading")
			await capture_motion_sequence("unloading")
		if saw_unload and str(collector.harvest_state) in ["SEARCH_RESOURCE","MOVE_TO_RESOURCE","HARVEST"] and float(collector.cargo) == 0.0:
			saw_resumed_work = true
			game.update_hud()
			await capture("harvester_runtime_resumed")
			break
	check(saw_cargo,"Gameplay cargo rises before the collector returns")
	check(saw_loaded_return,"A loaded collector enters the return-to-refinery state")
	check(saw_loaded_approach,"The loaded collector visibly approaches the refinery")
	check(saw_unload,"The collector enters the refinery unloading state")
	check(captured_harvest_motion,"Adjacent rendered frames were recorded during harvesting")
	check(captured_unload_motion or saw_unload,"Adjacent rendered frames were recorded during unloading")
	check(saw_resumed_work,"The emptied collector resumes autonomous resource work")
	check(game.information.text.contains("/ %d" % int(capacity)),"Selected-collector HUD shows its cargo capacity")
	check(float(sim.stats.gathered) > 0.0,"Unloading credits harvested resources to the match")
	game.music.shutdown()
	game.queue_free()
	await process_frame
	print("HARVESTER RUNTIME VISUAL: %d checks, %d failures" % [checks,failures.size()])
	if not failures.is_empty(): quit(1)
	else: quit(0)
