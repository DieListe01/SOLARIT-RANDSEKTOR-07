extends SceneTree
const ModelAssets = preload("res://scripts/model_asset_library.gd")

func count_named_descendants(node: Node, prefix: String) -> int:
	var count:=0
	for child in node.get_children():
		if str(child.name).begins_with(prefix): count+=1
		count+=count_named_descendants(child,prefix)
	return count

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
	var optional_asset_probe := Node3D.new()
	assert(not ModelAssets.add_optional_glb(optional_asset_probe,"res://assets/models/vehicles/test_missing_model.glb","Missing test model"),"missing authored assets should cleanly select the procedural fallback")
	assert(optional_asset_probe.get_child_count()==0,"a missing GLB must not add a partial model scene")
	optional_asset_probe.free()
	var team_tint_probe := MeshInstance3D.new()
	team_tint_probe.name="TeamColor"
	team_tint_probe.mesh=BoxMesh.new()
	team_tint_probe.material_override=StandardMaterial3D.new()
	ModelAssets.apply_team_tint(team_tint_probe,Color("e49a63"))
	assert((team_tint_probe.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color("e49a63")),"authored GLB TeamColor surfaces should inherit the owning faction color")
	team_tint_probe.free()
	var progress_renderer := WorldRenderer.new()
	var progress_entity := {"id":42}
	assert(not progress_renderer.world_progress_label_visible(progress_entity),"unfocused construction should use the compact bar without a text plate")
	progress_renderer.hovered_entity_id=42
	assert(progress_renderer.world_progress_label_visible(progress_entity),"hover should reveal construction context")
	progress_renderer.hovered_entity_id=0
	progress_renderer.selected=[42]
	assert(progress_renderer.world_progress_label_visible(progress_entity),"selection should reveal construction context")
	progress_renderer.free()
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
	var vehicle_features := {"harvester":"Ore conveyor housing","scout":"Scout front bumper","tank":"Wheel hub","siege":"Stabilizer foot","raider":"Raider wedge blade","lancer":"Lance capacitor","scorcher":"Flame projector mount","bulwark":"Bulwark side armor"}
	var vehicle_lengths: Dictionary={}
	for kind in ["harvester","scout","tank","siege","raider","lancer","scorcher","bulwark"]:
		var vehicle := Node3D.new()
		samples.add_child(vehicle)
		LowpolyModelFactory.vehicle(vehicle,{"kind":kind,"hp":100,"max_hp":100,"angle":0.0,"turret":0.4},Color("69d6c0"),"forge",0.4)
		var model:Node3D=vehicle.get_child(0)
		var lower_hull:MeshInstance3D=model.find_child("Lower hull",true,false)
		vehicle_lengths[kind]=(lower_hull.mesh as BoxMesh).size.z
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
			assert(tread_shoe!=null and tread_shoe.material_override is StandardMaterial3D and (tread_shoe.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("343a37")),"tank tread shoes should read as dark metal instead of pale hull striping")
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
		if kind=="scorcher":
			var flame_mount:Node3D=model.find_child("Flame projector mount",true,false)
			var flame_lances:=count_named_descendants(flame_mount,"Flame lance") if flame_mount!=null else 0
			assert(flame_mount!=null and flame_lances==2,"scorcher should show a distinct twin-nozzle flame projector")
		if kind=="siege":
			assert(model.find_child("Open mortar cradle",true,false)!=null and model.find_child("Shell rack",true,false)!=null,"artillery should have a separated mortar cradle and ammunition racks")
	assert(vehicle_lengths.scout < vehicle_lengths.raider and vehicle_lengths.raider < vehicle_lengths.tank and vehicle_lengths.tank < vehicle_lengths.siege and vehicle_lengths.siege < vehicle_lengths.bulwark,"combat vehicles follow the scout-to-heavy-tank visual size ladder")
	assert(vehicle_lengths.harvester > vehicle_lengths.tank,"industrial harvester reads larger than a normal battle tank")
	var drift_tank := Node3D.new()
	LowpolyModelFactory.vehicle(drift_tank,{"kind":"tank","hp":100,"max_hp":100,"angle":0.0,"turret":0.0},Color("e49a63"),"drift",0.0)
	var drift_model:Node3D=drift_tank.get_child(0)
	assert(drift_model.find_child("Track",true,false)==null and drift_model.find_child("Drift wedge glacis",true,false)!=null and count_named_descendants(drift_model,"Drift road tire")==4,"Wanderpakt armor should have a light wheeled wedge silhouette")
	drift_tank.free()
	var lumen_tank := Node3D.new()
	LowpolyModelFactory.vehicle(lumen_tank,{"kind":"tank","hp":100,"max_hp":100,"angle":0.0,"turret":0.0},Color("b69bfa"),"lumen",0.0)
	var lumen_model:Node3D=lumen_tank.get_child(0)
	assert(lumen_model.find_child("Track",true,false)==null and lumen_model.find_child("Lumen ventral reactor",true,false)!=null and lumen_model.find_child("Hover pod",true,false)!=null,"Prisma-Konklave armor should hover above a visible energy core")
	lumen_tank.free()
	var damaged_tank := Node3D.new()
	LowpolyModelFactory.vehicle(damaged_tank,{"kind":"tank","hp":30,"max_hp":100,"angle":0.0,"turret":0.4},Color("69d6c0"),"forge",0.4)
	assert(damaged_tank.find_child("Scorched armor edge",true,false)!=null and damaged_tank.find_child("Blown armor panel",true,false)!=null,"heavy damage adds visible armor failure details")
	damaged_tank.free()
	assert(LowpolyModelFactory._material(Color("343a37"),0.86,0.12)==LowpolyModelFactory._material(Color("343a37"),0.86,0.12),"identical procedural materials are shared across models")
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
	print("2.5D models: unique vehicle roles and faction silhouettes, size ladder, damage tiers, shared materials, compact progress labels, optional GLB fallback, 32 headings and 16 turret angles")
	quit()
