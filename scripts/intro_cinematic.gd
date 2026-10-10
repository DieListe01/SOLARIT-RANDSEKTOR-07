extends Control
class_name IntroCinematic

signal completed

const DURATION := 15.0
const TITLE_COLOR := Color("e7b86e")
const MINT_COLOR := Color("82ddc4")
const MODEL_ROOT := "res://assets/models/"

var elapsed := 0.0:
	set(value):
		elapsed = clampf(value, 0.0, DURATION)
		if is_instance_valid(title_label):
			_update_cinematic()
var finished := false
var world_root: Node3D
var camera: Camera3D
var harvester: Node3D
var colony_models: Array[Node3D] = []
var title_label: Label
var location_label: Label
var caption_label: Label
var second_title: Label
var progress: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_scene()
	_build_titles()
	_update_cinematic()

func _process(dt: float) -> void:
	if finished:
		return
	elapsed = minf(DURATION, elapsed + dt)
	_update_cinematic()
	if elapsed >= DURATION:
		finished = true
		completed.emit()

func _build_scene() -> void:
	var container := SubViewportContainer.new()
	container.name = "3D Intro View"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.name = "Cinematic 3D"
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var world := World3D.new()
	viewport.world_3d = world
	world_root = Node3D.new()
	world_root.name = "Veyra basin"
	viewport.add_child(world_root)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("111b27")
	sky_material.sky_horizon_color = Color("c28b59")
	sky_material.ground_bottom_color = Color("211a20")
	sky_material.ground_horizon_color = Color("644934")
	sky_material.sky_curve = 0.34
	sky_material.ground_curve = 0.30
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5baa0")
	environment.ambient_light_energy = 0.60
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_bloom = 0.08
	world_environment.environment = environment
	world_root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	sun.light_color = Color("ffd29a")
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 55.0
	world_root.add_child(sun)

	camera = Camera3D.new()
	camera.name = "Slow cinematic camera"
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43.0
	camera.position = Vector3(17.0, 12.5, 28.0)
	camera.current = true
	world_root.add_child(camera)
	camera.look_at(Vector3(-0.4, 2.6, 0.0), Vector3.UP)

	_add_ground()
	_add_sky_objects()
	_add_rocks()
	_add_crystal_fields()
	_add_colony()
	_add_harvester()

func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Veyra ochre regolith"
	var basin := PlaneMesh.new()
	basin.size = Vector2(96.0, 96.0)
	basin.subdivide_width = 64
	basin.subdivide_depth = 64
	ground.mesh = basin
	ground.position.y = -0.08
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode diffuse_burley, specular_schlick_ggx;
	varying vec2 ground_position;
	float dune_height(vec2 p) {
		return sin(p.y * 0.15 + sin(p.x * 0.07) * 0.7) * 0.48 + sin(p.x * 0.11 + p.y * 0.04) * 0.23;
	}
	void vertex() {
		vec2 p = VERTEX.xz;
		float step_size = 0.12;
		float dx = (dune_height(p + vec2(step_size, 0.0)) - dune_height(p - vec2(step_size, 0.0))) / (step_size * 2.0);
		float dz = (dune_height(p + vec2(0.0, step_size)) - dune_height(p - vec2(0.0, step_size))) / (step_size * 2.0);
		VERTEX.y += dune_height(p);
		NORMAL = normalize(vec3(-dx, 1.0, -dz));
		ground_position = p;
	}
	float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
	float noise(vec2 p) {
		vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
		return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
	}
	void fragment() {
	float broad = sin(ground_position.x * 0.11 + sin(ground_position.y * 0.08) * 1.4) * 0.5 + 0.5;
	float medium = sin(ground_position.x * 0.39 + sin(ground_position.y * 0.31) * 1.7 + ground_position.y * 0.23) * 0.5 + 0.5;
	float grain = noise(ground_position * 4.0 + vec2(sin(ground_position.y * 0.2), sin(ground_position.x * 0.2)));
	float ripple = sin(ground_position.y * 3.1 + sin(ground_position.x * 0.37) * 1.3) * 0.012;
	vec3 sand = mix(vec3(0.23, 0.12, 0.065), vec3(0.48, 0.255, 0.12), broad);
	sand += (medium - 0.5) * 0.065 + (grain - 0.5) * 0.028 + ripple;
		ALBEDO = sand; ROUGHNESS = 0.94;
	}
	"""
	material.shader = shader
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(ground)


func _make_basin_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const STEPS := 52
	for z_index in range(STEPS + 1):
		var z := -48.0 + 96.0 * float(z_index) / float(STEPS)
		for x_index in range(STEPS + 1):
			var x := -48.0 + 96.0 * float(x_index) / float(STEPS)
			var distant := 1.0 - smoothstep(-42.0, -10.0, z)
			var dune := sin(z * 0.15 + sin(x * 0.07) * 0.7) * 0.48 + sin(x * 0.11 + z * 0.04) * 0.23
			vertices.append(Vector3(x, dune * (0.35 + distant * 2.4), z))
	for z_index in STEPS:
		for x_index in STEPS:
			var top_left := z_index * (STEPS + 1) + x_index
			indices.append_array(PackedInt32Array([top_left, top_left + STEPS + 1, top_left + 1, top_left + 1, top_left + STEPS + 1, top_left + STEPS + 2]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()

func _add_sky_objects() -> void:
	var planet := MeshInstance3D.new()
	planet.name = "Ash-moon"
	var sphere := SphereMesh.new()
	sphere.radius = 3.1
	sphere.height = 6.2
	sphere.radial_segments = 32
	sphere.rings = 16
	planet.mesh = sphere
	planet.position = Vector3(-15.0, 8.0, -42.0)
	var planet_material := StandardMaterial3D.new()
	planet_material.albedo_color = Color("bd9a67")
	planet_material.emission_enabled = true
	planet_material.emission = Color("6a4934")
	planet_material.emission_energy_multiplier = 0.18
	planet_material.roughness = 1.0
	planet.material_override = planet_material
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(planet)

	# One multimesh keeps the star field cheap while adding actual depth to the sky.
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.035
	star_mesh.height = 0.07
	star_mesh.radial_segments = 5
	star_mesh.rings = 3
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.mesh = star_mesh
	stars.instance_count = 140
	var rng := RandomNumberGenerator.new()
	rng.seed = 218607
	for index in stars.instance_count:
		var position := Vector3(rng.randf_range(-36.0, 36.0), rng.randf_range(-16.0, 17.0), rng.randf_range(-49.0, -44.0))
		stars.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.45, 1.8)), position))
	var star_field := MultiMeshInstance3D.new()
	star_field.name = "Distant stars"
	star_field.multimesh = stars
	var star_material := StandardMaterial3D.new()
	star_material.albedo_color = Color("c9d8c8")
	star_material.emission_enabled = true
	star_material.emission = Color("90b8ae")
	star_material.emission_energy_multiplier = 0.5
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mesh.material = star_material
	camera.add_child(star_field)

func _add_rocks() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.4
	mesh.radial_segments = 6
	mesh.rings = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 125
	var rng := RandomNumberGenerator.new()
	rng.seed = 709
	for index in multi.instance_count:
		var x := rng.randf_range(-31.0, 31.0)
		var z := rng.randf_range(-25.0, 24.0)
		var size := rng.randf_range(0.08, 0.48)
		var ground_y := _ground_surface_y(Vector2(x, z))
		var transform := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))).scaled(Vector3(size * rng.randf_range(0.6, 1.5), size, size * rng.randf_range(0.7, 1.6))), Vector3(x, ground_y + size * 0.35, z))
		multi.set_instance_transform(index, transform)
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "Scattered basalt and slag"
	rocks.multimesh = multi
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("514335")
	material.roughness = 1.0
	mesh.material = material
	world_root.add_child(rocks)

func _add_crystal_fields() -> void:
	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(0.25, 0.72, 0.30)
	crystal_mesh.left_to_right = 0.32
	crystal_mesh.subdivide_width = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("28bcb1")
	material.metallic = 0.22
	material.roughness = 0.23
	material.emission_enabled = true
	material.emission = Color("0b766e")
	material.emission_energy_multiplier = 0.42
	crystal_mesh.material = material
	var crystals := MultiMesh.new()
	crystals.transform_format = MultiMesh.TRANSFORM_3D
	crystals.mesh = crystal_mesh
	crystals.instance_count = 68
	var rng := RandomNumberGenerator.new()
	rng.seed = 1707
	for index in crystals.instance_count:
		var cluster := floori(float(index) / 17.0)
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(0.1, 2.3)
		var height := rng.randf_range(0.28, 0.86)
		var cluster_x: float = [-12.0, -7.0, 8.0, 13.0][cluster]
		var cluster_z: float = [3.0, 9.0, -1.0, 6.0][cluster]
		var px := cluster_x + cos(angle) * radius
		var pz := cluster_z + sin(angle) * radius
		var pos := Vector3(px, _ground_surface_y(Vector2(px, pz)) + height * 0.5, pz)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.13, 0.13), rng.randf_range(0.0, TAU), rng.randf_range(-0.13, 0.13))).scaled(Vector3(1.0, height, 1.0))
		crystals.set_instance_transform(index, Transform3D(basis, pos))
	var field := MultiMeshInstance3D.new()
	field.name = "Glassy Solarit seams"
	field.multimesh = crystals
	world_root.add_child(field)

func _add_colony() -> void:
	var placements := [
		["core", Vector3(-1.1, 0.0, -0.9), 4.2],
		["power", Vector3(5.1, 0.0, -1.5), 4.5],
		["refinery", Vector3(-6.3, 0.0, 0.6), 5.2],
		["factory", Vector3(4.8, 0.0, 4.3), 4.2],
	]
	for item in placements:
		var kind: String = item[0]
		var packed := load(MODEL_ROOT + "buildings/%s.glb" % kind) as PackedScene
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		model.name = "Cinematic " + kind
		world_root.add_child(model)
		await get_tree().process_frame
		_fit_model_to_width(model, float(item[2]))
		model.position = Vector3(item[1].x, _ground_surface_y(Vector2(item[1].x, item[1].z)), item[1].z)
		model.rotation.y = float(colony_models.size() % 4) * 0.16
		colony_models.append(model)

func _add_harvester() -> void:
	var packed := load(MODEL_ROOT + "vehicles/harvester.glb") as PackedScene
	if packed == null:
		return
	harvester = packed.instantiate() as Node3D
	harvester.name = "Cinematic Solarit harvester"
	world_root.add_child(harvester)
	await get_tree().process_frame
	_fit_model_to_width(harvester, 3.6)
	harvester.position = Vector3(12.0, _ground_surface_y(Vector2(12.0, 9.0)), 9.0)
	harvester.rotation.y = 0.0
	var player := harvester.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(&"Move"):
		player.play(&"Move")
		player.speed_scale = 0.72

func _fit_model_to_width(model: Node3D, target: float) -> void:
	var bounds := AABB()
	var found := false
	var nodes: Array[Node] = [model]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is VisualInstance3D:
			var visual := node as VisualInstance3D
			var current: AABB = visual.get_aabb() * visual.global_transform
			if not found:
				bounds = current
				found = true
			else:
				bounds = bounds.merge(current)
		nodes.append_array(node.get_children())
	if not found or bounds.size.length() <= 0.001:
		return
	var scale_value := target / maxf(bounds.size.x, bounds.size.z)
	model.scale = Vector3.ONE * scale_value
	model.position.y = -bounds.position.y * scale_value

func _ground_surface_y(position: Vector2) -> float:
	return sin(position.y * 0.15 + sin(position.x * 0.07) * 0.7) * 0.48 + sin(position.x * 0.11 + position.y * 0.04) * 0.23 - 0.08

func _build_titles() -> void:
	var canvas := Control.new()
	canvas.name = "Cinematic text and title"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var shade := ColorRect.new()
	shade.name = "Left title readability"
	shade.position = Vector2.ZERO
	shade.size = Vector2(850, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	var shade_shader := Shader.new()
	shade_shader.code = "shader_type canvas_item; void fragment(){ float a=0.76*(1.0-smoothstep(0.0,1.0,UV.x)); COLOR=vec4(0.025,0.055,0.073,a); }"
	shade.material = shade_material
	shade.material.shader = shade_shader
	canvas.add_child(shade)
	shade.z_index = 0
	title_label = _add_label(canvas, "SOLARIT: RANDSEKTOR 07", Rect2(86, 185, 1160, 98), 70, TITLE_COLOR)
	location_label = _add_label(canvas, "DAS VEYRA-BECKEN   /   RANDSEKTOR 07 · 2186", Rect2(92, 292, 1000, 45), 22, MINT_COLOR)
	caption_label = _add_label(canvas, "Unter der Asche schläft die Energie einer verlorenen Sonne.", Rect2(92, 902, 1400, 48), 25, Color("e0dfcc"))
	second_title = _add_label(canvas, "Drei Bündnisse. Ein Becken. Deine erste Kolonie.", Rect2(92, 950, 1400, 48), 23, Color("e0dfcc"))
	progress = ColorRect.new()
	progress.name = "Cinematic progress"
	progress.position = Vector2(720, 1038)
	progress.size = Vector2(1, 2)
	progress.color = Color(TITLE_COLOR, 0.58)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(progress)

func _add_label(parent: Control, text: String, rect: Rect2, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0.015, 0.025, 0.03, 0.86))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.modulate.a = 0.0
	parent.add_child(label)
	return label

func _update_cinematic() -> void:
	var title_alpha := maxf(_window_alpha(0.25, 4.0, 0.8), _window_alpha(10.0, DURATION, 0.8))
	var location_alpha := maxf(_window_alpha(3.0, 7.8, 0.7), _window_alpha(10.0, DURATION, 0.8))
	var first_caption := _window_alpha(4.2, 9.5, 0.65)
	var final_caption := _window_alpha(9.0, 15.0, 0.8)
	title_label.modulate.a = title_alpha
	location_label.modulate.a = location_alpha
	caption_label.modulate.a = first_caption
	second_title.modulate.a = final_caption
	progress.size.x = 480.0 * clampf(elapsed / DURATION, 0.0, 1.0)
	if is_instance_valid(camera):
		var reveal := smoothstep(3.0, 13.0, elapsed)
		var target := Vector3(17.0, 12.5, 28.0).lerp(Vector3(14.0, 11.0, 31.0), reveal)
		camera.position = camera.position.lerp(target, 1.0 - exp(-get_process_delta_time() * 0.15))
		camera.look_at(Vector3(-0.2, 2.3, 0.2), Vector3.UP)
	if is_instance_valid(harvester):
		var drive := smoothstep(5.0, 13.0, elapsed)
		var harvester_xz := Vector2(12.0, 9.0).lerp(Vector2(9.0, 6.5), drive)
		harvester.position = Vector3(harvester_xz.x, _ground_surface_y(harvester_xz), harvester_xz.y)
		harvester.rotation.y = lerpf(0.0, -0.34, drive)

func _window_alpha(start: float, end: float, fade: float) -> float:
	return clampf((elapsed - start) / fade, 0.0, 1.0) * clampf((end - elapsed) / fade, 0.0, 1.0)
