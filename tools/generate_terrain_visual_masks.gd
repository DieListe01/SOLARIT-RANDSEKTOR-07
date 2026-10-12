extends SceneTree

const WorldRendererScript = preload("res://scripts/world_renderer.gd")

func _initialize() -> void:
	call_deferred("generate")

func generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/terrain_masks"))
	var renderer: Node = WorldRendererScript.new()
	for mission_file in ["veyra.json", "dry_vein.json", "khepri_pass.json"]:
		var mission_path: String = "res://data/"+mission_file
		var catalog := Catalog.new(mission_path)
		var simulation := Simulation.new(catalog)
		renderer.sim=simulation
		var mask: Image=renderer._build_visual_terrain_mask(simulation.grid)
		var destination: String="res://assets/terrain_masks/"+str(catalog.mission.id)+".png"
		var error:=mask.save_png(ProjectSettings.globalize_path(destination))
		if error!=OK:
			push_error("Could not write %s: %s" % [destination,error])
			quit(1)
			return
		print("Generated %s (%dx%d)" % [destination,mask.get_width(),mask.get_height()])
	renderer.free()
	quit(0)
