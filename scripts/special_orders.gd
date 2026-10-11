extends RefCounted
class_name SpecialOrders

const PROFILE_PATH := "user://special_orders_profile.json"
const TYPES := ["gebiet_sichern", "solarit_foerderung", "stellung_halten", "basis_ausschalten"]
const TYPE_NAMES := {
	"gebiet_sichern": "GEBIET SICHERN",
	"solarit_foerderung": "SOLARIT-FÖRDERUNG",
	"stellung_halten": "STELLUNG HALTEN",
	"basis_ausschalten": "FEINDLICHE BASIS AUSSCHALTEN"
}
const MODIFIERS := [
	{"id":"reiche_ader", "name":"REICHE SOLARITADER", "description":"Solaritfelder enthalten 40 % mehr."},
	{"id":"knapper_start", "name":"KNAPPER START", "description":"Weniger Solarit zu Einsatzbeginn."},
	{"id":"frueher_druck", "name":"FRÜHER FEINDDRUCK", "description":"Die erste Angriffswelle kommt früher."},
	{"id":"verstaerkte_front", "name":"VERSTÄRKTE FRONT", "description":"Der Gegner beginnt mit zusätzlicher Verteidigung."},
	{"id":"weit_entfernte_adern", "name":"WEITE FÖRDERWEGE", "description":"Die ergiebigste Ader liegt weiter vom Baukern entfernt."},
	{"id":"feindreserve", "name":"FEINDRESERVE", "description":"Ein zusätzlicher gegnerischer Späher bewacht die Basis."},
	{"id":"duenne_adern", "name":"DÜNNE ADERN", "description":"Solarit ist knapper, die Startreserve bleibt erhalten."},
	{"id":"alarmnetz", "name":"ALARMNETZ", "description":"Der Gegner produziert und reagiert schneller."}
]
const DOCTRINES := ["AGGRESSOR", "BELAGERER", "JÄGER", "FESTUNGSBAUER", "RAIDER", "EXPANSIONIST"]
const OPTIONALS := [
	{"id":"bonus_solarit", "type":"harvest_amount", "amount":3000, "text":"Liefere zusätzlich 3.000 Solarit.", "hud":"3.000 SOLARIT EXTRA"},
	{"id":"drei_tuerme", "type":"build_structure", "kind":"tower", "count":3, "text":"Errichte drei Geschütztürme.", "hud":"3 GESCHÜTZE BAUEN"},
	{"id":"standhalten", "type":"survive", "seconds":600, "text":"Halte zehn Minuten durch.", "hud":"10 MINUTEN ÜBERLEBEN"},
	{"id":"feindraffinerie", "type":"destroy_target", "owner":1, "kind":"refinery", "text":"Zerstöre die feindliche Raffinerie.", "hud":"RAFFINERIE AUSSCHALTEN"},
	{"id":"sammler_schuetzen", "type":"protect", "owner":0, "kind":"harvester", "text":"Verliere keinen Sammler.", "hud":"SAMMLER SCHÜTZEN"},
	{"id":"zwei_raffinerien", "type":"build_structure", "kind":"refinery", "count":2, "text":"Errichte zwei Raffinerien.", "hud":"2 RAFFINERIEN BAUEN"},
	{"id":"feindspaeher", "type":"destroy_all", "owner":1, "kind":"scout", "text":"Schalte alle feindlichen Späher aus.", "hud":"FEINDSPÄHER AUSSCHALTEN"},
	{"id":"bonus_foerderung", "type":"harvest_amount", "amount":5000, "text":"Berge insgesamt 5.000 Solarit.", "hud":"5.000 SOLARIT BERGEN"}
]

static func weekly_index(unix_time: int) -> int:
	# A globally shared Monday-to-Monday UTC epoch; independent of local timezone.
	return floori(float(unix_time - 345600) / 604800.0)

static func weekly_seed(index: int) -> int:
	var mixed: int = (index * 1103515245 + 12345) & 0x7fffffff
	return 100000 + (mixed % 900000)

static func generate(base_mission: Dictionary, seed_value: int, mission_type: String, player_faction: String, level: String, official: bool = false, weekly_number: int = 0) -> Dictionary:
	if mission_type not in TYPES: mission_type = TYPES[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, seed_value)
	var mission: Dictionary = base_mission.duplicate(true)
	var order_id := ("week_%d" % weekly_number) if official else ("seed_%d" % seed_value)
	var doctrine: String = DOCTRINES[rng.randi_range(0, DOCTRINES.size() - 1)]
	mission.id = "special_" + order_id
	mission.seed = seed_value
	mission.name = TYPE_NAMES[mission_type]
	mission.display_name = mission.name
	mission.short_name = mission.name
	mission.briefing = "Spezialauftrag · Seed %d · Doktrin %s. Die Kampagne bleibt davon unberührt." % [seed_value, doctrine]
	mission.briefing_hint = "SEED %d  ·  %s" % [seed_value, TYPE_NAMES[mission_type]]
	mission.hud_hint = "SPEZIALAUFTRAG / %s\nSEED %d  ·  DOKTRIN %s" % [TYPE_NAMES[mission_type], seed_value, doctrine]
	mission.start_message = "Spezialauftrag begonnen · Seed %d" % seed_value
	mission.victory_title = "Spezialauftrag erfüllt"
	mission.defeat_title = "Spezialauftrag gescheitert"
	mission.ai_enabled = true
	if not mission.has("waves"): mission["waves"] = []
	var modifier_ids: Array[String] = []
	var available := MODIFIERS.duplicate(true)
	for _pick in 2:
		var selected_index := rng.randi_range(0, available.size() - 1)
		modifier_ids.append(str(available[selected_index].id))
		available.remove_at(selected_index)
	var selected_optionals: Array[Dictionary] = []
	var optional_pool := OPTIONALS.duplicate(true)
	for pick_index in 2:
		var objective_index := rng.randi_range(0, optional_pool.size() - 1)
		var objective: Dictionary = optional_pool[objective_index].duplicate(true)
		objective.optional = true
		selected_optionals.append(objective)
		optional_pool.remove_at(objective_index)
	for resource_index in mission.resources.size():
		var resource: Dictionary = mission.resources[resource_index]
		var cell: Array = resource.cell.duplicate()
		cell[0] = clampi(int(cell[0]) + rng.randi_range(-7, 7), 3, int(mission.width) - 4)
		cell[1] = clampi(int(cell[1]) + rng.randi_range(-7, 7), 3, int(mission.height) - 4)
		resource.cell = cell
		resource.amount = int(resource.amount * rng.randf_range(0.72, 1.28))
		mission.resources[resource_index] = resource
	mission.units.append({"kind":"harvester", "owner":0, "cell":[14,43]})
	var objectives: Array[Dictionary] = []
	objectives.append({"id":"hold_core", "type":"protect", "owner":0, "kind":"core", "text":"Erhalte deinen Baukern."})
	match mission_type:
		"gebiet_sichern":
			objectives.append({"id":"enemy_base_clear", "type":"destroy_target", "owner":1, "kind":"core", "primary":true, "text":"Schalte den feindlichen Baukern aus."})
			var zone_cell := [rng.randi_range(27, 38), rng.randi_range(22, 39)]
			objectives.append({"id":"control_zone", "type":"control_zone", "cell":zone_cell, "radius":150, "seconds":35, "primary":true, "text":"Kontrolliere die markierte Zone für 35 Sekunden.", "hud":"ZONE SICHERN"})
		"solarit_foerderung":
			objectives.append({"id":"secure_refineries", "type":"destroy_target", "owner":1, "kind":"refinery", "primary":true, "text":"Schalte die feindliche Raffinerie aus."})
			objectives.append({"id":"harvest_goal", "type":"harvest_amount", "amount":3500, "primary":true, "text":"Berge 3.500 Solarit.", "hud":"3.500 SOLARIT BERGEN"})
		"stellung_halten":
			objectives.append({"id":"hold_position", "type":"survive", "seconds":720, "primary":true, "text":"Halte deine Stellung für zwölf Minuten.", "hud":"STELLUNG HALTEN"})
			mission.waves = [
				{"time":150, "spawn_cell":[58,8], "units":["scout","raider","raider"], "message":"FEINDLICHER VORSTOSS"},
				{"time":360, "spawn_cell":[58,8], "units":["tank","scout","raider"], "message":"ZWEITE ANGRIFFSWELLE"},
				{"time":570, "spawn_cell":[58,8], "units":["tank","tank","siege"], "message":"SCHWERE FEINDKRÄFTE"}
			]
		"basis_ausschalten":
			objectives.append({"id":"destroy_enemy_core", "type":"destroy_target", "owner":1, "kind":"core", "primary":true, "text":"Zerstöre den feindlichen Baukern."})
	for optional_objective in selected_optionals: objectives.append(optional_objective)
	mission.objectives = objectives
	var modifier_labels: Array[String] = []
	for modifier_id in modifier_ids:
		var modifier: Dictionary = modifier_by_id(modifier_id)
		modifier_labels.append(str(modifier.name))
		match modifier_id:
			"reiche_ader":
				for resource in mission.resources: resource.amount = int(resource.amount * 1.4)
			"knapper_start": mission.credits[0] = maxi(1800, int(mission.credits[0]) - 900)
			"frueher_druck":
				mission.rules_overrides.normal.attack_grace = 135
				mission.waves.append({"time":105, "spawn_cell":[58,8], "units":["scout","raider"], "message":"FRÜHER FEINDKONTAKT"})
			"verstaerkte_front": mission.structures.append({"kind":"tower", "owner":1, "cell":[47,18]})
			"weit_entfernte_adern":
				var far_resource: Dictionary = mission.resources[0]
				far_resource.cell = [clampi(int(far_resource.cell[0]) + 12, 4, 59), clampi(int(far_resource.cell[1]) - 12, 4, 59)]
				mission.resources[0] = far_resource
			"feindreserve": mission.units.append({"kind":"scout", "owner":1, "cell":[46,25]})
			"duenne_adern":
				for resource in mission.resources: resource.amount = int(resource.amount * 0.68)
			"alarmnetz": mission.rules_overrides.normal.ai_production_interval = 16
	mission["enemy_doctrine"] = doctrine
	match doctrine:
		"AGGRESSOR":
			mission.rules_overrides.normal.attack_grace = mini(int(mission.rules_overrides.normal.get("attack_grace", 210)), 135)
			mission.waves.append({"time":120, "spawn_cell":[58,8], "units":["raider","raider","scout"], "message":"DOKTRIN AGGRESSOR · FRÜHER ANGRIFF"})
		"BELAGERER":
			mission.waves.append({"time":300, "spawn_cell":[58,8], "units":["siege","tank"], "message":"DOKTRIN BELAGERER · ARTILLERIE"})
		"JÄGER":
			mission.waves.append({"time":210, "spawn_cell":[58,8], "target_cell":[14,43], "units":["scout","raider"], "message":"DOKTRIN JÄGER · SAMMLER IM VISIER"})
		"FESTUNGSBAUER":
			mission.structures.append({"kind":"tower", "owner":1, "cell":[45,16]})
			mission.structures.append({"kind":"tower", "owner":1, "cell":[55,19]})
		"RAIDER":
			mission.waves.append({"time":135, "spawn_cell":[58,8], "units":["raider","raider","raider"], "message":"DOKTRIN RAIDER · ÜBERFALL"})
		"EXPANSIONIST":
			mission.structures.append({"kind":"power", "owner":1, "cell":[56,14]})
			mission.structures.append({"kind":"refinery", "owner":1, "cell":[43,26]})
	return {
		"format_version":1, "id":order_id, "seed":seed_value, "type":mission_type,
		"type_name":TYPE_NAMES[mission_type], "official":official, "weekly_number":weekly_number,
		"player_faction":player_faction, "difficulty":level, "enemy_doctrine":doctrine,
		"modifier_ids":modifier_ids, "modifiers":modifier_labels,
		"optional_objectives":selected_optionals, "mission":mission,
		"risk_level":0, "score":0
	}

static func modifier_by_id(identifier: String) -> Dictionary:
	for item in MODIFIERS:
		if str(item.id) == identifier: return item
	return {}

static func score_run(order: Dictionary, sim: Simulation) -> Dictionary:
	var optional_done := 0
	for objective in order.get("mission", {}).get("objectives", []):
		if bool(objective.get("optional", false)) and sim.objective_latched(objective): optional_done += 1
	var raw_score := 10000 + optional_done * 2500
	raw_score += mini(5000, int(sim.stats.gathered / 4.0))
	raw_score += maxi(0, 2400 - int(sim.time * 2.0))
	raw_score -= int(sim.stats.lost) * 180
	raw_score -= int(sim.stats.buildings_lost) * 350
	raw_score += int(order.get("risk_level", 0)) * 1800
	var score := maxi(0, raw_score)
	var medal := "BRONZE" if score < 14500 else ("SILBER" if score < 19000 else ("GOLD" if score < 24500 else "PLATIN"))
	return {"score":score,"medal":medal,"optional_done":optional_done,"optional_total":order.get("optional_objectives",[]).size()}

static func weekly_order(base_mission: Dictionary, unix_time: int, player_faction: String, level: String) -> Dictionary:
	var index := weekly_index(unix_time)
	var seed_value := weekly_seed(index)
	var mission_type: String = TYPES[posmod(index, TYPES.size())]
	var order := generate(base_mission, seed_value, mission_type, player_faction, level, true, index)
	order.id = "week_%d" % index
	order.type_name = "WOCHENAUFTRAG · " + str(order.type_name)
	order["mission"].display_name = order.type_name
	order["mission"].name = order.type_name
	return order

static func profile_default() -> Dictionary:
	return {"format_version":1,"completed":0,"wins":0,"gold_plus":0,"best_streak":0,"current_streak":0,"solarite":0,"history":[],"leaderboards":{}}

static func load_profile(path: String = PROFILE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return profile_default()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("format_version", 0)) != 1: return profile_default()
	var result := profile_default()
	for key in ["completed", "wins", "gold_plus", "best_streak", "current_streak", "solarite"]: result[key] = maxi(0, int(parsed.get(key, 0)))
	if parsed.get("history", []) is Array: result.history = parsed.history.duplicate(true).slice(0, 50)
	if parsed.get("leaderboards", {}) is Dictionary: result.leaderboards = parsed.leaderboards.duplicate(true)
	return result

static func save_profile(profile: Dictionary, path: String = PROFILE_PATH) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(profile, "  ")); file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := ProjectSettings.globalize_path(path + ".tmp")
	if FileAccess.file_exists(path):
		var backup_path := ProjectSettings.globalize_path(path + ".previous")
		if FileAccess.file_exists(path + ".previous"):
			DirAccess.remove_absolute(backup_path)
			if DirAccess.rename_absolute(absolute_path, backup_path) != OK:
				DirAccess.remove_absolute(temporary_path)
				return false
		elif DirAccess.rename_absolute(absolute_path, backup_path) != OK:
			DirAccess.remove_absolute(temporary_path)
			return false
	var rename_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if rename_error != OK:
		var backup_path := ProjectSettings.globalize_path(path + ".previous")
		if FileAccess.file_exists(path + ".previous"): DirAccess.rename_absolute(backup_path, absolute_path)
		return false
	return true

static func record_result(profile: Dictionary, order: Dictionary, result: Dictionary, path: String = PROFILE_PATH) -> bool:
	var bucket := "weekly" if bool(order.get("official", false)) else ("seed_%d" % int(order.get("seed", 0)))
	var entry := {"id":str(order.get("id", "")),"seed":int(order.get("seed", 0)),"type":str(order.get("type_name", order.get("type", ""))),"date":Time.get_datetime_string_from_system(true, true),"outcome":str(result.get("outcome", "defeat")),"score":int(result.get("score", 0)),"medal":str(result.get("medal", "")),"difficulty":str(order.get("difficulty", "normal")),"faction":str(order.get("player_faction", "forge")),"solarite":int(result.get("solarite", 0)),"risk_level":int(order.get("risk_level", 0))}
	profile.completed = int(profile.get("completed", 0)) + 1
	profile.solarite = int(profile.get("solarite", 0)) + int(entry.solarite)
	if entry.outcome == "victory":
		profile.wins = int(profile.get("wins", 0)) + 1
		profile.current_streak = int(profile.get("current_streak", 0)) + 1
		profile.best_streak = maxi(int(profile.get("best_streak", 0)), int(profile.current_streak))
		if entry.medal in ["GOLD", "PLATIN"]: profile.gold_plus = int(profile.get("gold_plus", 0)) + 1
	else: profile.current_streak = 0
	var history: Array = profile.get("history", []).duplicate(true)
	history.push_front(entry)
	profile.history = history.slice(0, 50)
	var boards: Dictionary = profile.get("leaderboards", {}).duplicate(true)
	var entries: Array = boards.get(bucket, []).duplicate(true)
	entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	boards[bucket] = entries.slice(0, 25)
	profile.leaderboards = boards
	return save_profile(profile, path)
