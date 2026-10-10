extends RefCounted
class_name PlayerProfileService

const PROFILE_PATH := "user://commander_profile.json"
const PROFILE_VERSION := 1
const HISTORY_LIMIT := 30

var path := PROFILE_PATH
var data: Dictionary = {}
var load_warning := ""

func create_default() -> Dictionary:
	return {
		"profile_version": PROFILE_VERSION,
		"profile_id": "",
		"nickname": "",
		"created_at": "",
		"statistics": {
			"total_active_seconds": 0.0,
			"singleplayer": {"missions": 0, "wins": 0, "losses": 0, "active_seconds": 0.0},
			"duel": {"missions": 0, "wins": 0, "losses": 0, "active_seconds": 0.0},
			"coop": {"missions": 0, "wins": 0, "losses": 0, "active_seconds": 0.0},
			"best_score": 0,
			"best_score_mission": "",
			"best_score_date": ""
		},
		"history": [],
		"recorded_results": []
	}

func load_profile() -> void:
	data = create_default()
	load_warning = ""
	if not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	var parse_result := parser.parse(FileAccess.get_file_as_string(path))
	var parsed: Variant = parser.data
	if parse_result != OK or not parsed is Dictionary or int(parsed.get("profile_version", 0)) > PROFILE_VERSION:
		load_warning = "Kommandantenakte konnte nicht gelesen werden."
		return
	var loaded: Dictionary = parsed
	var nickname := validate_nickname(str(loaded.get("nickname", "")))
	if loaded.get("profile_id", "") is String:
		data.profile_id = str(loaded.profile_id).left(64)
	data.nickname = nickname
	data.created_at = str(loaded.get("created_at", "")).left(32)
	var stats: Variant = loaded.get("statistics", {})
	if stats is Dictionary:
		for mode in ["singleplayer", "duel", "coop"]:
			var mode_stats: Variant = stats.get(mode, {})
			if not mode_stats is Dictionary:
				continue
			for key in ["missions", "wins", "losses"]:
				var value: Variant = mode_stats.get(key, 0)
				if is_finite_number(value):
					data.statistics[mode][key] = maxi(0, int(value))
			var seconds: Variant = mode_stats.get("active_seconds", 0.0)
			if is_finite_number(seconds):
				data.statistics[mode].active_seconds = maxf(0.0, float(seconds))
		var total: Variant = stats.get("total_active_seconds", 0.0)
		if is_finite_number(total):
			data.statistics.total_active_seconds = maxf(0.0, float(total))
		var score: Variant = stats.get("best_score", 0)
		if is_finite_number(score):
			data.statistics.best_score = maxi(0, int(score))
		data.statistics.best_score_mission = str(stats.get("best_score_mission", "")).left(120)
		data.statistics.best_score_date = str(stats.get("best_score_date", "")).left(32)
	var history: Variant = loaded.get("history", [])
	if history is Array:
		for entry in history:
			if entry is Dictionary and data.history.size() < HISTORY_LIMIT:
				data.history.append(entry.duplicate(true))
	var recorded: Variant = loaded.get("recorded_results", [])
	if recorded is Array:
		for result_id in recorded:
			if result_id is String and not result_id.is_empty():
				data.recorded_results.append(result_id.left(96))
		data.recorded_results = data.recorded_results.slice(maxi(0, data.recorded_results.size() - HISTORY_LIMIT * 2))

func has_identity() -> bool:
	return not str(data.get("nickname", "")).is_empty() and not str(data.get("profile_id", "")).is_empty()

static func validate_nickname(raw: String) -> String:
	var nickname := raw.strip_edges()
	if nickname.length() < 2 or nickname.length() > 20:
		return ""
	var pattern := RegEx.new()
	if pattern.compile("^[\\p{L}\\p{N} _-]+$") != OK:
		return ""
	return nickname if pattern.search(nickname) != null else ""

static func sanitize_network_nickname(raw: String) -> String:
	var nickname := validate_nickname(raw)
	return nickname if not nickname.is_empty() else "Kommandant"

func set_nickname(raw: String) -> bool:
	var nickname := validate_nickname(raw)
	if nickname.is_empty():
		return false
	if data.is_empty():
		data = create_default()
	data.nickname = nickname
	if str(data.profile_id).is_empty():
		data.profile_id = _new_profile_id()
	if str(data.created_at).is_empty():
		data.created_at = Time.get_datetime_string_from_system(false, true)
	return save_profile()

func save_profile() -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	if FileAccess.file_exists(path):
		var backup_path := path + ".previous"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
			var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path))
			if backup_error != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
				return false
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		var backup_path := path + ".previous"
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path))
		return false
	return true

func record_result(result: Dictionary) -> bool:
	if not has_identity():
		return false
	var result_id := str(result.get("result_id", "")).left(96)
	if result_id.is_empty() or data.recorded_results.has(result_id):
		return false
	var mode := str(result.get("mode", "singleplayer"))
	if mode not in ["singleplayer", "duel", "coop"]:
		return false
	var outcome := str(result.get("outcome", ""))
	if outcome not in ["victory", "defeat"]:
		return false
	var seconds_value: Variant = result.get("active_seconds", 0.0)
	var duration := maxf(0.0, float(seconds_value)) if is_finite_number(seconds_value) else 0.0
	var stats: Dictionary = data.statistics
	var mode_stats: Dictionary = stats[mode]
	mode_stats.missions = int(mode_stats.missions) + 1
	mode_stats.wins = int(mode_stats.wins) + (1 if outcome == "victory" else 0)
	mode_stats.losses = int(mode_stats.losses) + (1 if outcome == "defeat" else 0)
	mode_stats.active_seconds = float(mode_stats.active_seconds) + duration
	stats.total_active_seconds = float(stats.total_active_seconds) + duration
	var score := maxi(0, int(result.get("score", 0)))
	if outcome == "victory" and mode == "singleplayer" and score > int(stats.best_score):
		stats.best_score = score
		stats.best_score_mission = str(result.get("mission_name", "")).left(120)
		stats.best_score_date = str(result.get("date", Time.get_date_string_from_system(false)))
	var history_entry := {
		"result_id": result_id,
		"date": str(result.get("date", Time.get_date_string_from_system(false))),
		"nickname": str(data.nickname),
		"mode": mode,
		"mission": str(result.get("mission_name", result.get("mission", ""))).left(120),
		"outcome": outcome,
		"active_seconds": duration,
		"score": score if outcome == "victory" and mode == "singleplayer" else -1,
		"difficulty": str(result.get("difficulty", "")).left(32),
		"match_report_id": str(result.get("match_report_id", result_id)).left(96),
		"game_version": str(result.get("game_version", "unbekannt")).left(24)
	}
	data.history.push_front(history_entry)
	while data.history.size() > HISTORY_LIMIT:
		data.history.pop_back()
	data.recorded_results.push_back(result_id)
	while data.recorded_results.size() > HISTORY_LIMIT * 2:
		data.recorded_results.pop_front()
	return save_profile()

static func format_duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]

static func is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _new_profile_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%08x-%08x-%08x" % [rng.randi(), rng.randi(), Time.get_ticks_usec() & 0xffffffff, rng.randi()]
