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
	var heading_frames:Dictionary={}
	var camera_backward:Vector3=(LowpolyModelFactory.CACHE_CAMERA_POSITION-LowpolyModelFactory.CACHE_CAMERA_TARGET).normalized()
	var camera_right:Vector3=Vector3.UP.cross(camera_backward).normalized()
	var camera_up:Vector3=camera_backward.cross(camera_right).normalized()
	for i in 32:
		var screen_angle:=float(i)*TAU/32.0
		var heading:int=WorldRenderer.vehicle_heading_frame(screen_angle)
		heading_frames[heading]=true
		var yaw:float=LowpolyModelFactory.heading_yaw_for_screen_angle(screen_angle)
		var forward:Vector3=Basis(Vector3.UP,yaw)*Vector3(0,0,-1)
		var projected:=Vector2(camera_right.dot(forward),-camera_up.dot(forward)).normalized()
		assert(projected.dot(Vector2(cos(screen_angle),sin(screen_angle)))>0.999,"3D body projection should line up with its 2D movement angle")
	assert(heading_frames.size()==32,"vehicle cache should expose 32 evenly spaced body headings")
	var turret_frames:Dictionary={}
	for i in 16:
		var turret:int=WorldRenderer.vehicle_turret_frame(float(i)*TAU/16.0-PI)
		turret_frames[turret]=true
	assert(turret_frames.size()==16,"vehicle turret should retain 16 independent aim angles")
	var vehicle_features := {"harvester":"Collector arm","scout":"Scout front bumper","tank":"Wheel hub","siege":"Muzzle ring","raider":"Raider side blade","lancer":"Lance emitter","scorcher":"Flame nozzle","bulwark":"Bulwark prow"}
	for kind in ["harvester","scout","tank","siege","raider","lancer","scorcher","bulwark"]:
		var vehicle := Node3D.new()
		samples.add_child(vehicle)
		LowpolyModelFactory.vehicle(vehicle,{"kind":kind,"hp":100,"max_hp":100,"angle":0.0,"turret":0.4},Color("69d6c0"),"forge",0.4)
		var model:Node3D=vehicle.get_child(0)
		assert(model.get_child_count() >= 6, "%s should have detailed low-poly model geometry" % kind)
		assert(model.find_child(vehicle_features[kind],true,false)!=null,"%s should have its own readable 3D detail" % kind)
		var id_plate:MeshInstance3D=model.find_child("Team ID plate",true,false)
		assert(id_plate!=null and id_plate.material_override is StandardMaterial3D and (id_plate.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("69d6c0")),"%s should carry a visible owner-color plate" % kind)
		if kind=="harvester":
			assert(model.find_child("Turret",true,false)==null and model.find_child("Weapon",true,false)==null,"collector must not share the tank turret silhouette")
			assert(model.find_child("Collector cargo bed",true,false)!=null and model.find_child("Collector cutting edge",true,false)!=null,"collector should have a rear ore hopper and wide front cutter")
		if kind=="tank":
			assert(model.find_child("Turret",true,false)!=null and model.find_child("Weapon",true,false)!=null,"tank should remain visibly armed and distinct from a collector")
			var tread_shoe:MeshInstance3D=model.find_child("Track cleat",true,false)
			assert(tread_shoe!=null and tread_shoe.material_override is StandardMaterial3D and (tread_shoe.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("77796f")),"tank tread shoes should read as dark metal instead of pale hull striping")
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
	print("2.5D models: 32 projection-aligned headings, 16 turret angles, distinct harvester and tank silhouettes, owner-color plates and detailed 3D models loaded")
	quit()
