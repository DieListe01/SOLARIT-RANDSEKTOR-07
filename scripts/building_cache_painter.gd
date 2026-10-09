extends Node3D
class_name BuildingCachePainter
const ModelAssets = preload("res://scripts/model_asset_library.gd")

var art: IndustrialArt
var entity: Dictionary
var team := Color.WHITE
var faction := "forge"
var sim: Simulation

func _ready() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0,0,0,0)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("c3d3cd")
	environment.ambient_light_energy=0.8
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled=true
	environment.ssao_radius=1.3
	environment.ssao_intensity=1.1
	environment.ssao_power=1.2
	environment_node.environment=environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color("ffe1b6")
	sun.light_energy=1.35
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=26
	add_child(sun)
	var camera := Camera3D.new()
	camera.name="Cache camera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=8.4
	camera.position=Vector3(7.5,10.5,12.5)
	add_child(camera)
	camera.look_at(Vector3(0,0.65,0),Vector3.UP)
	camera.current=true
	var footprint_data: Array=sim.definition(entity).footprint
	var footprint := Vector2(footprint_data[0],footprint_data[1])*sim.grid.tile
	_add_shadow(footprint)
	var kind := str(entity.get("kind", "core"))
	var asset_path := "res://assets/models/buildings/%s.glb" % kind
	if ModelAssets.add_optional_glb(self, asset_path, "Authored building",team):
		ModelAssets.apply_building_pose(get_node("Authored building") as Node3D, entity)
		return
	LowpolyModelFactory.building(self,entity,team,faction,footprint)

func _add_shadow(footprint: Vector2) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name="Soft ground shadow"
	var mesh := PlaneMesh.new()
	mesh.size=Vector2(maxf(1.8,footprint.x/32.0*1.35),maxf(1.8,footprint.y/32.0*1.35))
	shadow.mesh=mesh
	shadow.position=Vector3(0,0.025,0)
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(0.12,0.075,0.04,0.25)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override=material
	add_child(shadow)
