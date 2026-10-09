extends SceneTree

const ModelAssets=preload("res://scripts/model_asset_library.gd")
const VehiclePainter=preload("res://scripts/vehicle_cache_painter.gd")
const ModelFactory=preload("res://scripts/lowpoly_model_factory.gd")

func _initialize() -> void:
	call_deferred("run")

func descendants(node:Node) -> Array[Node]:
	var result:Array[Node]=[]
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func run() -> void:
	var vehicle_signatures:Dictionary={
		"scout":"Tri-band recon mast", "tank":"Long rifled cannon",
		"siege":"Deployable firing leg", "harvester":"Transverse rotary cutter drum",
		"raider":"Forward impact ram", "lancer":"Coherent beam lance",
		"scorcher":"Protected propellant vessel", "bulwark":"Full-width assault mantlet",
	}
	var vehicle_mesh_counts:Dictionary={}
	for kind in vehicle_signatures:
		var path="res://assets/models/vehicles/%s.glb"%kind
		assert(FileAccess.file_exists(path),"the authored %s vehicle should ship as its own GLB"%kind)
		var source_path="res://assets/models/source/harvester.blend" if kind=="harvester" else "res://assets/models/source/vehicles/%s.blend"%kind
		assert(FileAccess.file_exists(source_path),"the %s GLB must have its own editable Blender source scene"%kind)
		var packed=ResourceLoader.load(path,"PackedScene") as PackedScene
		assert(packed!=null,"the authored %s model should import as a Godot scene"%kind)
		var model=packed.instantiate() as Node3D
		root.add_child(model)
		await process_frame
		var nodes:=descendants(model)
		var mesh_count:=0
		var named_mesh:=false
		for node in nodes:
			if node is MeshInstance3D:
				mesh_count+=1
				if str(node.name).contains(str(vehicle_signatures[kind])): named_mesh=true
		assert(mesh_count>=8,"%s should contain an authored multipart vehicle model, not a flat stand-in (got %d meshes)"%[kind,mesh_count])
		assert(named_mesh,"%s should retain its role-specific mechanical silhouette feature"%kind)
		assert(model.find_child("TeamColor",true,false) is MeshInstance3D,"%s should expose faction-colored identification hardware"%kind)
		assert(model.find_child("DamageLight",true,false)!=null and model.find_child("DamageHeavy",true,false)!=null,"%s should have authored damage overlays"%kind)
		ModelAssets.apply_cached_animation(model,{"visual_damage_state":0})
		assert(not model.find_child("DamageLight",true,false).visible and not model.find_child("DamageHeavy",true,false).visible,"%s starts clean until its simulated damage state changes"%kind)
		ModelAssets.apply_cached_animation(model,{"visual_damage_state":2})
		assert(model.find_child("DamageLight",true,false).visible and model.find_child("DamageHeavy",true,false).visible,"%s exposes both damage detail tiers when heavily damaged"%kind)
		if kind in ["tank","siege","scorcher","bulwark"]:
			var turret:=model.find_child("Turret",true,false) as Node3D
			assert(turret!=null and not descendants(turret).is_empty(),"%s turret geometry should follow its independent 3D pivot"%kind)
			var initial_yaw:=turret.rotation.y
			turret.rotation.y=.55
			assert(not is_equal_approx(turret.rotation.y,initial_yaw),"%s must preserve independent turret traverse"%kind)
		var tint_host:=Node3D.new()
		root.add_child(tint_host)
		assert(ModelAssets.add_optional_glb(tint_host,path,"Faction vehicle",Color("e49a63")),"%s should load through the normal vehicle cache asset seam"%kind)
		var tinted=tint_host.get_node("Faction vehicle").find_child("TeamColor",true,false) as MeshInstance3D
		var source_color:Color=((model.find_child("TeamColor",true,false) as MeshInstance3D).get_active_material(0) as StandardMaterial3D).albedo_color
		var tinted_material=tinted.get_surface_override_material(0) as StandardMaterial3D if tinted!=null else null
		assert(tinted_material!=null and tinted_material.albedo_color.is_equal_approx(source_color*Color("e49a63")),"%s ownership markings should use the current friend/enemy color"%kind)
		vehicle_mesh_counts[kind]=mesh_count
		model.free(); tint_host.free()
		await process_frame
	var unique_vehicle_mesh_counts:Dictionary={}
	for count in vehicle_mesh_counts.values(): unique_vehicle_mesh_counts[count]=true
	assert(unique_vehicle_mesh_counts.size()>=3,"combat and support units should use distinct authored material assemblies")
	var building_signatures:Dictionary={
		"core":"Raised armored command citadel", "power":"Primary reactor containment ring",
		"refinery":"Ore conveyor belt", "factory":"Overhead bridge crane",
		"tower":"Rotating gunhouse", "radar":"Signal dish core",
		"repair":"Drive-through service door", "armory":"Sealed ammunition canister",
	}
	var architectural_counts:Dictionary={}
	for kind in building_signatures:
		var packed=ResourceLoader.load("res://assets/models/buildings/%s.glb"%kind,"PackedScene") as PackedScene
		assert(packed!=null,"%s must retain its authored building GLB"%kind)
		var model=packed.instantiate() as Node3D
		root.add_child(model); await process_frame
		var nodes:=descendants(model); var mesh_count:=0; var signature_found:=false
		for node in nodes:
			if node is MeshInstance3D: mesh_count+=1
			if str(node.name).contains(str(building_signatures[kind])): signature_found=true
		assert(mesh_count>=20,"%s should retain detailed Blender-authored building geometry"%kind)
		assert(signature_found,"%s should expose the machinery that explains its purpose"%kind)
		assert(model.find_child("TeamColor",true,false)!=null,"%s should identify its owner"%kind)
		architectural_counts[kind]=mesh_count
		model.free(); await process_frame
	var distinct_building_counts:Dictionary={}
	for count in architectural_counts.values(): distinct_building_counts[count]=true
	assert(distinct_building_counts.size()>=5,"buildings should contain visibly different authored structures and hardware")
	for kind in vehicle_signatures:
		var painter=VehiclePainter.new()
		painter.art=IndustrialArt.new()
		painter.entity={"id":91,"kind":kind,"owner":0,"hp":100.0,"max_hp":100.0,"angle":PI/2,"turret":0.2,"drive_frame":0,"visual_animation_state":0,"visual_damage_state":0,"visual_cargo_state":0,"cargo":0.0,"velocity":Vector2.ZERO}
		painter.team=Color("69d6c0"); painter.faction="forge"
		root.add_child(painter); await process_frame
		var in_game_model:=painter.get_node_or_null("Authored vehicle") as Node3D
		assert(in_game_model!=null,"the real vehicle cache painter should select the %s GLB"%kind)
		assert(is_equal_approx(in_game_model.rotation.y,ModelFactory.heading_yaw_for_screen_angle(PI/2)),"the imported %s hull should track its diagonal movement heading"%kind)
		painter.free(); await process_frame
	print("Authored Blender asset audit: 8 independent vehicle roles and 8 purpose-designed buildings; faction markers, damage states and turret pivots verified")
	quit()
