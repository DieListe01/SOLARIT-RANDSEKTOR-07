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
	if node is MeshInstance3D and (node.name=="TeamColor" or node.name.begins_with("TeamColor luminous column")):
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
