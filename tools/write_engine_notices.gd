extends SceneTree
func _initialize() -> void:
	var file := FileAccess.open("res://build/GODOT-LICENSES.txt",FileAccess.WRITE)
	file.store_string("Godot Engine 4.7.2 stable\n\n"+Engine.get_license_text()+"\n\n")
	file.store_string("EMBEDDED THIRD-PARTY COPYRIGHT NOTICES\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n")
	file.store_string("THIRD-PARTY LICENSE TEXTS\n\n"+JSON.stringify(Engine.get_license_info(),"  ")+"\n")
	file.close()
	quit()
