extends RefCounted
class_name ModelAssetLibrary

## Optional authored-asset seam. Imported GLB scenes are rendered by the same
## cache SubViewport as the procedural fallback, so the world renderer and its
## cache keys do not depend on how a model was authored.
static func add_optional_glb(parent: Node3D, resource_path: String, instance_name: String, team_color: Color = Color.WHITE) -> bool:
	if not ResourceLoader.exists(resource_path, "PackedScene"):
		return false
	var packed_scene := ResourceLoader.load(resource_path, "PackedScene") as PackedScene
	if packed_scene == null:
		push_warning("GLB model could not be loaded: %s" % resource_path)
		return false
	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		push_warning("GLB model root must inherit Node3D: %s" % resource_path)
		instance.free()
		return false
	instance.name = instance_name
	apply_team_tint(instance,team_color)
	parent.add_child(instance)
	return true

static func apply_team_tint(node: Node, team_color: Color) -> void:
	if node is MeshInstance3D and node.name.begins_with("TeamColor"):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh!=null:
			for surface in mesh_instance.mesh.get_surface_count():
				var source_material := mesh_instance.get_active_material(surface)
				var team_material: BaseMaterial3D
				if source_material is BaseMaterial3D:
					team_material=(source_material as BaseMaterial3D).duplicate() as BaseMaterial3D
				else:
					team_material=StandardMaterial3D.new()
				team_material.albedo_color*=team_color
				if team_material.emission_enabled: team_material.emission*=team_color
				mesh_instance.set_surface_override_material(surface,team_material)
	for child in node.get_children():
		apply_team_tint(child,team_color)

## Apply a deterministic pose to the authored industrial scene before it is
## rasterized. The game still displays cached 2D sprites; only changed state
## combinations require a new SubViewport render.
static func apply_building_pose(root: Node3D, entity: Dictionary) -> void:
	root.rotation.y = float(posmod(int(entity.get("rotation", 0)), 4)) * PI * 0.5
	var frame := posmod(int(entity.get("building_animation_frame", 0)), 8)
	_set_yaw(root, "CommandSensorPivot", float(frame) * TAU / 8.0)
	_set_yaw(root, "ReactorRotor", float(frame) * TAU / 4.0)
	_set_yaw(root, "RadarRotor", float(frame) * TAU / 8.0)
	_set_yaw(root, "TurretPivot", float(entity.get("turret", 0.0)))
	_set_yaw(root, "ProductionCrane", sin(float(frame) * TAU / 4.0) * 0.34)
	_set_yaw(root, "AssemblyArmLeft", -0.10 - float(frame % 4) * 0.12)
	_set_yaw(root, "AssemblyArmRight", 0.10 + float(frame % 4) * 0.12)
	if str(entity.get("kind", "")) == "factory" and (not entity.get("queue", []).is_empty() or int(entity.get("production_exit_unit",0))>0):
		_apply_factory_mechanism_pose(root, str(entity.get("faction", "forge")), frame)
	_set_yaw(root, "RepairArmLeft", -0.30 if frame > 0 else 0.0)
	_set_yaw(root, "RepairArmRight", 0.30 if frame > 0 else 0.0)
	_set_yaw(root, "OrdnanceLift", sin(float(frame) * TAU / 4.0) * 0.22)
	var gate := root.find_child("UnloadGate", true, false) as Node3D
	if gate != null:
		gate.rotation.x = -0.62 if bool(entity.get("unloading", false)) else 0.0
	var upgrade := root.find_child("UpgradeStage2", true, false)
	if upgrade != null:
		upgrade.visible = int(entity.get("upgrade_level", 0)) >= 1

## Move each faction's authored production mechanism through the existing four
## cached working poses. All moving parts use nodes from that faction's GLB.
static func _apply_factory_mechanism_pose(root: Node3D, faction: String, frame: int) -> void:
	# Four deliberate carriage positions make production readable at normal RTS
	# zoom, with a raised workpiece and a visible release-ramp cycle.
	var frame_index := posmod(frame, 4)
	var carriage_x: float = [-0.48, 0.48, 0.48, -0.48][frame_index]
	var carriage_z: float = [-0.40, -0.40, 0.40, 0.40][frame_index]
	var hoist_y: float = [0.92, 0.52, 0.74, 1.02][frame_index]
	if faction == "forge":
		var crane := root.find_child("ProductionCrane", true, false) as Node3D
		if crane != null:
			crane.position.x = carriage_x
			crane.position.z = carriage_z
		var ramp := root.find_child("Hydraulic deployment ramp", true, false) as Node3D
		if ramp != null: ramp.rotation.x = [-0.04, -0.14, -0.34, -0.18][frame_index]
	elif faction == "drift":
		var crane := root.find_child("ProductionCrane", true, false) as Node3D
		if crane != null:
			crane.position.x = carriage_x
			crane.position.z = carriage_z
			crane.position.y += [0.0, 0.14, 0.26, 0.10][frame_index]
		var rollers := root.find_children("Drive-in roller", "MeshInstance3D", true, false)
		for index in rollers.size():
			var roller := rollers[index] as Node3D
			roller.position.y += [0.02, 0.16, 0.24, 0.08][frame_index] * (1.0 if index % 2 == 0 else -0.35)
		var skid := root.find_child("Vehicle assembly skid", true, false) as Node3D
		if skid != null:
			skid.position.z += carriage_z * 0.72
	else:
		var trolley := root.find_child("Prismatic assembly trolley", true, false) as Node3D
		if trolley != null:
			trolley.position.x += carriage_x
			trolley.position.z += carriage_z
			trolley.position.y += hoist_y * 0.18
		var slab := root.find_child("Floating central armor slab", true, false) as Node3D
		if slab != null: slab.position.y += [0.04, 0.25, 0.42, 0.18][frame_index]

static func _set_yaw(root: Node, node_name: String, yaw: float) -> void:
	var node := root.find_child(node_name, true, false) as Node3D
	if node != null:
		node.rotation.y = yaw

## The 2D battlefield draws cached poses of the authored 3D scene. Select an
## animation from the simulation state and seek to a deterministic cache frame
## before the SubViewport renders, rather than advancing a live 3D scene per
## screen frame. Missing clips are optional and leave the imported bind pose.
static func apply_cached_animation(root: Node, entity: Dictionary) -> StringName:
	var cargo_state:=clampi(int(entity.get("visual_cargo_state",0)),0,8)
	for stage in range(1,9):
		var cargo_node:=root.find_child("CargoStage%02d"%stage,true,false)
		if cargo_node!=null: cargo_node.visible=stage<=cargo_state
	var damage_state:=clampi(int(entity.get("visual_damage_state",0)),0,2)
	var light_damage:=root.find_child("DamageLight",true,false)
	var heavy_damage:=root.find_child("DamageHeavy",true,false)
	if light_damage!=null: light_damage.visible=damage_state>=1
	if heavy_damage!=null: heavy_damage.visible=damage_state>=2
	var player := root.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player == null:
		return &""
	var state := int(entity.get("visual_animation_state",0))
	var animation_name: StringName
	match state:
		1: animation_name=&"Harvest"
		2: animation_name=&"Unload"
		3: animation_name=&"Move"
		_: animation_name=&"Idle"
	if not player.has_animation(animation_name):
		return &""
	var animation := player.get_animation(animation_name)
	if animation == null or animation.length <= 0.0:
		return &""
	var frame_count := maxi(1,int(entity.get("animation_frame_count",4)))
	var frame := posmod(int(entity.get("drive_frame",0)),frame_count)
	var pose_time := animation.length*float(frame)/float(frame_count)
	player.play(animation_name)
	player.seek(pose_time,true)
	player.pause()
	return animation_name

## Collapse the authored vehicle mesh into its post-destruction state before an
## offline 3D wreck atlas render. The intact role-specific model and its
## authored heavy-damage modules remain visible, so the final wreck is derived
## from the actual faction/role asset rather than a generic canvas silhouette.
static func apply_vehicle_destruction_pose(root: Node3D, entity: Dictionary) -> void:
	var wreck_entity:=entity.merged({"visual_damage_state":2},true)
	if str(entity.get("kind",""))=="harvester": wreck_entity["visual_cargo_state"]=8
	apply_cached_animation(root,wreck_entity)
	_apply_burnt_materials(root)
	root.scale*=Vector3(1.0,0.40,1.0)
	root.rotation.z+=0.24
	var turret:=root.find_child("Turret",true,false) as Node3D
	if turret!=null:
		# The detached and canted weapon assembly remains recognizable at RTS zoom.
		turret.position+=Vector3(0.62,-0.34,0.64)
		turret.rotation.x+=0.44
		turret.rotation.z+=0.56
	var cutter:=root.find_child("CutterDrumRotor",true,false) as Node3D
	if cutter!=null:
		cutter.position+=Vector3(0.16,-0.08,0.30)
		cutter.rotation.x+=0.72
	for module_name in ["ProductionCrane","UnloadGate","RadarRotor","CommandSensorPivot","OrdnanceLift"]:
		var module:=root.find_child(module_name,true,false) as Node3D
		if module!=null:
			module.position.y-=0.18
			module.rotation.x+=0.72
			module.rotation.z+=0.38
	# Reuse the model's authored heavy-damage panel mesh as displaced wreckage,
	# keeping this tied to the source model instead of replacing it with generic
	# debris primitives.
	var damage_panel:=root.find_child("DamageHeavy overlay",true,false) as MeshInstance3D
	if damage_panel!=null and damage_panel.mesh!=null:
		for index in 2:
			var fragment:=MeshInstance3D.new()
			fragment.name="Detached authored armor fragment %d"%index
			fragment.mesh=damage_panel.mesh
			var panel_material:=damage_panel.get_active_material(0)
			if panel_material==null:
				var shard_material:=StandardMaterial3D.new()
				shard_material.albedo_color=Color("55483b")
				shard_material.roughness=0.9
				fragment.material_override=shard_material
			else: fragment.material_override=panel_material
			fragment.scale=Vector3(0.58,0.58,0.58)
			fragment.position=Vector3(-0.78+index*1.48,0.07,0.42-index*0.83)
			fragment.rotation=Vector3(0.50+index*0.25,0.45,-0.70+index*0.9)
			root.add_child(fragment)
	_add_3d_rubble(root,3.6 if str(entity.get("kind","")) in ["siege","harvester","bulwark"] else 2.8)

## Building wrecks likewise retain the authored building's machinery and
## silhouette, while the known animated pivots receive a role-specific failure
## pose. These are static snapshots after baking and add no runtime animation.
static func apply_building_destruction_pose(root: Node3D, kind: String) -> void:
	_apply_burnt_materials(root)
	root.scale*=Vector3(1.08,0.43,1.08)
	root.rotation.z=0.13
	var failure_pivot: String=""
	match kind:
		"refinery": failure_pivot="UnloadGate"
		"factory": failure_pivot="ProductionCrane"
		"radar": failure_pivot="RadarRotor"
		"power": failure_pivot="ReactorRotor"
		"tower": failure_pivot="TurretPivot"
		"core": failure_pivot="CommandSensorPivot"
		"repair": failure_pivot="RepairArmLeft"
		"armory": failure_pivot="OrdnanceLift"
	if failure_pivot!="":
		var pivot:=root.find_child(failure_pivot,true,false) as Node3D
		if pivot!=null:
			pivot.position.y-=0.28
			pivot.rotation.x+=0.92
			pivot.rotation.z+=0.64
	_add_3d_rubble(root,3.4)

static func _apply_burnt_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance:=node as MeshInstance3D
		if mesh_instance.mesh==null: continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source:=mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source==null: continue
			var charred:=source.duplicate() as BaseMaterial3D
			var glow_part:=mesh_instance.name.begins_with("TeamColor")
			var darkening:=0.56 if glow_part else 0.76
			charred.albedo_color=source.albedo_color.lerp(Color("211d19"),darkening)
			charred.roughness=0.96
			charred.emission_enabled=false
			mesh_instance.set_surface_override_material(surface,charred)

static func _add_3d_rubble(root: Node3D, span: float) -> void:
	for index in 3:
		var shard:=MeshInstance3D.new()
		shard.name="Collapsed 3D armor and structure %d"%index
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(0.62+0.20*float(index%2),0.18+0.05*float(index),1.0-0.14*float(index))
		shard.mesh=mesh
		shard.position=Vector3(-span*0.45+float(index)*span*0.45,0.08,-0.48+0.46*float(index))
		shard.rotation=Vector3(0.16+0.36*float(index),0.35*float(index),-0.68+0.54*float(index))
		var material:=StandardMaterial3D.new()
		material.albedo_color=[Color("292b29"),Color("534639"),Color("79715f")][index]
		material.roughness=0.94
		material.metallic=0.48
		shard.material_override=material
		shard.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shard)
