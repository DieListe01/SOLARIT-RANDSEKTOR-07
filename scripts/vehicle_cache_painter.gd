extends Node3D
class_name VehicleCachePainter
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
	# Contact shadows deepen the low-poly seams and keep the 3D cache art from
	# reading like a flat icon after it is scaled down into the RTS view.
	environment.ssao_enabled=true
	environment.ssao_radius=1.15
	environment.ssao_intensity=1.05
	environment.ssao_power=1.2
	environment_node.environment=environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color("ffe1b6")
	sun.light_energy=1.35
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=22
	add_child(sun)
	var camera := Camera3D.new()
	camera.name="Cache camera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=7.2
	camera.position=Vector3(7.5,9.5,11.5)
	add_child(camera)
	camera.look_at(Vector3(0,0.7,0),Vector3.UP)
	camera.current=true
	_add_shadow()
	var kind := str(entity.get("kind", "tank"))
	var asset_path := "res://assets/models/vehicles/%s.glb" % kind
	if ModelAssets.add_optional_glb(self, asset_path, "Authored vehicle",team):
		var imported_model := get_node("Authored vehicle") as Node3D
		var body_angle := float(entity.get("angle",0.0))
		var body_yaw := LowpolyModelFactory.heading_yaw_for_screen_angle(body_angle)
		imported_model.rotation.y=body_yaw
		var turret := imported_model.find_child("Turret",true,false) as Node3D
		if turret != null:
			turret.rotation.y=LowpolyModelFactory.heading_yaw_for_screen_angle(body_angle+float(entity.get("turret",0.0)))-body_yaw
		return
	LowpolyModelFactory.vehicle(self,entity,team,faction,float(entity.get("turret",0.0)))

func _add_shadow() -> void:
	var shadow := MeshInstance3D.new()
	shadow.name="Soft ground shadow"
	var mesh := PlaneMesh.new()
	mesh.size=Vector2(3.2,4.1)
	shadow.mesh=mesh
	shadow.position=Vector3(0,0.025,0)
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(0.12,0.075,0.04,0.3)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override=material
	add_child(shadow)
