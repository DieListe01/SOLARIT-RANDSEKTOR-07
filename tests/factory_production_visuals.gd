extends SceneTree

const ModelAssets := preload("res://scripts/model_asset_library.gd")
const FACTIONS := ["forge", "drift", "lumen"]
var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	for faction in FACTIONS:
		var model := Node3D.new()
		test_root.add_child(model)
		var path := "res://assets/models/buildings/factory.glb" if faction == "forge" else "res://assets/models/buildings/factions/%s_factory.glb" % faction
		check(ModelAssets.add_optional_glb(model, path, "Factory", Color.WHITE), "%s has its own authored vehicle factory" % faction)
		var factory := model.get_node_or_null("Factory") as Node3D
		var queue: Array = [{"kind": "tank", "paid": 0}]
		var mechanism_values: Array[float] = []
		for frame in 4:
			ModelAssets.apply_building_pose(factory, {"kind": "factory", "queue": queue, "faction": faction, "building_animation_frame": frame, "rotation": 0})
			var moving_name := "Hydraulic deployment ramp" if faction == "forge" else ("Drive-in roller" if faction == "drift" else "Prismatic assembly trolley")
			var moving_part := factory.find_child(moving_name, true, false) as Node3D
			check(moving_part != null, "%s factory has its distinct moving production component" % faction)
			if moving_part != null: mechanism_values.append(moving_part.position.x + moving_part.position.y + moving_part.position.z + moving_part.rotation.x)
		check(mechanism_values.size()==4 and not is_equal_approx(mechanism_values[0],mechanism_values[1]), "%s has visibly distinct authored working poses" % faction)
		var idle_factory := Node3D.new()
		test_root.add_child(idle_factory)
		var idle_scene_path := "res://assets/models/buildings/factory.glb" if faction == "forge" else "res://assets/models/buildings/factions/%s_factory.glb" % faction
		ModelAssets.add_optional_glb(idle_factory,idle_scene_path,"Idle factory",Color.WHITE)
		var idle_model := idle_factory.get_node("Idle factory") as Node3D
		ModelAssets.apply_building_pose(idle_model,{"kind":"factory","queue":[],"faction":faction,"building_animation_frame":0,"rotation":0})
		var idle_part_name := "Hydraulic deployment ramp" if faction=="forge" else ("Drive-in roller" if faction=="drift" else "Prismatic assembly trolley")
		var idle_part := idle_model.find_child(idle_part_name,true,false) as Node3D
		ModelAssets.apply_building_pose(factory,{"kind":"factory","queue":[],"production_exit_unit":1001,"faction":faction,"building_animation_frame":1,"rotation":0})
		var exit_part := factory.find_child(idle_part_name,true,false) as Node3D
		check(idle_part!=null and exit_part!=null and (not idle_part.position.is_equal_approx(exit_part.position) or not idle_part.rotation.is_equal_approx(exit_part.rotation)),"%s factory stays animated while its completed vehicle clears the exit" % faction)
		if faction == "drift":
			var trolley := factory.find_child("Drive-in roller", true, false) as Node3D
			check(trolley != null, "Wanderpakt factory exposes its improvised moving roller")
		if faction == "lumen":
			var slab := factory.find_child("Floating central armor slab", true, false) as Node3D
			check(slab != null, "Prisma factory exposes its floating assembly slab")
		check(ResourceLoader.exists("res://assets/models/vehicles/factions/%s_tank.glb" % faction,"PackedScene") or faction=="forge", "%s production preview uses the matching vehicle model family" % faction)

	test_root.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("FACTORY PRODUCTION VISUALS: %d checks, 0 failures" % checks)
		quit(0)
	else:
		printerr("FACTORY PRODUCTION VISUALS: %d checks, %d failures" % [checks, failures.size()])
		quit(1)
