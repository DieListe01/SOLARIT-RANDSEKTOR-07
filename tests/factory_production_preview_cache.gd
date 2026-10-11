extends SceneTree

const PreviewCacheScript = preload("res://scripts/production_preview_cache.gd")

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro()
	await game.start_game()
	game.paused = true
	var cache = game.renderer.production_preview_cache
	check(cache != null and cache.warmed, "Factory pose catalog finishes during paused mission loading")
	var expected: int = int(game.sim.factions.size()) * int(game.sim.db.units.size()) * 4
	check(cache.created_view_count == expected, "All unit roles, active factions and factory exit directions are prewarmed")
	check(cache.readback_count == 0, "GPU-resident production views require no CPU readbacks")
	var initial_count: int = int(cache.created_view_count)
	for owner in game.sim.factions.size():
		for kind_value in game.sim.db.units.keys():
			var kind := str(kind_value)
			for direction in 4:
				var texture: Texture2D = cache.texture_for(kind,owner,float(direction)*TAU/4.0)
				check(texture != null and texture.get_size() == Vector2(256,256), "Prewarmed production texture exists for %s, faction %s, heading %d" % [kind,game.sim.factions[owner],direction])
	check(cache.created_view_count == initial_count, "Combat-time cache lookup creates no new pose views")
	check(cache.readback_count == 0, "Combat-time cache lookup still performs zero GPU-to-CPU readbacks")
	for viewport_value in cache.viewports.values():
		var viewport := viewport_value as SubViewport
		check(viewport != null and viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Cached production SubViewports render once and stay GPU-resident")
		break
	game.music.shutdown()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("FACTORY PREVIEW CACHE: %d checks, 0 failures" % checks)
		quit(0)
	else:
		printerr("FACTORY PREVIEW CACHE: %d checks, %d failures" % [checks,failures.size()])
		quit(1)
