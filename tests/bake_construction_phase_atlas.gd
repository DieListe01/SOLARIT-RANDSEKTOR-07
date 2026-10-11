extends SceneTree

const BuildingPainter=preload("res://scripts/building_cache_painter.gd")
const CatalogType=preload("res://scripts/catalog.gd")
const SimulationType=preload("res://scripts/simulation.gd")
const TILE:=256
const PHASES: Array[float]=[0.20,0.50,0.80,0.95,1.0]
const BUILDINGS: Array[String]=["power","refinery","factory","tower","radar","repair","armory","core"]
var sim: Simulation

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog:=CatalogType.new()
	sim=SimulationType.new(catalog,"forge","normal")
	var atlas:=Image.create(TILE*PHASES.size(),TILE*BUILDINGS.size(),false,Image.FORMAT_RGBA8)
	for row in BUILDINGS.size():
		var kind:=BUILDINGS[row]
		var base: Dictionary=catalog.buildings[kind]
		for col in PHASES.size():
			var progress:=PHASES[col]
			var stage:=construction_stage(progress)
			var viewport:=SubViewport.new()
			viewport.size=Vector2i(TILE,TILE)
			viewport.msaa_3d=Viewport.MSAA_4X
			viewport.transparent_bg=true
			viewport.own_world_3d=true
			viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			root.add_child(viewport)
			var painter:=BuildingPainter.new() as Node3D
			painter.art=IndustrialArt.new()
			painter.sim=sim
			painter.team=Color("55d5c3")
			painter.faction="forge"
			painter.entity={"id":1,"kind":kind,"owner":0,"building":true,"complete":progress>=1.0,"construction_stage":stage,"build_progress":float(base.time)*progress,"rotation":0,"turret":0.0,"building_animation_frame":0,"unloading":false,"hp":float(base.health),"max_hp":float(base.health),"upgrade_level":0,"repair":false}
			viewport.add_child(painter)
			await process_frame
			await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			assert(image!=null and not image.is_empty(),"empty construction preview %s %.2f"%[kind,progress])
			atlas.blit_rect(image,Rect2i(0,0,TILE,TILE),Vector2i(col*TILE,row*TILE))
			painter.free()
			viewport.free()
			await process_frame
	var out_dir:=ProjectSettings.globalize_path("res://test-output")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path=out_dir+"/construction_phases_atlas.png"
	assert(atlas.save_png(path)==OK,"could not save construction phase atlas")
	print("Construction phase atlas captured: %d buildings × %d progress samples at 4× MSAA"%[BUILDINGS.size(),PHASES.size()])
	quit(0)

func construction_stage(progress: float) -> int:
	if progress<0.25: return 0
	if progress<0.50: return 1
	if progress<0.75: return 2
	if progress<0.85: return 3
	if progress<1.0: return 4
	return 5
