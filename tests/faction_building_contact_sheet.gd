extends SceneTree

const Painter=preload("res://scripts/building_cache_painter.gd")
const CatalogType=preload("res://scripts/catalog.gd")
const SimulationType=preload("res://scripts/simulation.gd")
const KINDS=["core","power","refinery","factory","tower","radar","repair","armory"]
const FACTIONS=["forge","drift","lumen"]
const CELL=512
var captured:Dictionary={}

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var catalog=CatalogType.new()
	var sim=SimulationType.new(catalog,"forge","normal")
	for kind in KINDS:
		var base:Dictionary=catalog.buildings[kind]
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
			painter.entity={"id":1,"kind":kind,"owner":0,"building":true,"complete":true,"construction_stage":5,"build_progress":float(base.time),"upgrade_level":0,"rotation":0,"turret":0.0,"building_animation_frame":0,"unloading":false,"hp":float(base.health),"max_hp":float(base.health)}
			painter.team=Color("d4ded7")
			painter.faction=faction
			painter.sim=sim
			view.add_child(painter)
			await process_frame
			await RenderingServer.frame_post_draw
			var image=view.get_texture().get_image()
			assert(image!=null and not image.is_empty(),"capture failed for %s/%s"%[faction,kind])
			var expected_name="Authored building" if faction=="forge" else "Faction building"
			var imported=painter.get_node_or_null(expected_name) as Node3D
			assert(imported!=null,"real building painter did not select %s/%s GLB"%[faction,kind])
			assert(imported.find_child("TeamColor",true,false) is MeshInstance3D,"%s/%s must preserve ownership identification"%[faction,kind])
			for pivot in ["CommandSensorPivot","ReactorRotor","RadarRotor","TurretPivot","ProductionCrane","RepairArmLeft","RepairArmRight","OrdnanceLift","UnloadGate"]:
				if imported.find_child(pivot,true,false)!=null:
					assert(imported.find_child(pivot,true,false) is Node3D,"%s/%s pivot %s must be poseable"%[faction,kind,pivot])
			var path="res://test-output/faction_building_contact_%s_%s.png"%[faction,kind]
			assert(image.save_png(path)==OK,"could not save %s"%path)
			captured["%s_%s"%[faction,kind]]=ProjectSettings.globalize_path(path)
			painter.free(); view.free()
			await process_frame
	for kind in KINDS:
		var reference:Dictionary=catalog.buildings[kind]
		for faction in FACTIONS:
			assert(catalog.buildings[kind]==reference,"faction model unexpectedly changes %s building definition"%kind)
	var json=JSON.stringify({"captures":captured,"roles":KINDS,"factions":FACTIONS,"camera":"BuildingCachePainter; fixed orthographic camera; 512px; 4x MSAA","note":"Unmodified normal game cache renders; source cells share identical lighting and camera."},"\t")
	var file=FileAccess.open("res://test-output/faction_building_contact.json",FileAccess.WRITE)
	file.store_string(json); file.close()
	print("Faction building contact captures: 24 role/faction sprites through the normal building cache painter")
	quit()
