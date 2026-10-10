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
	var faction_asset_path := "res://assets/models/buildings/factions/%s_%s.glb" % [faction,kind]
	var asset_path := "res://assets/models/buildings/%s.glb" % kind
	var loaded_faction_model:=ModelAssets.add_optional_glb(self, faction_asset_path, "Faction building",team)
	var loaded_standard_model:=false
	if not loaded_faction_model:
		loaded_standard_model=ModelAssets.add_optional_glb(self, asset_path, "Authored building",team)
	if loaded_faction_model or loaded_standard_model:
		var model: Node3D=get_node("Faction building" if loaded_faction_model else "Authored building") as Node3D
		ModelAssets.apply_building_pose(model, entity)
		var construction_stage:=int(entity.get("construction_stage",5))
		if construction_stage<5:
			var total:=maxf(0.01,float(sim.definition(entity).time))
			var progress:=clampf(float(entity.get("build_progress",0.0))/total,0.0,1.0)
			model.visible=construction_stage>=2
			if model.visible:
				model.scale.y=clampf(0.34+(progress-0.5)*2.2,0.34,1.0)
			_add_construction_rig(footprint/float(sim.grid.tile),construction_stage)
		return
	LowpolyModelFactory.building(self,entity,team,faction,footprint)

func _add_construction_rig(footprint: Vector2, stage: int) -> void:
	var width:=maxf(1.8,footprint.x*0.82)
	var depth:=maxf(1.8,footprint.y*0.82)
	_add_construction_box("Cast construction pad",Vector3(width,0.20,depth),Vector3(0,0.12,0),Color("303b38"),0.78)
	var anchor_mat:=Color("a77b3f")
	for side in [-1.0,1.0]:
		for fore_aft in [-1.0,1.0]:
			_add_construction_box("Foundation anchor",Vector3(0.13,0.42,0.13),Vector3(side*width*0.43,0.20,fore_aft*depth*0.43),anchor_mat,0.58)
	if stage<1: return
	var frame_mat:=Color("697a72")
	var height:=1.75 if stage==1 else 2.55
	for side in [-1.0,1.0]:
		for fore_aft in [-1.0,1.0]:
			_add_construction_box("Erected structural column",Vector3(0.105,height,0.105),Vector3(side*width*0.36,0.22+height*0.5,fore_aft*depth*0.36),frame_mat,0.72)
	for fore_aft in [-1.0,1.0]:
		_add_construction_box("Open roof crossbeam",Vector3(width*0.78,0.11,0.12),Vector3(0,0.22+height,fore_aft*depth*0.36),frame_mat,0.72)
	for side in [-1.0,1.0]:
		_add_construction_box("Side truss",Vector3(0.10,0.10,depth*0.72),Vector3(side*width*0.36,0.22+height,0),frame_mat,0.72)
	if stage<2: return
	var team_mat:=StandardMaterial3D.new()
	team_mat.albedo_color=team
	team_mat.emission_enabled=true
	team_mat.emission=team
	team_mat.emission_energy_multiplier=0.55
	for side in [-1.0,1.0]:
		_add_construction_box("Assembly guide light",Vector3(0.07,height+0.22,0.07),Vector3(side*width*0.40,0.25+(height+0.22)*0.5,depth*0.40),Color("45d8c5"),0.15,team_mat)
	if stage>=4:
		_add_construction_box("Commissioning power rail",Vector3(width*0.68,0.045,0.06),Vector3(0,1.60,0),Color("45d8c5"),0.15,team_mat)

func _add_construction_box(label: String, size: Vector3, position: Vector3, color: Color, metallic: float, custom_material: Material = null) -> void:
	var instance:=MeshInstance3D.new()
	instance.name=label
	var box:=BoxMesh.new()
	box.size=size
	instance.mesh=box
	instance.position=position
	var material:=custom_material
	if material==null:
		var surface:=StandardMaterial3D.new()
		surface.albedo_color=color
		surface.metallic=metallic
		surface.roughness=0.52
		material=surface
	instance.material_override=material
	add_child(instance)

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
