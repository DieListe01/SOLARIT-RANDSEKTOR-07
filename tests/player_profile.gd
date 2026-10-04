extends SceneTree

const Profile := preload("res://scripts/player_profile.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PLAYER PROFILE: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "user://player_profile_test.json"
	for candidate in [path, path + ".tmp", path + ".previous", "user://profile_corrupt_test.json"]:
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	var profile := Profile.new()
	profile.path = path
	profile.load_profile()
	check(not profile.has_identity(), "A new installation has no identity and can prompt once")
	check(Profile.validate_nickname(" A") == "" and Profile.validate_nickname("AB") == "AB", "Nickname trims outer spaces and requires two characters")
	check(Profile.validate_nickname("  Dïrk_7  ") == "Dïrk_7", "Unicode letters, digits and underscore are accepted")
	check(Profile.validate_nickname("NAME[bb]") == "" and Profile.validate_nickname("Name\\nOther") == "", "Markup and control characters are rejected")
	check(not profile.set_nickname(" ") and profile.set_nickname("DIRK"), "Valid name creates and saves the profile")
	var stable_id := str(profile.data.profile_id)
	profile.record_result({"result_id":"r1","match_report_id":"r1-report","game_version":"0.35","mode":"singleplayer","outcome":"victory","active_seconds":600,"score":184250,"mission_name":"Veyra 03","date":"2026-10-04"})
	profile.record_result({"result_id":"r2","mode":"singleplayer","outcome":"defeat","active_seconds":1200,"score":0})
	profile.record_result({"result_id":"r3","mode":"duel","outcome":"victory","active_seconds":1800})
	profile.record_result({"result_id":"r4","mode":"coop","outcome":"defeat","active_seconds":2400})
	check(not profile.record_result({"result_id":"r1","mode":"singleplayer","outcome":"victory","active_seconds":600,"score":184250}), "An already recorded completed run is ignored")
	profile.data.nickname = "COMMANDER-D"
	check(profile.save_profile(), "Nickname changes save without replacing profile history")
	var reloaded := Profile.new()
	reloaded.path = path
	reloaded.load_profile()
	check(reloaded.has_identity() and str(reloaded.data.profile_id) == stable_id and str(reloaded.data.nickname) == "COMMANDER-D", "Nickname and stable profile ID persist across reload")
	check(int(reloaded.data.statistics.singleplayer.missions) == 2 and int(reloaded.data.statistics.singleplayer.wins) == 1 and int(reloaded.data.statistics.singleplayer.losses) == 1, "Single-player results count only their outcomes")
	check(int(reloaded.data.statistics.duel.wins) == 1 and int(reloaded.data.statistics.coop.losses) == 1, "Duel and coop statistics remain separate")
	check(is_equal_approx(float(reloaded.data.statistics.total_active_seconds), 6000.0), "Active playtime aggregates completed mission time")
	check(int(reloaded.data.statistics.best_score) == 184250 and str(reloaded.data.history[0].nickname) == "DIRK", "Best score and latest-entry nickname are saved")
	check(str(reloaded.data.history[3].match_report_id)=="r1-report" and str(reloaded.data.history[3].game_version)=="0.35","History stores the report link and game version")
	for index in 35:
		reloaded.record_result({"result_id":"cap-%d"%index,"mode":"duel","outcome":"defeat","active_seconds":1})
	check(reloaded.data.history.size() == Profile.HISTORY_LIMIT, "History is capped at the configured limit")
	var corrupt := FileAccess.open("user://profile_corrupt_test.json", FileAccess.WRITE)
	corrupt.store_string("{not json")
	corrupt.close()
	var recovery := Profile.new()
	recovery.path = "user://profile_corrupt_test.json"
	recovery.load_profile()
	check(not recovery.has_identity() and not recovery.load_warning.is_empty(), "Corrupt profile falls back safely with a readable warning")
	for candidate in [path, path + ".tmp", path + ".previous", "user://profile_corrupt_test.json", "user://profile_corrupt_test.json.previous"]:
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	print("PLAYER PROFILE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
