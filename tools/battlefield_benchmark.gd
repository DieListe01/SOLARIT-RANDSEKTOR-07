extends SceneTree

var game: Control
var sample_label := "before"
var results: Array[Dictionary] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): sample_label = args[0]
	call_deferred("run")

func sample(mode: String) -> void:
	game.start_game()
	game.set_process(false)
	game.sim.ai_timer = 99999
	game.sim.ai_production_timer = 99999
	for entity in game.sim.entities.values():
		if not entity.building: game.sim.entities.erase(entity.id)
	for i in 40:
		var owner := 0 if mode == "idle" or i < 20 else 1
		var column := i % 5
		var row := i / 5 if mode == "idle" else (i % 20) / 5
		var position := Vector2(380 + column * 62 + (280 if owner == 1 else 0), 1300 + row * 64)
		var id: int = game.sim.spawn(["tank", "scout", "siege", "harvester"][i % 4], owner, position, false)
		game.sim.entities[id].hp = 100000.0
		game.sim.entities[id].max_hp = 100000.0
		game.sim.entities[id].order = "hold"
	game.sim.fog[0].fill(1)
	game.sim.explored[0].fill(1)
	game.renderer.camera = Vector2(700, 1420)
	game.renderer.zoom = 1.0
	game.renderer.health_mode = "damaged"
	game.renderer.profile_enabled = true
	game.renderer.selected = game.sim.entities.keys().filter(func(id): return not game.sim.entities[id].building and game.sim.entities[id].owner == 0)
	for frame in 120:
		if mode == "battle": game.sim.tick(1.0 / 30.0)
		await process_frame
	if mode == "combat-static":
		game.renderer.combat_fx.reset()
		game.sim.effects.clear(); game.sim.projectiles.clear()
		game.renderer.tracks.clear(); game.renderer.visual_bursts.clear()
	var durations: Array[float] = []
	var calls := 0.0
	var sim_total := 0.0
	var sim_peak := 0.0
	var last := Time.get_ticks_usec()
	for frame in 180:
		if mode == "battle":
			var sim_started := Time.get_ticks_usec()
			game.sim.tick(1.0 / 30.0)
			var sim_elapsed := float(Time.get_ticks_usec()-sim_started)/1000.0
			sim_total+=sim_elapsed; sim_peak=maxf(sim_peak,sim_elapsed)
		await process_frame
		var now := Time.get_ticks_usec()
		durations.append((now - last) / 1000.0)
		last = now
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	durations.sort()
	var total := 0.0
	for duration in durations: total += duration
	var renderer = game.renderer
	var result := {"mode": mode, "fps": 180000.0 / total, "frame_ms": total / 180.0, "p95_ms": durations[170], "draw_calls": calls / 180.0, "sim_avg_ms": sim_total/180.0, "sim_peak_ms": sim_peak, "visible_units": renderer.visible_mobile_count, "vfx": renderer.active_vfx_count, "renderer_ms": renderer.profile_total_ms, "terrain_ms": renderer.profile_terrain_ms, "tracks_ms": renderer.profile_tracks_ms, "wrecks_ms": renderer.profile_wrecks_ms, "buildings_ms": renderer.profile_buildings_ms, "vehicles_ms": renderer.profile_vehicles_ms, "combat_fx_ms": renderer.profile_combat_fx_ms, "projectiles_ms": renderer.profile_projectiles_ms, "impacts_ms": renderer.profile_impacts_ms, "explosions_ms": renderer.profile_explosions_ms, "smoke_ms": renderer.profile_smoke_ms, "fog_ms": renderer.profile_fog_ms, "projectiles": renderer.profile_projectile_count, "impacts": renderer.profile_impact_count, "particles": renderer.profile_particle_count, "vehicle_cache_size": renderer.vehicle_texture_cache.size(), "vehicle_cache_queue": renderer.vehicle_cache_queue.size(), "resolution": root.size, "zoom": renderer.zoom}
	results.append(result)
	print("BATTLEFIELD BENCHMARK ", sample_label, " ", JSON.stringify(result))
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/battlefield-" + sample_label + "-" + mode + ".png")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro()
	game.set_classic(false)
	await sample("idle")
	await sample("combat-static")
	await sample("battle")
	var file := FileAccess.open("res://test-output/battlefield-" + sample_label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	game.music.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
