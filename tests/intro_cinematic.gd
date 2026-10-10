extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	var cinematic := load("res://scripts/intro_cinematic.gd").new() as IntroCinematic
	cinematic.size = Vector2(1920, 1080)
	root.add_child(cinematic)
	await process_frame
	await process_frame
	assert(cinematic.process_mode == Node.PROCESS_MODE_ALWAYS, "cinematic advances while the game shell is paused")
	assert(cinematic.world_root != null and cinematic.camera != null, "intro owns a real 3D scene and camera")
	assert(cinematic.world_root.find_child("Cinematic core", true, false) != null, "intro reuses the current command bunker GLB")
	assert(cinematic.world_root.find_child("Cinematic refinery", true, false) != null, "intro reuses the current refinery GLB")
	assert(cinematic.world_root.find_child("Cinematic Solarit harvester", true, false) != null, "intro reuses the current animated harvester GLB")
	var output_dir := ProjectSettings.globalize_path("res://test-output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	cinematic.elapsed = 5.0
	await process_frame
	await RenderingServer.frame_post_draw
	assert(cinematic.location_label.modulate.a > 0.9 and cinematic.caption_label.modulate.a > 0.9, "mid-intro location and story captions fade in")
	assert(cinematic.second_title.modulate.a < 0.1, "final title remains hidden during the landing beat")
	var landing := root.get_texture().get_image()
	assert(landing.save_png("res://test-output/intro_3d_landing.png") == OK, "landing beat screenshot is saved")
	cinematic.elapsed = 13.0
	await process_frame
	await RenderingServer.frame_post_draw
	assert(cinematic.title_label.modulate.a > 0.9 and cinematic.second_title.modulate.a > 0.9, "the final title and closing line fade in over the colony")
	var reveal := root.get_texture().get_image()
	assert(reveal.save_png("res://test-output/intro_3d_title.png") == OK, "3D reveal screenshot is saved")
	var difference := 0.0
	for y in range(0, 1080, 8):
		for x in range(0, 1920, 8):
			var a := landing.get_pixel(x, y)
			var b := reveal.get_pixel(x, y)
			difference += absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b)
	assert(difference > 20.0, "cinematic stages produce different rendered frames")
	var completed := [false]
	cinematic.completed.connect(func(): completed[0] = true)
	cinematic.finished = false
	cinematic.elapsed = IntroCinematic.DURATION - 0.005
	cinematic._process(0.016)
	assert(completed[0], "cinematic completes on its own timeline")
	print("3D INTRO: GLB colony, animated harvester, distinct story/reveal frames verified")
	quit()
