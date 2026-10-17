extends SceneTree

var checks := 0
var failures: Array[String] = []
var game: Control

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("PLACEMENT INPUT FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func click(local_position: Vector2, button_index: int = MOUSE_BUTTON_LEFT, pressed: bool = true) -> void:
	var raw: Vector2 = root.get_final_transform() * game.get_global_transform_with_canvas() * local_position
	var motion := InputEventMouseMotion.new()
	motion.position = raw
	motion.global_position = raw
	Input.parse_input_event(motion)
	var button := InputEventMouseButton.new()
	button.position = raw
	button.global_position = raw
	button.button_index = button_index
	button.pressed = pressed
	Input.parse_input_event(button)
	await process_frame

func move_pointer(local_position: Vector2) -> void:
	var raw: Vector2 = root.get_final_transform() * game.get_global_transform_with_canvas() * local_position
	var motion := InputEventMouseMotion.new()
	motion.position = raw
	motion.global_position = raw
	Input.parse_input_event(motion)
	await process_frame
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.commander_profile.path = "user://ui_commander_profile.json"
	game.commander_profile.load_profile()
	game.commander_profile.set_nickname("DIRK")
	game.skip_intro()
	await create_timer(0.8).timeout
	game.start_game()
	print("PLACEMENT INPUT: mission started")
	game.sim.ai_timer = 99999
	game.renderer.building_visual_diagnostics_enabled = true
	game.renderer.building_visual_event_log.clear()
	var warmup_started_ms := Time.get_ticks_msec()
	var last_warmup_heartbeat_ms := warmup_started_ms
	while game.vehicle_pose_warmup_active and Time.get_ticks_msec() - warmup_started_ms < 150000:
		await process_frame
		var now_ms := Time.get_ticks_msec()
		if now_ms - last_warmup_heartbeat_ms >= 30000:
			last_warmup_heartbeat_ms = now_ms
			print("PLACEMENT INPUT WARMUP HEARTBEAT: runtime_s=", (now_ms - warmup_started_ms) / 1000, " active=", game.vehicle_pose_warmup_active, " pose_queue=", game.renderer.vehicle_cache_queue.size(), " pending=", game.renderer.pending_pose_keys.size())
	if game.vehicle_pose_warmup_active:
		verify(false, "vehicle-view startup warm-up finishes within 150 seconds")
		print("PLACEMENT INPUT RESULT: %d checks, %d failures" % [checks, failures.size()])
		quit(1)
		return
	print("PLACEMENT INPUT: pose warmup complete active=false")
	var core: Dictionary = game.sim.buildings(0, "core")[0]
	var stale_cell: Vector2i = game.sim.grid.cell(core.pos)
	game.renderer.placement_cell = stale_cell
	game.renderer.placement_cell_valid = true
	var button_position: Vector2 = game.get_global_transform_with_canvas().affine_inverse() * game.buttons.power.get_global_rect().get_center()
	await click(button_position)
	await click(button_position, MOUSE_BUTTON_LEFT, false)
	print("PLACEMENT INPUT: catalog click processed")
	verify(game.placement == "power", "clicking the build catalog enters power placement")
	verify(not game.renderer.placement_cell_valid, "new placement invalidates the previous map cell")
	var pointer_position: Vector2 = game.WORLD_RECT.get_center() + Vector2(180, 0)
	await move_pointer(pointer_position)
	var expected_cell: Vector2i = game.sim.grid.cell(game.screen_world(game.pointer_local))
	print("PLACEMENT INPUT: pointer motion processed local=", game.pointer_local, " expected=", pointer_position, " world=", game.screen_world(game.pointer_local), " actual_cell=", game.renderer.placement_cell, " expected_cell=", expected_cell)
	verify(game.renderer.placement_cell_valid, "the first in-world mouse motion validates the placement cell")
	verify(game.renderer.placement_cell == expected_cell, "the preview cell follows the current pointer exactly")
	verify(expected_cell != stale_cell, "the current pointer selects a cell different from the stale pre-placement cell")
	var frame_samples: Array[Dictionary] = []
	for frame_number in 3:
		if frame_number > 0:
			await process_frame
			await process_frame
		var latest_preview: Dictionary = {}
		for event in game.renderer.building_visual_event_log:
			if str(event.get("event", "")) == "placement_preview_drawn":
				latest_preview = event
		verify(int(latest_preview.get("cell_x", -1)) == expected_cell.x and int(latest_preview.get("cell_y", -1)) == expected_cell.y and bool(latest_preview.get("cell_valid", false)), "rendered frame %d has a valid preview only at the pointer cell" % frame_number)
		frame_samples.append({"frame": frame_number, "cell_x": latest_preview.get("cell_x", -1), "cell_y": latest_preview.get("cell_y", -1), "cell_valid": latest_preview.get("cell_valid", false)})
		print("PLACEMENT INPUT FRAME: ", JSON.stringify(frame_samples[-1]))
	var event_file := FileAccess.open("res://test-output/placement_input_frames.json", FileAccess.WRITE)
	if event_file != null:
		event_file.store_string(JSON.stringify(frame_samples, "\t"))
		event_file.close()
	verify(event_file != null, "three adjacent preview render events are saved as a diagnostic artifact")
	game.renderer.building_visual_diagnostics_enabled = false
	game.queue_free()
	await process_frame
	print("PLACEMENT INPUT RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
