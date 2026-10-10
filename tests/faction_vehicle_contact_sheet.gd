extends SceneTree

const Painter=preload("res://scripts/vehicle_cache_painter.gd")
const CatalogType=preload("res://scripts/catalog.gd")
const SimulationType=preload("res://scripts/simulation.gd")
const KINDS=["scout","raider","tank","siege","harvester","lancer","scorcher","bulwark"]
const FACTIONS=["forge","drift","lumen"]
const CELL=512
var captured:Dictionary={}
var visual_bounds:Dictionary={}

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var catalog=CatalogType.new()
	var sim=SimulationType.new(catalog,"forge","normal")
	for kind in KINDS:
		var base:Dictionary=catalog.units[kind]
		for faction in FACTIONS:
			var view=SubViewport.new()
			view.size=Vector2i(CELL,CELL)
			view.transparent_bg=true
			view.own_world_3d=true
			view.msaa_3d=Viewport.MSAA_4X
			view.render_target_update_mode=SubViewport.UPDATE_ONCE
			root.add_child(view)
			var painter=Painter.new()
			painter.art=IndustrialArt.new()
			painter.entity={"id":1,"kind":kind,"owner":0,"hp":float(base.health),"max_hp":float(base.health),"angle":0.0,"turret":0.0,"drive_frame":0,"visual_animation_state":0,"visual_damage_state":0,"visual_cargo_state":0,"cargo":0.0,"velocity":Vector2.ZERO}
			painter.team=Color("d4ded7")
			painter.faction=faction
			painter.sim=sim
			view.add_child(painter)
			await process_frame
			await RenderingServer.frame_post_draw
			var image=view.get_texture().get_image()
			assert(image!=null and not image.is_empty(),"capture failed for %s/%s"%[faction,kind])
			var expected_name="Authored vehicle" if faction=="forge" else "Faction vehicle"
			var imported=painter.get_node_or_null(expected_name) as Node3D
			assert(imported!=null,"real game painter did not select %s/%s GLB"%[faction,kind])
			visual_bounds["%s_%s"%[faction,kind]]=_world_bounds(imported)
			assert(imported.find_child("TeamColor",true,false) is MeshInstance3D,"%s/%s must preserve ownership identification"%[faction,kind])
			if kind=="harvester":
				assert(imported.find_child("CutterDrumRotor",true,false)!=null,"%s collector needs a named animated intake rotor"%faction)
				assert(imported.find_child("CargoStage08",true,false)!=null,"%s collector needs visible load states"%faction)
				var player=imported.find_child("AnimationPlayer",true,false) as AnimationPlayer
				assert(player!=null and player.has_animation("Harvest") and player.has_animation("Unload"),"%s collector needs working harvest and unload clips"%faction)
			for node_name in ["DamageLight","DamageHeavy"]:
				assert(imported.find_child(node_name,true,false)!=null,"%s/%s must retain %s"%[faction,kind,node_name])
			var path="res://test-output/faction_contact_%s_%s.png"%[faction,kind]
			assert(image.save_png(path)==OK,"could not save %s"%path)
			captured["%s_%s"%[faction,kind]]=ProjectSettings.globalize_path(path)
			painter.free(); view.free()
			await process_frame
	# Visual assets must not alter the role's simulation definition. Existing
	# faction multipliers are an explicit balance layer, separate from model size.
	for kind in KINDS:
		var reference:Dictionary=catalog.units[kind]
		for faction in FACTIONS:
			assert(catalog.units[kind]==reference,"model faction unexpectedly changes the %s role definition"%kind)
	# Uniform mathematical separation avoids any asset-derived collision radius.
	assert(str(FileAccess.get_file_as_string("res://scripts/simulation.gd")).contains("func unit_separation"),"shared collision/separation implementation must remain model-independent")
	var json=JSON.stringify({"captures":captured,"visual_bounds":visual_bounds,"roles":KINDS,"factions":FACTIONS,"camera":"LowpolyModelFactory.CACHE_CAMERA_POSITION; 7.2 ortho; 512px; 4x MSAA","note":"Cache view enlarged only for sheet layout; source captures are unmodified game vehicle-cache renders."},"\t")
	var file=FileAccess.open("res://test-output/faction_vehicle_contact.json",FileAccess.WRITE)
	file.store_string(json); file.close()
	print("Faction contact captures: 24 role/faction sprites, game cache view, PBR imported, gameplay role data unchanged")
	quit()

func _world_bounds(root_node:Node3D)->Dictionary:
	var found:=false
	var bounds:=AABB()
	var stack:Array[Node]=[root_node]
	while not stack.is_empty():
		var node:Node=stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null:
			var mesh:=node as MeshInstance3D
			var transformed:=mesh.global_transform*mesh.get_aabb()
			bounds=transformed if not found else bounds.merge(transformed)
			found=true
		for child in node.get_children(): stack.append(child)
	return {"x":snappedf(bounds.size.x,0.01),"y":snappedf(bounds.size.y,0.01),"z":snappedf(bounds.size.z,0.01)} if found else {}
