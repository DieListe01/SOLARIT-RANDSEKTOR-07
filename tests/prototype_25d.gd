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
	var vehicle_features := {"harvester":"Collector arm","scout":"Scout front bumper","tank":"Wheel hub","siege":"Muzzle ring","raider":"Raider side blade","lancer":"Lance emitter","scorcher":"Flame nozzle","bulwark":"Bulwark prow"}
	for kind in ["harvester","scout","tank","siege","raider","lancer","scorcher","bulwark"]:
		var vehicle := Node3D.new()
		samples.add_child(vehicle)
		LowpolyModelFactory.vehicle(vehicle,{"kind":kind,"hp":100,"max_hp":100,"angle":0.0,"turret":0.4},Color("69d6c0"),"forge",0.4)
		var model:Node3D=vehicle.get_child(0)
		assert(model.get_child_count() >= 6, "%s should have detailed low-poly model geometry" % kind)
		assert(model.find_child(vehicle_features[kind],true,false)!=null,"%s should have its own readable 3D detail" % kind)
		if kind=="scout":
			var scout_cylinders:=0
			for child in model.get_children():
				if child is MeshInstance3D and child.mesh is CylinderMesh: scout_cylinders+=1
			assert(scout_cylinders>=9,"recon scout should include four 3D wheels, hubs and its sensor")
		var angled_vehicle:=Node3D.new()
		LowpolyModelFactory.vehicle(angled_vehicle,{"kind":kind,"hp":100,"max_hp":100,"angle":PI*0.5,"turret":0.4},Color("69d6c0"),"forge",0.4)
		assert(not is_equal_approx(model.rotation.y,angled_vehicle.get_child(0).rotation.y),"%s should turn in 3D around its vertical axis" % kind)
		angled_vehicle.free()
		if kind=="tank":
			var tread_vehicle:=Node3D.new()
			LowpolyModelFactory.vehicle(tread_vehicle,{"kind":kind,"hp":100,"max_hp":100,"angle":0.0,"drive_frame":1},Color("69d6c0"),"forge",0.4)
			var still_cleat:MeshInstance3D=model.find_child("Track cleat",true,false)
			var moving_cleat:MeshInstance3D=tread_vehicle.get_child(0).find_child("Track cleat",true,false)
			assert(not is_equal_approx(still_cleat.position.z,moving_cleat.position.z),"tracked vehicles should animate their 3D tread position while moving")
			tread_vehicle.free()
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
	print("2.5D models: prototype plus 8 detailed, independently turning 3D vehicle archetypes, moving treads and 8 footprint-sized buildings loaded")
	quit()
