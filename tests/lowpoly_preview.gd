extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("171614")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("cbb99e")
	environment.ambient_light_energy=0.75
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment_node.environment=environment
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color("ffe0b5")
	sun.light_energy=1.35
	sun.shadow_enabled=true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=23
	camera.position=Vector3(0,25,34)
	world.add_child(camera)
	camera.look_at(Vector3(0,0,0),Vector3.UP)
	camera.current=true
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size=Vector2(45,24)
	floor.mesh=floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color=Color("a9662f")
	floor_material.roughness=0.96
	floor.material_override=floor_material
	floor.position.y=-0.04
	world.add_child(floor)
	var vehicles := ["harvester","scout","tank","siege","raider","lancer","scorcher","bulwark"]
	for i in vehicles.size():
		var node := Node3D.new()
		node.position=Vector3(-12.25+i*3.5,0,3.6)
		world.add_child(node)
		LowpolyModelFactory.vehicle(node,{"kind":vehicles[i],"hp":100,"max_hp":100},Color("69d6c0"),"forge",0.35)
	var buildings := ["core","power","refinery","factory","tower","radar","repair","armory"]
	for i in buildings.size():
		var node := Node3D.new()
		node.position=Vector3(-12.25+i*3.5,0,-4.2)
		world.add_child(node)
		LowpolyModelFactory.building(node,{"kind":buildings[i],"rotation":0},Color("69d6c0"),"forge",Vector2(64,64))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image!=null and not image.is_empty(),"preview viewport should render")
	image.save_png("res://test-output/lowpoly_preview.png")
	print("Saved low-poly vehicle and building preview")
	quit()
