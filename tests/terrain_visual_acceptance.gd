extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TERRAIN VISUAL FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro()
	game.set_classic(false)
	game.start_game()
	game.paused = true
	for _frame in 3: await process_frame
	for owner in game.sim.explored.size():
		game.sim.explored[owner].fill(1)
		game.sim.fog[owner].fill(1)
		game.sim.known[owner].clear()
	game.renderer._update_fog_texture()
	game.renderer.benchmark_disabled_categories.clear()
	for category in ["fog","terrain_detail","tracks","wrecks","combat_vfx","buildings","vehicles","health_selection"]:
		game.renderer.benchmark_disabled_categories.append(category)
	game.renderer.heat_layer.visible=false
	game.renderer.camera = Vector2(640,1440)
	game.renderer.zoom = 1.3
	var terrain_before: PackedInt32Array = game.sim.grid.terrain.duplicate()
	var mask_started:=Time.get_ticks_usec()
	var mask: Image=game.renderer._build_visual_terrain_mask(game.sim.grid)
	var mask_build_ms:=float(Time.get_ticks_usec()-mask_started)/1000.0
	var mission_data_before: Dictionary=game.sim.db.mission
	for mission_file in ["veyra.json", "dry_vein.json", "khepri_pass.json"]:
		var catalog:=Catalog.new("res://data/"+mission_file)
		var mission_grid:=WorldGrid.new(catalog.mission)
		var gameplay_before: PackedInt32Array=mission_grid.terrain.duplicate()
		game.sim.db.mission=catalog.mission
		var generated: Image=game.renderer._build_visual_terrain_mask(mission_grid)
		var baked:=Image.new()
		var baked_path: String="res://assets/terrain_masks/%s.png" % str(catalog.mission.id)
		var load_error:=baked.load(baked_path)
		if load_error==OK: baked.convert(Image.FORMAT_R8)
		check(load_error==OK and baked.get_data()==generated.get_data(),"Prebaked terrain mask matches generator for "+str(catalog.mission.id))
		check(mission_grid.terrain==gameplay_before,"Visual mask leaves gameplay grid unchanged for "+str(catalog.mission.id))
	game.sim.db.mission=mission_data_before
	await create_timer(0.8).timeout
	game.renderer.queue_redraw()
	await process_frame
	var shader: Shader = game.renderer.terrain_sprite.material.shader
	check(shader != null,"Full-detail terrain shader is active on the graphical renderer")
	check(game.sim.grid.terrain == terrain_before,"Visual border distortion does not change gameplay terrain cells")
	var mask_image: Image = game.renderer.terrain_sprite.texture.get_image()
	var expected_runtime_mask:=mask.duplicate()
	mask_image.convert(Image.FORMAT_R8)
	expected_runtime_mask.convert(Image.FORMAT_R8)
	check(mask_image.get_data()==expected_runtime_mask.get_data(),"Runtime mission texture matches its prebaked visual mask")
	var rock_center:=mask_image.get_pixel(13*8+4,47*8+4).r*8.0
	var sand_center:=mask_image.get_pixel(27*8+4,47*8+4).r*8.0
	check(int(floor(rock_center))==1 and int(floor(sand_center))==0,"Supersampled visual mask preserves distinct interior materials")
	check(mask.get_width()==game.sim.grid.width*8 and mask.get_height()==game.sim.grid.height*8,"Visual mask has eight samples per gameplay cell")
	check(game.renderer.terrain_sprite.texture.get_width()==game.sim.grid.width*8,"Loaded mask keeps map geometry at the gameplay map size")
	check(int(floor(mask.get_pixel(30*8+4,47*8+4).r*8.0))==6,"Exact cliff cells survive visual mask shaping")
	var boundary_kinds: Dictionary={}
	for y_cell in range(38,57,2):
		var sample:=mask_image.get_pixel(22*8+4,y_cell*8+4).r*8.0
		boundary_kinds[int(floor(sample))]=true
	check(boundary_kinds.has(0) and boundary_kinds.has(1),"Soft material edge visibly deviates from its authored straight rectangle")
	var cliff_edge_classes: Dictionary={}
	for y_cell in range(33,63):
		var sample:=mask_image.get_pixel(29*8+4,y_cell*8+4).r*8.0
		cliff_edge_classes[int(floor(sample))]=true
	check(cliff_edge_classes.has(0) and cliff_edge_classes.has(6),"Cliff edge receives presentation-only erosion while retaining its interior")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
	var capture_path := "res://test-output/terrain_irregular_boundaries.png"
	var error := root.get_texture().get_image().save_png(capture_path)
	check(error == OK,"Vulkan terrain acceptance capture is saved")
	var mask_path := "res://test-output/terrain_visual_mask.png"
	check(mask.save_png(ProjectSettings.globalize_path(mask_path))==OK,"Generated visual mask is saved for inspection")
	game.renderer.camera=Vector2(704,1504)
	game.renderer.zoom=2.0
	game.renderer.queue_redraw()
	await create_timer(0.3).timeout
	var detail_capture_path := "res://test-output/terrain_irregular_boundaries_detail.png"
	check(root.get_texture().get_image().save_png(detail_capture_path)==OK,"Close terrain material-edge capture is saved")
	game.renderer.benchmark_disabled_categories.append("terrain_detail")
	game.renderer.queue_redraw()
	await create_timer(0.3).timeout
	var material_only_path := "res://test-output/terrain_material_only.png"
	check(root.get_texture().get_image().save_png(material_only_path)==OK,"Material-only comparison capture is saved")
	# Preserve a presentation-neutral image of the baked material classes. This
	# separates mask defects from shading/noise artifacts during visual review.
	var diagnostic_shader:=Shader.new()
	diagnostic_shader.code="""
	shader_type canvas_item;
	render_mode unshaded;
	void fragment() {
		float kind=floor(texture(TEXTURE,UV).r*8.0);
		COLOR=vec4(kind/8.0,0.0,0.0,1.0);
	}
	"""
	var diagnostic_material:=ShaderMaterial.new()
	diagnostic_material.shader=diagnostic_shader
	var normal_material:Material=game.renderer.terrain_sprite.material
	game.renderer.terrain_sprite.material=diagnostic_material
	game.renderer.queue_redraw()
	await create_timer(0.3).timeout
	var class_capture_path:="res://test-output/terrain_mask_classes.png"
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(class_capture_path))==OK,"Material-class diagnostic capture is saved")
	game.renderer.terrain_sprite.material=normal_material
	game.music.shutdown()
	game.queue_free()
	await process_frame
	print("TERRAIN VISUAL: %d failures; mask_build_ms=%.2f; captures=%s, %s, %s, %s" % [failures, mask_build_ms, mask_path, capture_path, detail_capture_path, material_only_path])
	quit(1 if failures > 0 else 0)
