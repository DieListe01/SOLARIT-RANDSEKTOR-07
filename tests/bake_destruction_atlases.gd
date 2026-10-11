extends SceneTree

const VehiclePainter=preload("res://scripts/vehicle_cache_painter.gd")
const BuildingPainter=preload("res://scripts/building_cache_painter.gd")
const ModelAssets=preload("res://scripts/model_asset_library.gd")
const CatalogType=preload("res://scripts/catalog.gd")
const SimulationType=preload("res://scripts/simulation.gd")
const TILE:=256
const VEHICLE_HEADINGS:=8
const BUILDING_HEADINGS:=4
const FACTIONS: Array[String]=["forge","drift","lumen"]
const VEHICLES: Array[String]=["scout","raider","tank","siege","harvester","lancer","scorcher","bulwark"]
const BUILDINGS: Array[String]=["power","refinery","factory","tower","radar","repair","armory","core"]
var catalog: Catalog
var sim: Simulation

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	catalog=CatalogType.new()
	sim=SimulationType.new(catalog,"forge","normal")
	var output_dir:=ProjectSettings.globalize_path("res://assets/rendered/destruction")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for faction in FACTIONS:
		await bake_vehicle_atlas(faction,output_dir)
		await bake_building_atlas(faction,output_dir)
	print("Baked authored 3D destruction atlases: 24 vehicle roles × 8 headings and 24 building roles × 4 rotations")
	quit(0)

func make_view(size: int) -> SubViewport:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(size,size)
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.gui_disable_input=true
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	return viewport

func capture(viewport: SubViewport, painter: Node3D) -> Image:
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	assert(image!=null and not image.is_empty(),"3D destruction render returned no image for "+painter.name)
	return image

func bake_vehicle_atlas(faction: String, output_dir: String) -> void:
	var atlas:=Image.create(TILE*VEHICLE_HEADINGS,TILE*VEHICLES.size(),false,Image.FORMAT_RGBA8)
	for role_index in VEHICLES.size():
		var kind:=VEHICLES[role_index]
		var base: Dictionary=catalog.units[kind]
		var viewport:=make_view(TILE)
		var painter:=VehiclePainter.new() as Node3D
		painter.art=IndustrialArt.new()
		painter.entity={"id":1,"kind":kind,"owner":0,"hp":float(base.health)*0.1,"max_hp":float(base.health),"angle":0.0,"turret":0.0,"drive_frame":0,"visual_animation_state":0,"animation_frame_count":4,"visual_damage_state":2,"visual_cargo_state":0,"cargo":0.0,"velocity":Vector2.ZERO}
		painter.team=Color.WHITE
		painter.faction=faction
		painter.sim=sim
		viewport.add_child(painter)
		await process_frame
		var model:=painter.get_node_or_null("Faction vehicle") as Node3D
		if model==null: model=painter.get_node_or_null("Authored vehicle") as Node3D
		assert(model!=null,"missing faction model %s/%s"%[faction,kind])
		ModelAssets.apply_vehicle_destruction_pose(model,painter.entity)
		_set_wreck_lighting(painter)
		for heading in VEHICLE_HEADINGS:
			var screen_angle:=float(heading)*TAU/float(VEHICLE_HEADINGS)
			model.rotation.y=LowpolyModelFactory.heading_yaw_for_screen_angle(screen_angle)
			var image: Image=await capture(viewport,painter)
			atlas.blit_rect(image,Rect2i(0,0,TILE,TILE),Vector2i(heading*TILE,role_index*TILE))
		painter.free(); viewport.free(); await process_frame
	var path=output_dir+"/vehicles_%s.png"%faction
	assert(atlas.save_png(path)==OK,"could not write vehicle destruction atlas: "+path)

func bake_building_atlas(faction: String, output_dir: String) -> void:
	var atlas:=Image.create(TILE*BUILDING_HEADINGS,TILE*BUILDINGS.size(),false,Image.FORMAT_RGBA8)
	for role_index in BUILDINGS.size():
		var kind:=BUILDINGS[role_index]
		var base: Dictionary=catalog.buildings[kind]
		var viewport:=make_view(TILE)
		var painter:=BuildingPainter.new() as Node3D
		painter.art=IndustrialArt.new()
		painter.entity={"id":1,"kind":kind,"owner":0,"building":true,"complete":true,"construction_stage":5,"build_progress":float(base.time),"rotation":0,"turret":0.0,"building_animation_frame":0,"unloading":false,"hp":float(base.health)*0.1,"max_hp":float(base.health),"upgrade_level":0,"repair":false}
		painter.team=Color.WHITE
		painter.faction=faction
		painter.sim=sim
		viewport.add_child(painter)
		await process_frame
		var model:=painter.get_node_or_null("Faction building") as Node3D
		if model==null: model=painter.get_node_or_null("Authored building") as Node3D
		assert(model!=null,"missing faction building %s/%s"%[faction,kind])
		ModelAssets.apply_building_destruction_pose(model,kind)
		_set_wreck_lighting(painter)
		for heading in BUILDING_HEADINGS:
			model.rotation.y=float(heading)*PI*0.5
			var image: Image=await capture(viewport,painter)
			atlas.blit_rect(image,Rect2i(0,0,TILE,TILE),Vector2i(heading*TILE,role_index*TILE))
		painter.free(); viewport.free(); await process_frame
	var path=output_dir+"/buildings_%s.png"%faction
	assert(atlas.save_png(path)==OK,"could not write building destruction atlas: "+path)

func _set_wreck_lighting(painter: Node) -> void:
	var sun:=painter.find_child("DirectionalLight3D",true,false) as DirectionalLight3D
	if sun!=null: sun.light_energy*=0.70
	var world:=painter.find_child("WorldEnvironment",true,false) as WorldEnvironment
	if world!=null and world.environment!=null: world.environment.ambient_light_energy*=0.62
