extends SceneTree

const VehiclePainter = preload("res://scripts/vehicle_cache_painter.gd")
const LEVELS: Array[int] = [0, 2, 4, 6, 8]
const FACTIONS: Array[String] = ["forge", "drift", "lumen"]
const TILE_SIZE := 160
const CROP := Rect2i(620, 240, 700, 640)
const MIN_STEP_PIXEL_DIFFERENCE := 0.0015
const MIN_EMPTY_FULL_PIXEL_DIFFERENCE := 0.01

func _initialize() -> void:
	print("Checking visible H09 Solarit cargo states: 0 / 25 / 50 / 75 / 100 percent")
	call_deferred("run")

func capture_level(level: int, faction: String) -> Image:
	var painter = VehiclePainter.new()
	painter.art = IndustrialArt.new()
	painter.entity = {
		"id": 1, "kind": "harvester", "owner": 0, "hp": 1000.0, "max_hp": 1000.0,
		"angle": -0.42, "turret": 0.0, "cargo": float(level) * 125.0,
		"harvest_state": "IDLE", "drive_frame": 0, "visual_animation_state": 0,
		"animation_frame_count": 8, "visual_cargo_state": level,
		"visual_damage_state": 0, "velocity": Vector2.ZERO
	}
	painter.team = Color("69d6c0")
	painter.faction = faction
	root.add_child(painter)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var texture: Texture2D = root.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty() or image.get_size().x < CROP.position.x + CROP.size.x or image.get_size().y < CROP.position.y + CROP.size.y:
		push_error("H09 cargo pose at %d/8 did not render a complete comparison crop" % level)
		quit(1)
		return Image.new()
	var crop := image.get_region(CROP)
	crop.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	crop.convert(Image.FORMAT_RGBA8)
	painter.queue_free()
	await process_frame
	return crop

func pixel_difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			total += (absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)) / 3.0
	return total / float(TILE_SIZE * TILE_SIZE)

func run() -> void:
	for faction in FACTIONS:
		var images: Array[Image] = []
		for level in LEVELS:
			var rendered := await capture_level(level, faction)
			if rendered.is_empty(): return
			images.append(rendered)
		var sheet := Image.create(TILE_SIZE * LEVELS.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
		for index in range(images.size()):
			sheet.blit_rect(images[index], Rect2i(Vector2i.ZERO, images[index].get_size()), Vector2i(index * TILE_SIZE, 0))
		var output_path := "res://test-output/harvester_cargo_levels_%s.png" % faction
		if sheet.save_png(output_path) != OK:
			push_error("cargo-level comparison sheet could not be saved for %s" % faction)
			quit(1)
			return
		var total_change := pixel_difference(images.front(), images.back())
		if total_change <= MIN_EMPTY_FULL_PIXEL_DIFFERENCE:
			push_error("empty and full %s harvester rendered too similarly: %.4f" % [faction, total_change])
			quit(1)
			return
		print("%s cargo empty-to-full rendered pixel difference %.4f" % [faction, total_change])
		for index in range(1, images.size()):
			var step_change := pixel_difference(images[index - 1], images[index])
			print("%s cargo %d%% -> %d%%: rendered pixel difference %.4f" % [faction, LEVELS[index - 1] * 100 / 8, LEVELS[index] * 100 / 8, step_change])
			if step_change <= MIN_STEP_PIXEL_DIFFERENCE:
				push_error("%s cargo stage %d/8 -> %d/8 did not visibly alter the pose: %.4f" % [faction, LEVELS[index - 1], LEVELS[index], step_change])
				quit(1)
				return
		print("%s H09 cargo level comparison saved: %s" % [faction, output_path])
	quit()
