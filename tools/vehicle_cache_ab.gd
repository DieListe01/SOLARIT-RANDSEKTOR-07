extends SceneTree

## GPU-only A/B run. Launch without --headless, once per variant, so every
## variant gets a fresh process and exactly the same scene/warm-up sequence.
const WARMUP_FRAMES := 360
const SAMPLE_FRAMES := 900
const VEHICLE_COUNT := 40
const VARIANTS := {
	"A": {"resolution": 512, "msaa": Viewport.MSAA_4X, "cache_capacity": 192},
	"B": {"resolution": 512, "msaa": Viewport.MSAA_DISABLED, "cache_capacity": 192},
	"C": {"resolution": 384, "msaa": Viewport.MSAA_2X, "cache_capacity": 192},
	"D": {"resolution": 256, "msaa": Viewport.MSAA_DISABLED, "cache_capacity": 192},
	"AW": {"resolution": 512, "msaa": Viewport.MSAA_4X, "cache_capacity": 768},
	"BW": {"resolution": 512, "msaa": Viewport.MSAA_DISABLED, "cache_capacity": 768},
	"CW": {"resolution": 384, "msaa": Viewport.MSAA_2X, "cache_capacity": 768},
	"DW": {"resolution": 256, "msaa": Viewport.MSAA_DISABLED, "cache_capacity": 768},
	"G": {"resolution": 512, "msaa": Viewport.MSAA_4X, "cache_capacity": 640},
	"W": {"resolution": 512, "msaa": Viewport.MSAA_4X, "cache_capacity": 768},
}

var game: Control
var variant := "A"
var unit_ids: Array[int] = []
var trace_rows: Array[String] = ["variant,stage,frame,frame_ms,fps,sim_tick_ms,cache_hits,cache_misses,poses_created,readbacks,readback_ms,subviewport_wait_ms,active_subviewports,cache_size,world_renderer_ms,terrain_ms,ground_fx_ms,wrecks_ms,buildings_ms,vehicles_ms,tracks_ms,projectiles_ms,impacts_ms,explosions_ms,smoke_ms,fog_ms,visible_vehicles,moving_vehicles,visible_wrecks"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): variant = str(args[0]).to_upper()
	if not VARIANTS.has(variant):
		push_error("Usage: vehicle_cache_ab.gd A|B|C|D|AW|BW|CW|DW|G|W")
		quit(2)
		return
	call_deferred("run")

func settle(frames: int) -> void:
	for _frame in frames: await process_frame

func setup_scene() -> void:
	game.set_process(false)
	game.sim.ai_timer = 999999.0
	game.sim.ai_production_timer = 999999.0
	var remove_ids: Array[int] = []
	for entity_id in game.sim.entities:
		if not game.sim.entities[entity_id].building: remove_ids.append(int(entity_id))
	for entity_id in remove_ids: game.sim.entities.erase(entity_id)
	game.renderer.camera = Vector2(700, 1420)
	game.renderer.zoom = 1.0
	game.renderer.health_mode = "damaged"
	game.renderer.profile_enabled = true
	game.renderer.vehicle_cache_resolution = int(VARIANTS[variant].resolution)
	game.renderer.vehicle_cache_msaa = int(VARIANTS[variant].msaa)
	game.renderer.vehicle_cache_capacity = int(VARIANTS[variant].get("cache_capacity", 192))
	game.renderer.vehicle_cache_diagnostics_enabled = true
	game.renderer.vehicle_texture_cache.clear()
	game.renderer.vehicle_cache_pending.clear()
	game.renderer.vehicle_cache_queue.clear()
	game.renderer.vehicle_cache_hits_total = 0
	game.renderer.vehicle_cache_misses_total = 0
	game.renderer.vehicle_cache_new_poses_total = 0
	game.renderer.vehicle_cache_readbacks_total = 0
	game.renderer.vehicle_cache_evictions_total = 0
	game.renderer.vehicle_cache_recreated_poses_total = 0
	game.renderer.vehicle_cache_created_keys.clear()
	game.renderer.vehicle_cache_render_wait_ms_total = 0.0
	game.renderer.vehicle_cache_readback_ms_total = 0.0
	game.renderer.vehicle_cache_event_log.clear()
	game.renderer.vehicle_cache_peak_subviewports = 0
	unit_ids.clear()
	for i in VEHICLE_COUNT:
		var owner := 0 if i < VEHICLE_COUNT / 2 else 1
		var column := i % 5
		var row := (i % 20) / 5
		var position: Vector2 = Vector2(700 + (-280 if owner == 0 else 280) + column * 58, 1420 - 116 + row * 58)
		var kinds := ["tank", "scout", "siege", "raider"]
		var entity_id: int = game.sim.spawn(kinds[i % kinds.size()], owner, position, false)
		var entity: Dictionary = game.sim.entities[entity_id]
		entity.hp = 100000.0
		entity.max_hp = 100000.0
		entity.order = "hold"
		entity.harvest_state = "HARVEST" if entity.kind == "harvester" else "IDLE"
		unit_ids.append(entity_id)
	game.sim.rebuild_movement_buckets()
	game.sim.fog[0].fill(1)
	game.sim.explored[0].fill(1)
	game.renderer.selected = unit_ids.filter(func(id): return game.sim.entities[id].owner == 0)
	game.sim.command(unit_ids.slice(0, 20), Vector2(980, 1420), "attack_move")
	game.sim.command(unit_ids.slice(20, 40), Vector2(420, 1420), "attack_move")
	# Preserve an identical active skirmish, including projectile and wreck costs,
	# in every process. Advance simulation at a fixed 30 Hz on every benchmark frame.
	for i in range(20):
		var left: Vector2 = game.sim.entities[unit_ids[i]].pos
		var right: Vector2 = game.sim.entities[unit_ids[i + 20]].pos
		game.sim.projectiles.append({"pos": left, "last": right, "target": unit_ids[i + 20], "owner": 0, "weapon": "cannon", "life": 3.0})
	for i in 16:
		var position: Vector2 = game.renderer.camera + Vector2(-400 + (i % 8) * 110, -200 + floori(float(i) / 8.0) * 300)
		game.renderer.combat_fx.emit_effect("destroy", {"pos": position, "angle": float(i) * 0.29, "building": false, "kind": "tank"})
	game.renderer.queue_redraw()

func record_frame(stage: String, index: int, previous_usec: int, previous: Dictionary, sim_tick_ms: float = 0.0) -> Dictionary:
	var now := Time.get_ticks_usec()
	var renderer = game.renderer
	var frame_duration := float(now - previous_usec) / 1000.0
	var new_poses: int = renderer.vehicle_cache_new_poses_total - int(previous["poses"])
	var readbacks: int = renderer.vehicle_cache_readbacks_total - int(previous["readbacks"])
	var readback_ms: float = renderer.vehicle_cache_readback_ms_total - float(previous["readback_ms"])
	var subviewport_ms: float = renderer.vehicle_cache_render_wait_ms_total - float(previous["render_wait_ms"])
	var moving_vehicles := 0
	for entity in renderer.sim.entities.values():
		if not entity.building and entity.velocity.length() > 2.0: moving_vehicles += 1
	trace_rows.append(",".join([variant,stage,str(index),"%.3f"%frame_duration,"%.2f"%(1000.0/maxf(frame_duration,0.001)),"%.3f"%sim_tick_ms,str(renderer.vehicle_cache_hits),str(renderer.vehicle_cache_misses),str(new_poses),str(readbacks),"%.3f"%readback_ms,"%.3f"%subviewport_ms,str(renderer.vehicle_cache_active_subviewports),str(renderer.vehicle_texture_cache.size()),"%.3f"%renderer.profile_total_ms,"%.3f"%renderer.profile_terrain_ms,"%.3f"%renderer.profile_ground_fx_ms,"%.3f"%renderer.profile_wrecks_ms,"%.3f"%renderer.profile_buildings_ms,"%.3f"%renderer.profile_vehicles_ms,"%.3f"%renderer.profile_tracks_ms,"%.3f"%renderer.profile_projectiles_ms,"%.3f"%renderer.profile_impacts_ms,"%.3f"%renderer.profile_explosions_ms,"%.3f"%renderer.profile_smoke_ms,"%.3f"%renderer.profile_fog_ms,str(renderer.visible_mobile_count),str(moving_vehicles),str(renderer.combat_fx.ruins.size())]))
	return {"time": now, "poses": renderer.vehicle_cache_new_poses_total, "misses": renderer.vehicle_cache_misses_total, "readbacks": renderer.vehicle_cache_readbacks_total, "readback_ms": renderer.vehicle_cache_readback_ms_total, "render_wait_ms": renderer.vehicle_cache_render_wait_ms_total}

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle(4)
	game.skip_intro()
	game.set_classic(false)
	game.start_game()
	game.set_process(false)
	# Let the mission renderer import its world, compile shaders and finish its
	# initial (non-test) pose queue before every variant starts from an empty cache.
	var ready_frames := 0
	while game.renderer.material_grid != game.sim.grid and ready_frames < 300:
		await process_frame
		ready_frames += 1
	await settle(120)
	var cache_wait_frames := 0
	while (game.renderer.vehicle_cache_worker_active or not game.renderer.vehicle_cache_queue.is_empty()) and cache_wait_frames < 600:
		await process_frame
		cache_wait_frames += 1
	setup_scene()
	print("CACHE A/B ", variant, " | ", VARIANTS[variant], " | renderer=", RenderingServer.get_current_rendering_method(), " | resolution=1920x1080")
	var start := Time.get_ticks_usec()
	var previous_usec := start
	var previous := {"poses": 0, "misses": 0, "readbacks": 0, "readback_ms": 0.0, "render_wait_ms": 0.0}
	var cold_durations: Array[float] = []
	var cold_total_ms := 0.0
	var cold_pose_count := 0
	var cold_miss_count := 0
	var cold_readback_count := 0
	var cold_readback_ms := 0.0
	var cold_wait_ms := 0.0
	for frame in WARMUP_FRAMES:
		if frame > 0 and frame % 120 == 0:
			var reverse_targets := (frame / 120) % 2 == 1
			game.sim.command(unit_ids.slice(0, 20), Vector2(420 if reverse_targets else 980, 1420), "attack_move")
			game.sim.command(unit_ids.slice(20, 40), Vector2(980 if reverse_targets else 420, 1420), "attack_move")
		game.sim.tick(1.0 / 30.0)
		await process_frame
		var current := record_frame("cold_warmup", frame, previous_usec, previous)
		cold_durations.append(float(current.time - previous_usec) / 1000.0)
		cold_total_ms += float(current.time - previous_usec) / 1000.0
		cold_pose_count += int(current.poses) - int(previous.poses)
		cold_miss_count += int(current.misses) - int(previous.misses)
		cold_readback_count += int(current.readbacks) - int(previous.readbacks)
		cold_readback_ms += float(current.readback_ms) - float(previous.readback_ms)
		cold_wait_ms += float(current.render_wait_ms) - float(previous.render_wait_ms)
		previous_usec = int(current.time)
		previous = current
	var warmup_seconds := float(Time.get_ticks_usec() - start) / 1000000.0
	var renderer = game.renderer
	var before := previous.duplicate(true)
	var before_evictions: int = renderer.vehicle_cache_evictions_total
	var before_recreated: int = renderer.vehicle_cache_recreated_poses_total
	var cold_evictions: int = renderer.vehicle_cache_evictions_total
	var frame_ms: Array[float] = []
	var hits := 0
	var misses := 0
	var world_ms := 0.0
	var sim_ms := 0.0
	var render_parts := {"terrain": 0.0, "ground_fx": 0.0, "wrecks": 0.0, "buildings": 0.0, "vehicles": 0.0, "tracks": 0.0, "projectiles": 0.0, "impacts": 0.0, "explosions": 0.0, "smoke": 0.0, "fog": 0.0}
	var cache_active_peak := 0
	var visible_vehicle_sum := 0
	var moving_vehicle_sum := 0
	var visible_wreck_peak := 0
	var cache_size_peak := 0
	var draw_calls := 0.0
	var replay_snapshots: Array[Dictionary] = []
	var start_sample := Time.get_ticks_usec()
	var last := start_sample
	for frame in SAMPLE_FRAMES:
		var global_frame := WARMUP_FRAMES + frame
		if global_frame > 0 and global_frame % 120 == 0:
			var reverse_targets := (global_frame / 120) % 2 == 1
			game.sim.command(unit_ids.slice(0, 20), Vector2(420 if reverse_targets else 980, 1420), "attack_move")
			game.sim.command(unit_ids.slice(20, 40), Vector2(980 if reverse_targets else 420, 1420), "attack_move")
		var sim_started := Time.get_ticks_usec()
		game.sim.tick(1.0 / 30.0)
		var sim_tick_ms := float(Time.get_ticks_usec() - sim_started) / 1000.0
		if variant in ["AW", "BW", "CW", "DW", "W"]:
			var entity_snapshot := {}
			for entity_id in unit_ids:
				if game.sim.entities.has(entity_id): entity_snapshot[entity_id] = game.sim.entities[entity_id].duplicate(true)
			replay_snapshots.append({"time": game.sim.time, "entities": entity_snapshot})
		await process_frame
		var current := record_frame("warm_sample", frame, last, previous, sim_tick_ms)
		frame_ms.append(float(current.time - last) / 1000.0)
		last = int(current.time)
		previous = current
		hits += renderer.vehicle_cache_hits
		misses += renderer.vehicle_cache_misses
		world_ms += renderer.profile_total_ms
		sim_ms += sim_tick_ms
		render_parts.terrain += renderer.profile_terrain_ms
		render_parts.ground_fx += renderer.profile_ground_fx_ms
		render_parts.wrecks += renderer.profile_wrecks_ms
		render_parts.buildings += renderer.profile_buildings_ms
		render_parts.vehicles += renderer.profile_vehicles_ms
		render_parts.tracks += renderer.profile_tracks_ms
		render_parts.projectiles += renderer.profile_projectiles_ms
		render_parts.impacts += renderer.profile_impacts_ms
		render_parts.explosions += renderer.profile_explosions_ms
		render_parts.smoke += renderer.profile_smoke_ms
		render_parts.fog += renderer.profile_fog_ms
		cache_active_peak = maxi(cache_active_peak, renderer.vehicle_cache_active_subviewports)
		visible_vehicle_sum += renderer.visible_mobile_count
		for entity in renderer.sim.entities.values():
			if not entity.building and entity.velocity.length() > 2.0: moving_vehicle_sum += 1
		visible_wreck_peak = maxi(visible_wreck_peak, renderer.combat_fx.ruins.size())
		cache_size_peak = maxi(cache_size_peak, renderer.vehicle_texture_cache.size())
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var sample_seconds := float(Time.get_ticks_usec() - start_sample) / 1000000.0
	var warm_replay := {}
	if variant in ["AW", "BW", "CW", "DW", "W"]:
		# Replay the exact entity poses and simulation clock recorded above. The
		# pose keys are therefore fully resident before this second pass begins.
		var replay_start := Time.get_ticks_usec()
		var replay_last := replay_start
		var replay_times: Array[float] = []
		var replay_before_poses: int = renderer.vehicle_cache_new_poses_total
		var replay_before_readbacks: int = renderer.vehicle_cache_readbacks_total
		var replay_before_readback_ms: float = renderer.vehicle_cache_readback_ms_total
		var replay_previous := {"poses": renderer.vehicle_cache_new_poses_total, "misses": renderer.vehicle_cache_misses_total, "readbacks": renderer.vehicle_cache_readbacks_total, "readback_ms": renderer.vehicle_cache_readback_ms_total, "render_wait_ms": renderer.vehicle_cache_render_wait_ms_total}
		for replay_index in range(replay_snapshots.size()):
			var pose_frame: Dictionary = replay_snapshots[replay_index]
			game.sim.time = float(pose_frame.time)
			for entity_id in unit_ids:
				if pose_frame.entities.has(entity_id): game.sim.entities[entity_id] = pose_frame.entities[entity_id].duplicate(true)
			game.renderer.queue_redraw()
			await process_frame
			var current := record_frame("warm_replay", replay_index, replay_last, replay_previous)
			replay_times.append(float(current.time - replay_last) / 1000.0)
			replay_last = int(current.time)
			replay_previous = current
		replay_times.sort()
		var replay_p99 := replay_times[clampi(ceili(float(replay_times.size()) * 0.99) - 1, 0, replay_times.size() - 1)]
		var replay_sum := 0.0
		for duration in replay_times: replay_sum += duration
		var replay_mean := replay_sum / maxf(1.0, float(replay_times.size()))
		warm_replay = {"frames": replay_times.size(), "average_fps": 1000.0 / replay_mean, "average_frame_ms": replay_mean, "one_percent_low_fps": 1000.0 / replay_p99, "p99_frame_ms": replay_p99, "worst_frame_ms": replay_times.back(), "poses_created": renderer.vehicle_cache_new_poses_total - replay_before_poses, "readbacks": renderer.vehicle_cache_readbacks_total - replay_before_readbacks, "readback_ms": renderer.vehicle_cache_readback_ms_total - replay_before_readback_ms, "cache_size": renderer.vehicle_texture_cache.size()}
		print("FULLY WARM A REPLAY ", JSON.stringify(warm_replay))
	frame_ms.sort()
	var total_frame_ms := 0.0
	var max_frame_ms := 0.0
	for duration in frame_ms:
		total_frame_ms += duration
		max_frame_ms = maxf(max_frame_ms, duration)
	var p99_index := clampi(ceili(float(frame_ms.size()) * 0.99) - 1, 0, frame_ms.size() - 1)
	var mean_frame_ms := total_frame_ms / maxf(1.0, float(frame_ms.size()))
	var p99_ms := frame_ms[p99_index]
	var cold_sorted := cold_durations.duplicate()
	cold_sorted.sort()
	var cold_p99_ms: float = float(cold_sorted[clampi(ceili(float(cold_sorted.size()) * 0.99) - 1, 0, cold_sorted.size() - 1)])
	var cold_max_ms: float = cold_sorted.back()
	var after := {"poses": renderer.vehicle_cache_new_poses_total, "misses": renderer.vehicle_cache_misses_total, "readbacks": renderer.vehicle_cache_readbacks_total, "readback_ms": renderer.vehicle_cache_readback_ms_total, "render_wait_ms": renderer.vehicle_cache_render_wait_ms_total}
	var created_pose_keys: Dictionary = renderer.vehicle_cache_created_keys
	var pose_summary := {}
	for raw_key in created_pose_keys:
		var parts := str(raw_key).split("|")
		if parts.size() < 6: continue
		var kind: String = parts[0]
		if not pose_summary.has(kind): pose_summary[kind] = {"keys": 0, "headings": {}, "turret_frames": {}}
		pose_summary[kind].keys += 1
		pose_summary[kind].headings[parts[4]] = true
		pose_summary[kind].turret_frames[parts[5]] = true
	for kind in pose_summary:
		pose_summary[kind] = {"unique_keys": pose_summary[kind].keys, "body_headings_used": pose_summary[kind].headings.size(), "turret_frames_used": pose_summary[kind].turret_frames.size()}
	var result := {
		"variant": variant, "resolution": renderer.vehicle_cache_resolution, "msaa": int(renderer.vehicle_cache_msaa),
		"renderer": RenderingServer.get_current_rendering_method(), "window": root.size,
		"warmup_frames": WARMUP_FRAMES, "warmup_seconds": warmup_seconds, "sample_frames": SAMPLE_FRAMES,
		"cold_warmup": {"frames": WARMUP_FRAMES, "average_fps": 1000.0 / (cold_total_ms / maxf(1.0, float(cold_durations.size()))), "one_percent_low_fps": 1000.0 / cold_p99_ms, "p99_frame_ms": cold_p99_ms, "worst_frame_ms": cold_max_ms, "poses_created": cold_pose_count, "misses": cold_miss_count, "readbacks": cold_readback_count, "readback_ms_total": cold_readback_ms, "subviewport_wait_ms_total": cold_wait_ms},
		"average_fps": 1000.0 / mean_frame_ms, "average_frame_ms": mean_frame_ms,
		"one_percent_low_fps": 1000.0 / p99_ms, "p99_frame_ms": p99_ms, "worst_frame_ms": max_frame_ms,
		"hits_per_sec": float(hits) / sample_seconds, "misses_per_sec": float(misses) / sample_seconds,
		"new_poses_per_sec": float(after.poses - before.poses) / sample_seconds,
		"recreated_pose_entries": renderer.vehicle_cache_recreated_poses_total - before_recreated,
		"evictions": renderer.vehicle_cache_evictions_total - before_evictions,
		"cold_warmup_evictions": cold_evictions,
		"unique_pose_keys_seen": created_pose_keys.size(), "unique_pose_keys_by_kind": pose_summary,
		"readbacks_per_sec": float(after.readbacks - before.readbacks) / sample_seconds,
		"readback_ms_per_sec": float(after.readback_ms - before.readback_ms) / sample_seconds,
		"subviewport_render_wait_ms_per_sec": float(after.render_wait_ms - before.render_wait_ms) / sample_seconds,
		"active_subviewport_peak": renderer.vehicle_cache_peak_subviewports, "cache_size_end": renderer.vehicle_texture_cache.size(), "cache_size_peak": cache_size_peak,
		"visible_vehicles_avg": float(visible_vehicle_sum) / SAMPLE_FRAMES, "moving_vehicles_avg": float(moving_vehicle_sum) / SAMPLE_FRAMES, "visible_wrecks_peak": visible_wreck_peak,
		"world_renderer_ms_avg": world_ms / SAMPLE_FRAMES, "world_renderer_parts_ms_avg": {"terrain": render_parts.terrain / SAMPLE_FRAMES, "ground_fx": render_parts.ground_fx / SAMPLE_FRAMES, "wrecks": render_parts.wrecks / SAMPLE_FRAMES, "buildings": render_parts.buildings / SAMPLE_FRAMES, "vehicles": render_parts.vehicles / SAMPLE_FRAMES, "tracks": render_parts.tracks / SAMPLE_FRAMES, "projectiles": render_parts.projectiles / SAMPLE_FRAMES, "impacts": render_parts.impacts / SAMPLE_FRAMES, "explosions": render_parts.explosions / SAMPLE_FRAMES, "smoke": render_parts.smoke / SAMPLE_FRAMES, "fog": render_parts.fog / SAMPLE_FRAMES}, "sim_tick_ms_avg": sim_ms / SAMPLE_FRAMES, "draw_calls_avg": draw_calls / SAMPLE_FRAMES,
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"sample_seconds": sample_seconds, "fully_warm_pose_replay": warm_replay
	}
	var path := "res://test-output/vehicle-cache-" + variant + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	var trace_file := FileAccess.open("res://test-output/vehicle-cache-" + variant + "-frames.csv", FileAccess.WRITE)
	trace_file.store_string("\n".join(trace_rows) + "\n")
	trace_file.close()
	var event_file := FileAccess.open("res://test-output/vehicle-cache-" + variant + "-events.csv", FileAccess.WRITE)
	event_file.store_line("time_usec,event,pose_key,duration_ms")
	for event in renderer.vehicle_cache_event_log:
		event_file.store_line("%s,%s,%s,%s" % [str(event.time_usec),str(event.event),str(event.key),"%.3f"%float(event.duration_ms)])
	event_file.close()
	await RenderingServer.frame_post_draw
	var review_image: Image = root.get_texture().get_image()
	if review_image != null: review_image.save_png("res://test-output/vehicle-cache-" + variant + ".png")
	print("CACHE A/B RESULT ", JSON.stringify(result))
	game.music.shutdown()
	game.queue_free()
	await process_frame
	quit(0)
