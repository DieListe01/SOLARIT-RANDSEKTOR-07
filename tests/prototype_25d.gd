extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed: PackedScene = load("res://scenes/prototype_25d.tscn")
	assert(packed != null, "2.5D prototype scene should load")
	var prototype: Node3D = packed.instantiate()
	root.add_child(prototype)
	await process_frame
	assert(prototype.get_node_or_null("Isometric camera") != null, "prototype camera should be present")
	assert(prototype.get_node_or_null("Sand") != null, "prototype terrain should be present")
	assert(prototype.get_child_count() >= 35, "prototype geometry should be generated")
	var samples := Node3D.new()
	prototype.add_child(samples)
	for kind in ["harvester","scout","tank","siege","raider","lancer","scorcher","bulwark"]:
		var vehicle := Node3D.new()
		samples.add_child(vehicle)
		LowpolyModelFactory.vehicle(vehicle,{"kind":kind,"hp":100,"max_hp":100},Color("69d6c0"),"forge",0.4)
		assert(vehicle.get_child_count() >= 1 and vehicle.get_child(0).get_child_count() >= 6, "%s should have low-poly model geometry" % kind)
	var building_features := {"core":"Command beacon","power":"Generator housing","refinery":"Fractionation tank","factory":"Vehicle bay","tower":"Rotating gun mount","radar":"Radar dish","repair":"Gantry lamp","armory":"Stored armor plate"}
	for kind in ["core","power","refinery","factory","tower","radar","repair","armory"]:
		var building := Node3D.new()
		samples.add_child(building)
		LowpolyModelFactory.building(building,{"kind":kind,"rotation":0},Color("69d6c0"),"forge",Vector2(64,64))
		assert(building.get_child_count() >= 6, "%s should have low-poly model geometry" % kind)
		assert(building.get_node_or_null(building_features[kind])!=null,"%s should expose its own readable silhouette feature" % kind)
		var foundation: MeshInstance3D=building.get_node("Reinforced foundation")
		var foundation_mesh := foundation.mesh as BoxMesh
		assert(foundation_mesh.size.x<=2.0 and foundation_mesh.size.z<=2.0,"%s should fit inside the map footprint" % kind)
	print("2.5D models: prototype plus all 8 vehicle and 8 distinctive, footprint-sized building archetypes loaded")
	quit()
