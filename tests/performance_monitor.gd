extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("PERFORMANCE MONITOR: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro()
	game.set_classic(false)
	game.start_game()
	var profiler_key:=InputEventKey.new()
	profiler_key.keycode=KEY_F3; profiler_key.pressed=true
	game._unhandled_input(profiler_key)
	game.renderer.queue_redraw()
	await process_frame
	game.update_hud()
	check(game.renderer.profile_enabled,"F3 enables the render profiler")
	check(game.renderer.profile_total_ms>0.0 and game.renderer.profile_terrain_ms>=0.0,"F3 render profiler captures frame and terrain timings")
	check(game.debug_label.text.contains("ZEICHNEN") and game.debug_label.text.contains("WRACKS"),"F3 overlay shows render categories and wreck counts")
	game._unhandled_input(profiler_key)
	await process_frame
	check(is_instance_valid(game.fps_label) and game.fps_label.text.begins_with("FPS"),"FPS readout exists in mission HUD")
	game.fps_sample_elapsed=0.0; game.fps_sample_frames=0
	for i in 25: game.monitor_frame_rate(1.0/60.0)
	check(game.fps_label.text=="FPS 60","FPS readout updates from measured frames")
	game.performance_log_path="res://test-output/performance_monitor_test.csv"
	if FileAccess.file_exists(game.performance_log_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(game.performance_log_path))
	game.record_performance_sample(55.0,0.5)
	check(not FileAccess.file_exists(game.performance_log_path),"Short dip is ignored to avoid transient noise")
	check(game.renderer.profile_enabled and not game.profiler_overlay_visible,"Sub-60 FPS automatically enables silent diagnostic profiling")
	game.record_performance_sample(55.0,0.6)
	check(FileAccess.file_exists(game.performance_log_path),"Sustained sub-60 FPS creates a log")
	var lines:=FileAccess.get_file_as_string(game.performance_log_path).strip_edges().split("\n")
	check(lines.size()==2 and lines[0].contains("entities,units,buildings") and lines[0].contains("terrain_ms") and lines[0].contains("vehicle_cache_queue") and lines[1].contains("LOW_FPS_WARNING"),"Low-FPS row includes object counts and renderer/cache breakdown")
	check(lines[0].split(",").size()==lines[1].split(",").size(),"Performance CSV header and event rows have matching columns")
	check(lines[1].contains(",55.00,55.00,"),"Low-FPS row records average and minimum FPS")
	game.record_performance_sample(49.0,0.4)
	lines=FileAccess.get_file_as_string(game.performance_log_path).strip_edges().split("\n")
	check(lines.size()==3 and lines[2].contains("LOW_FPS_SAMPLE") and lines[2].contains(",49.00,49.00,"),"Active slow periods log each sampled frame window")
	game.record_performance_sample(49.0,0.4)
	lines=FileAccess.get_file_as_string(game.performance_log_path).strip_edges().split("\n")
	check(lines.size()==4 and lines[3].contains("LOW_FPS_CRITICAL") and lines[3].contains(",49.00,49.00,"),"Sustained sub-50 FPS receives a separate critical event")
	game.record_performance_sample(65.0,0.5)
	check(FileAccess.get_file_as_string(game.performance_log_path).strip_edges().split("\n").size()==4,"Brief recovery does not prematurely close the event")
	game.record_performance_sample(65.0,0.5)
	lines=FileAccess.get_file_as_string(game.performance_log_path).strip_edges().split("\n")
	check(lines.size()==5 and lines[4].contains("RECOVERED") and not game.renderer.profile_enabled,"Recovery is logged only after one second above 60 FPS and silent profiling stops")
	for row in lines.slice(1): check(row.split(",").size()==lines[0].split(",").size(),"Every performance event retains the documented CSV schema")
	game.music.shutdown()
	game.queue_free()
	await process_frame
	if FileAccess.file_exists("res://test-output/performance_monitor_test.csv"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test-output/performance_monitor_test.csv"))
	print("PERFORMANCE MONITOR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
