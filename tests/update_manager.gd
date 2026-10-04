extends SceneTree

const Manager = preload("res://scripts/update_manager.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error("UPDATE MANAGER: "+message)

func _initialize() -> void:
	check(Manager.repository_is_valid("DieListe01/SOLARIT-RANDSEKTOR-07-Releases"),"public binary feed repository accepted")
	check(not Manager.repository_is_valid("https://github.com/DieListe01/SOLARIT-RANDSEKTOR-07"),"full URL rejected as repository identifier")
	check(not Manager.repository_is_valid("DieListe01/../other"),"path traversal rejected")
	check(not Manager.repository_is_valid("../SOLARIT: RANDSEKTOR 07"),"dot path segment rejected")
	check(Manager.normalize_version("v0.35")=="0.35","release tag prefix normalized")
	check(Manager.is_newer_version("0.35","0.34"),"newer minor release recognized")
	check(Manager.is_newer_version("1.0","0.99"),"numeric versions compare by components")
	check(not Manager.is_newer_version("0.34","0.35"),"older release ignored")
	check(not Manager.is_newer_version("0.35-beta","0.34"),"non-numeric release rejected")
	check(Manager.is_sha256("0123456789abcdef".repeat(4)),"SHA-256 format accepted")
	check(not Manager.is_sha256("bad-hash"),"invalid SHA-256 rejected")
	print("UPDATE MANAGER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
