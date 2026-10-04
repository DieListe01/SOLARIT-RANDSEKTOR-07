extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("HIGHSCORE: "+message)

func _initialize() -> void:
	call_deferred("run")

func win_with_stats(game: Control, run_stats: Dictionary, elapsed: float) -> void:
	game.start_game()
	game.sim.stats.merge(run_stats,true)
	game.sim.time=elapsed
	game.sim.result="victory"
	game.ended=true
	game.show_end()

func run() -> void:
	var mission_files:=DirAccess.get_files_at("res://data")
	var missions: Array[String]=[]
	for path in mission_files:
		if path.ends_with(".json") and path not in ["catalog.json","update_history.json"]: missions.append(path)
	check(missions.size()==3 and ["veyra.json","dry_vein.json","khepri_pass.json"].all(func(name_value):return missions.has(name_value)),"All three playable campaign missions are present")
	var game: Control=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.commander_profile.path = "user://highscore_profile_test.json"
	game.commander_profile.load_profile()
	game.commander_profile.set_nickname("DIRK")
	game.skip_intro(); game.set_classic(false)
	game.campaign_progress_path="user://highscore_campaign_test.json"
	game.campaign_progress={"format_version":1,"unlocked_mission":0,"tech_level":0,"completed":[]}
	game.highscore_path="user://highscore_test.json"
	if FileAccess.file_exists(game.highscore_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(game.highscore_path))
	win_with_stats(game,{"gathered":1000.0,"kills":4,"produced":2,"built":3,"lost":1,"buildings_lost":1},100.0)
	check(game.campaign_progress.unlocked_mission==1 and game.campaign_progress.tech_level==1,"Mission victory unlocks the next campaign step and armory tier")
	var first: Dictionary=game.load_highscores()
	check(first.entries.size()==1 and int(first.entries[0].score)==5740 and str(first.entries[0].nickname)=="DIRK" and str(first.entries[0].profile_id)==str(game.commander_profile.data.profile_id),"Victory stores the score, nickname and stable profile ID")
	check(int(game.commander_profile.data.statistics.singleplayer.missions)==1 and int(game.commander_profile.data.statistics.singleplayer.wins)==1 and int(game.commander_profile.data.statistics.best_score)==5740,"The same result updates the commander file and personal record")
	var end_panel: Control=game.overlay.get_child(0)
	var score_text: String=""
	for child in end_panel.get_children():
		if child is Label and child.text.contains("PLATZ 1 / 10"): score_text=child.text
	check(not score_text.is_empty() and score_text.contains("NEUER BESTWERT"),"Victory screen shows score, rank and personal record")
	game.commander_profile.set_nickname("COMMANDER-D")
	var completed_id: String=game.run_id
	game.show_end()
	check(game.load_highscores().entries.size()==1 and game.load_highscores().completed_runs.has(completed_id),"Reopening a debrief does not duplicate the same run")
	win_with_stats(game,{"gathered":0.0,"kills":1,"produced":0,"built":0,"lost":0,"buildings_lost":0},2500.0)
	var sorted: Array=game.load_highscores().entries
	check(sorted.size()==2 and int(sorted[0].score)>int(sorted[1].score),"Personal mission leaderboard is sorted by score")
	check(str(sorted[0].nickname)=="DIRK" and str(sorted[1].nickname)=="COMMANDER-D", "Renaming a commander preserves historical highscore names")
	game.show_highscores()
	var highscores_panel: Control=game.overlay.get_child(0)
	var list_text: String=""
	for child in highscores_panel.get_children():
		if child is Label: list_text+=child.text
	check(list_text.contains("Einsatzrekorde") and list_text.contains("5.740") and list_text.contains("1.250") and list_text.contains("DIRK"),"Full leaderboard shows saved scores and commander names")
	game.show_main_menu()
	check(game.menu_buttons.has("highscores"),"Main menu exposes the leaderboard")
	var count_before: int=game.load_highscores().entries.size()
	game.start_game(); game.sim.result="defeat"; game.ended=true; game.show_end()
	check(game.load_highscores().entries.size()==count_before,"Defeat does not add a highscore")
	check(int(game.commander_profile.data.statistics.singleplayer.losses) == 1, "A completed campaign defeat is counted in the commander file")
	game.music.shutdown(); game.queue_free()
	await process_frame
	if FileAccess.file_exists("user://highscore_test.json"): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://highscore_test.json"))
	for path in ["user://highscore_campaign_test.json","user://highscore_campaign_test.json.tmp","user://highscore_profile_test.json","user://highscore_profile_test.json.tmp","user://highscore_profile_test.json.previous"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HIGHSCORE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
