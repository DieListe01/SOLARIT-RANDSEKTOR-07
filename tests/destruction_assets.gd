extends SceneTree

const FACTIONS=["forge","drift","lumen"]
const VEHICLE_ROLES=["scout","raider","tank","siege","harvester","lancer","scorcher","bulwark"]
const BUILDING_ROLES=["power","refinery","factory","tower","radar","repair","armory","core"]
const TILE:=256
var checks:=0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for faction in FACTIONS:
		checks+=_check_atlas("vehicles",faction,8,VEHICLE_ROLES.size())
		checks+=_check_atlas("buildings",faction,4,BUILDING_ROLES.size())
	print("Destruction atlas audit passed: %d authored GLB sprites, faction sets, role rows and orientation cells"%(VEHICLE_ROLES.size()*8*FACTIONS.size()+BUILDING_ROLES.size()*4*FACTIONS.size()))
	quit(0)

func _check_atlas(family_name: String, faction: String, directions: int, rows: int) -> int:
	var path="res://assets/rendered/destruction/%s_%s.png"%[family_name,faction]
	assert(FileAccess.file_exists(path),"missing 3D destruction atlas: "+path)
	var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(image!=null and not image.is_empty(),"could not load destruction atlas: "+path)
	assert(image.get_width()==TILE*directions and image.get_height()==TILE*rows,"unexpected atlas dimensions: "+path)
	for row in rows:
		for direction in directions:
			var populated:=false
			for y in range(row*TILE+8,(row+1)*TILE,16):
				for x in range(direction*TILE+8,(direction+1)*TILE,16):
					if image.get_pixel(x,y).a>0.08:
						populated=true
						break
				if populated: break
			assert(populated,"empty rendered cell %s row %d heading %d"%[path,row,direction])
	return directions*rows
