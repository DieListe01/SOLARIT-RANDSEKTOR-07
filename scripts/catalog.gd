extends RefCounted
class_name Catalog

var units: Dictionary
var buildings: Dictionary
var weapons: Dictionary
var factions: Dictionary
var rules: Dictionary
var mission: Dictionary
var mission_path := "res://data/veyra.json"
var errors: Array[String] = []

func _init(path: String = "res://data/veyra.json") -> void:
	var data = read_json("res://data/catalog.json")
	units = data.get("units", {})
	buildings = data.get("buildings", {})
	weapons = data.get("weapons", {})
	factions = data.get("factions", {})
	rules = data.get("rules", {})
	mission_path = path
	mission = read_json(path)
	for table in [units, buildings]:
		for id in table:
			var d: Dictionary = table[id]
			if d.has("weapon") and not weapons.has(d.weapon):
				errors.append("Unbekannte Waffe: " + id)
			for pre in d.get("requires", []):
				if not buildings.has(pre): errors.append("Unbekannte Voraussetzung: " + str(pre))
			if d.has("footprint") and (d.footprint[0] < 1 or d.footprint[1] < 1):
				errors.append("Ungültiger Grundriss: " + id)
	if mission.get("format_version", 0) != 1: errors.append("Ungültiges Kartenformat")
	var objective_types := ["destroy_target", "destroy_all", "protect", "survive", "harvest_amount", "build_structure"]
	for objective in mission.get("objectives", []):
		if objective.get("type","") not in objective_types: errors.append("Unbekanntes Missionsziel: "+str(objective.get("type","")))
		if not objective.has("id") or not objective.has("text"): errors.append("Missionsziel ohne ID oder Text")
	for wave in mission.get("waves", []):
		if not wave.has("time") or not wave.has("spawn_cell"): errors.append("Ungültige Missionswelle")
	for error in errors: push_error(error)

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Fehlende Datei: " + path)
		return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON-Fehler in %s, Zeile %s: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	return parser.data
