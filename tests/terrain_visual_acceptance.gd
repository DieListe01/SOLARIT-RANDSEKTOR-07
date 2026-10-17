extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TERRAIN VISUAL FAIL: "+message)

func visual_mask_kind(mask: Image, point: Vector2) -> int:
	var x:=clampi(roundi(point.x*8.0-0.5),0,mask.get_width()-1)
	var y:=clampi(roundi(point.y*8.0-0.5),0,mask.get_height()-1)
	return int(floor(mask.get_pixel(x,y).r*8.0))

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
	# Capture controlled layer combinations at the exact same paused camera.
	# This isolates the rectangular patches reported in active gameplay without
	# changing terrain generation or the production render settings.
	var layer_cases := [
		{"name":"terrain_layers_all_on","disabled":[]},
		{"name":"terrain_layers_no_detail_sprite","disabled":["terrain_detail_sprite"]},
		{"name":"terrain_layers_no_detail_mesh","disabled":["terrain_detail_mesh"]},
		{"name":"terrain_layers_no_fog","disabled":["fog"]},
		{"name":"terrain_layers_base_only","disabled":["fog","terrain_detail"]}
	]
	for layer_case in layer_cases:
		game.renderer.benchmark_disabled_categories.clear()
		for category in ["tracks","wrecks","combat_vfx","buildings","vehicles","health_selection"]:
			game.renderer.benchmark_disabled_categories.append(category)
		for category in layer_case.disabled:
			game.renderer.benchmark_disabled_categories.append(category)
		game.renderer.queue_redraw()
		await process_frame
		await process_frame
		var layer_capture_path: String="res://test-output/%s.png" % str(layer_case.name)
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(layer_capture_path))==OK,"Layer isolation capture saved: "+str(layer_case.name))
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
	var resource_patches: Array=game.sim.db.mission.get("resources",[])
	var resource_edges_inside:=0
	var resource_edges_outside:=0
	for patch_index in resource_patches.size():
		var patch: Dictionary=resource_patches[patch_index]
		var patch_cell: Array=patch.get("cell",[])
		if patch_cell.size()<2: continue
		var patch_center:=Vector2(float(patch_cell[0])+0.5,float(patch_cell[1])+0.5)
		var patch_radius:=float(patch.get("radius",0))+0.5
		check(visual_mask_kind(mask,patch_center)==3,"Solarit deposit interior remains visible in the material mask")
		for sample_index in 32:
			var sample_point:=patch_center+Vector2.from_angle(TAU*float(sample_index)/32.0)*patch_radius
			if visual_mask_kind(mask,sample_point)==3: resource_edges_inside+=1
			else: resource_edges_outside+=1
	check(resource_edges_inside>0 and resource_edges_outside>0,"Solarit material boundary is irregular at sub-cell resolution instead of preserving a square-cell outline")
	var boundary_kinds: Dictionary={}
	for y_cell in range(38,57):
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
	game.renderer.camera=Vector2(640,1440)
	game.renderer.zoom=1.3
	game.renderer.queue_redraw()
	await create_timer(0.3).timeout
	var no_detail_path:="res://test-output/terrain_no_detail_default_shader.png"
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(no_detail_path))==OK,"Default shader without terrain detail is saved at the baseline camera")
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
	var baseline_camera:=Vector2(640,1440)
	game.renderer.camera=baseline_camera
	game.renderer.zoom=1.3
	game.renderer.terrain_sprite.material=diagnostic_material
	game.renderer.queue_redraw()
	await create_timer(0.3).timeout
	var class_capture_path:="res://test-output/terrain_mask_classes.png"
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(class_capture_path))==OK,"Material-class diagnostic capture is saved")
	var flat_shader:=Shader.new()
	flat_shader.code="""
	shader_type canvas_item;
	render_mode unshaded;
	vec3 terrain_color(float kind) {
		if(kind<0.5) return vec3(0.69,0.45,0.27);
		if(kind<1.5) return vec3(0.46,0.39,0.32);
		if(kind<2.5) return vec3(0.75,0.53,0.34);
		if(kind<3.5) return vec3(0.48,0.39,0.31);
		if(kind<4.5) return vec3(0.59,0.47,0.35);
		if(kind<5.5) return vec3(0.45,0.34,0.26);
		return vec3(0.35,0.29,0.23);
	}
	void fragment() {
		float kind=floor(texture(TEXTURE,UV).r*8.0);
		COLOR=vec4(terrain_color(kind),1.0);
	}
	"""
	var flat_material:=ShaderMaterial.new()
	flat_material.shader=flat_shader
	game.renderer.terrain_sprite.material=flat_material
	game.renderer.queue_redraw()
	await create_timer(0.3).timeout
	var flat_capture_path:="res://test-output/terrain_flat_material.png"
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(flat_capture_path))==OK,"Flat material diagnostic capture is saved")
	var production_shader: Shader=normal_material.shader
	var production_shader_code:=production_shader.code
	var no_warp_code:=production_shader_code
	no_warp_code=no_warp_code.replace("vec2 warp=(vec2(noise(world*0.0032),noise(world*0.0032+91.0))-0.5)*5.2;","vec2 warp=vec2(0.0);")
	no_warp_code=no_warp_code.replace("\twarp+=(vec2(noise(world*0.012+27.0),noise(world*0.012+118.0))-0.5)*2.2;","")
	no_warp_code=no_warp_code.replace("\twarp+=(vec2(noise(world*0.045+211.0),noise(world*0.045+302.0))-0.5)*0.7;","")
	for diagnostic in [
		{"id":"no_variation","code":production_shader_code.replace("COLOR=vec4(base+variation,1.0);","COLOR=vec4(base,1.0);")},
		{"id":"no_edge_blend","code":production_shader_code.replace("base=mix(base,adjacent,transition);","// Material transition disabled for artifact isolation.")},
		{"id":"no_warp","code":no_warp_code}
	]:
		var isolation_shader:=Shader.new()
		isolation_shader.code=str(diagnostic.code)
		check(isolation_shader.code!=production_shader_code,"Shader isolation variant changes the intended production shader code: "+str(diagnostic.id))
		var isolation_material:=ShaderMaterial.new()
		isolation_material.shader=isolation_shader
		# Diagnostic materials do not inherit shader parameters from the original
		# terrain ShaderMaterial. Keep the world-to-mask mapping identical or a
		# default 64x64 map scale introduces false square/block artifacts.
		isolation_material.set_shader_parameter("map_cells",Vector2(game.sim.grid.width,game.sim.grid.height))
		game.renderer.terrain_sprite.material=isolation_material
		game.renderer.queue_redraw()
		await create_timer(0.3).timeout
		var isolation_path:="res://test-output/terrain_shader_%s.png" % str(diagnostic.id)
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(isolation_path))==OK,"Terrain shader isolation capture is saved: "+str(diagnostic.id))
	# Compare the production shader with a flat class mask at the exact game zoom.
	var isolated_viewport:=SubViewport.new()
	isolated_viewport.size=game.viewport.size
	isolated_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	isolated_viewport.transparent_bg=false
	root.add_child(isolated_viewport)
	var isolated_sprite:=Sprite2D.new()
	isolated_sprite.centered=false
	isolated_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	isolated_sprite.texture=game.renderer.terrain_sprite.texture
	var isolated_scale:float=game.renderer.zoom*float(isolated_viewport.size.x)/game.renderer.logical_size.x*game.sim.grid.tile/8.0
	isolated_sprite.position=Vector2(isolated_viewport.size)*0.5-game.renderer.camera*(game.renderer.zoom*float(isolated_viewport.size.x)/game.renderer.logical_size.x)+game.renderer.visual_offset
	isolated_sprite.scale=Vector2.ONE*isolated_scale
	var isolated_material:ShaderMaterial=(normal_material as ShaderMaterial).duplicate() as ShaderMaterial
	isolated_material.set_shader_parameter("map_cells",Vector2(game.sim.grid.width,game.sim.grid.height))
	isolated_sprite.material=isolated_material
	isolated_viewport.add_child(isolated_sprite)
	await process_frame
	await process_frame
	var shader_only_image:=isolated_viewport.get_texture().get_image()
	check(shader_only_image.save_png(ProjectSettings.globalize_path("res://test-output/terrain_shader_only.png"))==OK,"Isolated production-shader capture is saved")
	check(production_shader_code.contains("vec2 noise_gradient"),"Terrain shader uses gradient noise to avoid visible square value-noise cells")
	isolated_sprite.material=flat_material
	isolated_sprite.queue_redraw()
	await create_timer(0.5).timeout
	var flat_only_image:=isolated_viewport.get_texture().get_image()
	check(flat_only_image.save_png(ProjectSettings.globalize_path("res://test-output/terrain_flat_shader_only.png"))==OK,"Isolated flat-shader comparison is saved")
	check(shader_only_image.get_data()!=flat_only_image.get_data(),"Isolated shader comparison renders distinct materials rather than a stale viewport frame")
	isolated_viewport.queue_free()
	game.renderer.terrain_sprite.material=normal_material
	game.music.shutdown()
	game.queue_free()
	await process_frame
	print("TERRAIN VISUAL: %d failures; mask_build_ms=%.2f; captures=%s, %s, %s, %s" % [failures, mask_build_ms, mask_path, capture_path, detail_capture_path, material_only_path])
	quit(1 if failures > 0 else 0)
