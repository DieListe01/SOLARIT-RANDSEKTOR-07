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
	if node is MeshInstance3D and node.name=="TeamColor":
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
				mesh_instance.set_surface_override_material(surface,team_material)
	for child in node.get_children():
		apply_team_tint(child,team_color)
