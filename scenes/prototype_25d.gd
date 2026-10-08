extends Node3D

const SAND := Color("a9662f")
const SAND_LIGHT := Color("c28245")
const METAL := Color("444b49")
const METAL_DARK := Color("252d2c")
const TURQUOISE := Color("24d4c4")
const CREAM := Color("d8c39a")
const AMBER := Color("e59a48")

func _ready() -> void:
	build_environment()
	build_ground()
	build_resources()
	build_vehicle()
	build_camera()

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171614")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cbb99e")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("ffe0b5")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

func build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Sand"
	var plane := PlaneMesh.new()
	plane.size = Vector2(64.0, 64.0)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	ground.mesh = plane
	ground.position.y = -0.16
	ground.material_override = make_material(SAND, 0.96)
	add_child(ground)

	var grid_material := make_material(Color("7e502e"), 1.0)
	for i in range(-8, 9):
		add_box("Ground seam X", Vector3(64.0, 0.008, 0.012), Vector3(0.0, -0.145, float(i) * 4.0), grid_material)
		add_box("Ground seam Z", Vector3(0.012, 0.008, 64.0), Vector3(float(i) * 4.0, -0.145, 0.0), grid_material)

	var rock_material := make_material(Color("625443"), 1.0)
	for rock in [Vector3(5.5, 0.15, -1.0), Vector3(6.1, 0.22, -0.3), Vector3(5.8, 0.18, 0.5), Vector3(6.4, 0.12, 1.0)]:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.8, 0.45, 0.7)
		mesh.mesh = shape
		mesh.position = rock
		mesh.rotation.y = randf_range(-0.5, 0.5)
		mesh.material_override = rock_material
		add_child(mesh)

func build_resources() -> void:
	var crystal_material := make_material(TURQUOISE, 0.42)
	crystal_material.emission_enabled = true
	crystal_material.emission = Color("087d77")
	for i in range(13):
		var crystal := MeshInstance3D.new()
		var shape := PrismMesh.new()
		shape.size = Vector3(randf_range(0.28, 0.55), randf_range(0.65, 1.25), randf_range(0.28, 0.55))
		crystal.mesh = shape
		var row := i / 4
		var col := i % 4
		crystal.position = Vector3(-4.6 + float(col) * 0.7 + randf_range(-0.1, 0.1), shape.size.y * 0.48, -2.0 + float(row) * 0.75)
		crystal.rotation.y = randf_range(-0.35, 0.35)
		crystal.material_override = crystal_material
		add_child(crystal)

func build_vehicle() -> void:
	var tread_material := make_material(METAL_DARK, 0.88, 0.28)
	var hull_material := make_material(METAL, 0.72, 0.3)
	var armor_material := make_material(CREAM, 0.64, 0.2)
	var turquoise_material := make_material(TURQUOISE, 0.4, 0.3)
	var dark_material := make_material(Color("172321"), 0.42, 0.25)
	var amber_material := make_material(AMBER, 0.56, 0.15)

	# Tracks and individual road wheels give the vehicle a readable silhouette at the isometric camera angle.
	for side in [-1.0, 1.0]:
		add_box("Track", Vector3(0.58, 0.72, 3.75), Vector3(side * 1.28, 0.38, 0.0), tread_material)
		for wheel_index in range(5):
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.28
			cylinder.bottom_radius = 0.28
			cylinder.height = 0.16
			cylinder.radial_segments = 12
			wheel.mesh = cylinder
			wheel.position = Vector3(side * 1.59, 0.38, -1.35 + float(wheel_index) * 0.68)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = armor_material
			add_child(wheel)

	add_box("Lower hull", Vector3(2.05, 0.56, 3.05), Vector3(0.0, 0.56, 0.0), hull_material)
	add_box("Front armor", Vector3(1.92, 0.26, 0.72), Vector3(0.0, 0.78, -1.42), armor_material)
	add_box("Rear deck", Vector3(1.62, 0.2, 0.76), Vector3(0.0, 0.88, 0.93), armor_material)
	add_box("Turret base", Vector3(1.54, 0.28, 1.7), Vector3(0.0, 1.0, -0.08), dark_material)
	add_box("Turret", Vector3(1.35, 0.55, 1.32), Vector3(0.0, 1.34, -0.06), hull_material)
	add_box("Turret armor", Vector3(1.22, 0.16, 0.9), Vector3(0.0, 1.7, -0.12), armor_material)
	add_box("Turquoise hull stripe", Vector3(0.18, 0.08, 2.38), Vector3(0.0, 0.87, 0.04), turquoise_material)
	add_box("Turret stripe", Vector3(0.86, 0.06, 0.12), Vector3(0.0, 1.8, -0.1), turquoise_material)
	add_box("Cannon", Vector3(0.22, 0.22, 1.55), Vector3(0.0, 1.42, -1.42), hull_material)
	add_box("Muzzle", Vector3(0.34, 0.29, 0.28), Vector3(0.0, 1.42, -2.2), amber_material)
	add_box("Vision slit", Vector3(0.56, 0.08, 0.07), Vector3(0.0, 1.57, -0.74), turquoise_material)
	for side in [-1.0, 1.0]:
		add_box("Side armor", Vector3(0.12, 0.25, 1.1), Vector3(side * 1.08, 0.78, 0.12), armor_material)
		add_box("Side light", Vector3(0.08, 0.1, 0.22), Vector3(side * 1.09, 0.96, -1.05), turquoise_material)

func build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "Isometric camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.5
	camera.position = Vector3(10.0, 12.0, 12.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

func make_material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func add_box(label: String, dimensions: Vector3, location: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var box := BoxMesh.new()
	box.size = dimensions
	instance.mesh = box
	instance.position = location
	instance.material_override = material
	add_child(instance)
