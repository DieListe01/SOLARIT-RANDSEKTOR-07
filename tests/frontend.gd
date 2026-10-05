extends SceneTree
var game: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error("FRONTEND FAIL: "+message)

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new(); event.keycode=code; event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.commander_profile.path = "user://frontend_commander_profile.json"
	game.commander_profile.load_profile()
	check(game.intro_active and not game.playing,"Startup enters cinematic intro")
	check(game.sim==null,"Intro never instantiates gameplay simulation")
	check(game.music.frontend and game.music.frontend_player.playing,"Own title score starts on first launch")
	check(absf(game.music.frontend_player.stream.get_length()-24)<0.1,"Full 24-second title theme")
	game.intro_art.elapsed=4.7
	await capture("intro_planet")
	game.intro_art.elapsed=8.8
	await capture("intro_landing")
	game.intro_art.elapsed=13.0
	await capture("intro_title")
	await key(KEY_ESCAPE)
	check(not game.intro_active and game.menu_buttons.has("start"),"Escape skips intro into functional menu")
	check(game.overlay.get_node_or_null("CommanderProfileDialog") != null, "First launch requires a commander profile before regular play")
	check(game.ui.get_node("MenuCommanderNickname").text == "NICHT IDENTIFIZIERT" and game.menu_buttons.commander.text == "IDENTIFIKATION STARTEN", "Menu shows the unidentified profile and identification link")
	var profile_name: LineEdit = game.overlay.get_node("CommanderProfileDialog/CommanderNickname")
	profile_name.text = "DIRK"
	profile_name.text_changed.emit("DIRK")
	game.overlay.get_node("CommanderProfileDialog").find_children("*", "Button", true, false).filter(func(item): return item is Button and item.text == "BESTÄTIGEN")[0].pressed.emit()
	check(game.commander_profile.has_identity() and game.overlay.get_node_or_null("CommanderProfileDialog") == null, "First-run identity saves and unlocks the main menu")
	check(game.ui.get_node("MenuCommanderNickname").text == "DIRK" and game.menu_buttons.commander.text == "SPIELER WECHSELN", "Menu immediately displays the saved commander")
	var stable_profile_id: String = str(game.commander_profile.data.profile_id)
	game.menu_buttons.commander.pressed.emit()
	check(game.overlay.get_node("CommanderProfileDialog/CommanderNickname").text == "DIRK", "System link opens the existing identity mask with the active nickname")
	game.overlay.get_node("CommanderProfileDialog").find_children("*", "Button", true, false).filter(func(item): return item.text == "ABBRECHEN")[0].pressed.emit()
	check(game.ui.get_node("MenuCommanderNickname").text == "DIRK" and game.overlay.get_child_count() == 0, "Cancelling a profile switch returns to the unchanged menu")
	game.menu_buttons.commander.pressed.emit()
	profile_name = game.overlay.get_node("CommanderProfileDialog/CommanderNickname")
	profile_name.text = "COMMANDER-D"
	profile_name.text_changed.emit(profile_name.text)
	game.overlay.get_node("CommanderProfileDialog").find_children("*", "Button", true, false).filter(func(item): return item.text == "BESTÄTIGEN")[0].pressed.emit()
	check(game.ui.get_node("MenuCommanderNickname").text == "COMMANDER-D" and game.overlay.get_child_count() == 0, "Profile switch updates the menu immediately after confirmation")
	var reloaded = load("res://scripts/player_profile.gd").new()
	reloaded.path = game.commander_profile.path
	reloaded.load_profile()
	check(reloaded.data.nickname == "COMMANDER-D" and reloaded.data.profile_id == stable_profile_id, "The renamed profile persists with the same commander file ID")
	game.commander_profile.set_nickname("WWWWWWWWWWWWWWWWWWWW")
	game.show_main_menu()
	await process_frame
	var menu_name: Label = game.ui.get_node("MenuCommanderNickname")
	check(menu_name.position.x >= 1660 and menu_name.get_rect().end.x <= 1890 and menu_name.get_rect().end.y <= game.menu_buttons.commander.position.y, "Maximum-width nickname stays beside the planet and above the system link")
	game.commander_profile.set_nickname("DIRK")
	game.show_main_menu()
	game.show_commander_file(game.show_main_menu)
	check(game.overlay.get_node_or_null("CommanderDossier") != null and game.commander_profile.data.statistics.best_score == 0, "Commander dossier opens with empty, real statistics")
	check(game.overlay.get_node("CommanderDossier").find_children("*", "ScrollContainer", true, false).size() == 1, "Dossier history remains in a bounded, scrollable region")
	game.show_main_menu()
	await create_timer(0.8).timeout
	await capture("menu_new")
	check(game.music.frontend_player.playing,"Menu continues the intro soundtrack")
	game.menu_buttons.multiplayer.pressed.emit()
	check(game.overlay.get_node_or_null("OnlineLobbyPanel")!=null,"Multiplayer opens the lobby directly from the main menu")
	game.show_main_menu()
	game.show_intro()
	await key(KEY_ENTER)
	check(not game.intro_active,"Intro can be replayed and skipped by Enter")
	game.show_intro()
	game.intro_art.elapsed=14.99
	await create_timer(0.15).timeout
	check(not game.intro_active,"Intro naturally completes at its end")
	game.show_intro()
	game.set_classic(true)
	game.intro_art.elapsed=13
	await capture("intro_classic")
	await key(KEY_SPACE)
	check(not game.intro_active,"Space skips in Classic Retro")
	await create_timer(0.8).timeout
	await capture("menu_classic_new")
	check(root.content_scale_size==Vector2i(640,360),"Menu retains real low-resolution rendering")
	game.set_classic(false)
	game.menu_buttons.options.pressed.emit()
	check(game.overlay.get_child_count()>0,"Options reachable from new menu")
	game.show_options(game.show_main_menu, "PROFIL")
	check(game.overlay.get_node("OptionsPanel").find_children("*", "Label", true, false).any(func(item): return item is Label and item.text == "KOMMANDANTENAKTE"), "Profile has a dedicated options tab")
	game.show_main_menu()
	game.campaign_progress.unlocked_mission=0
	game.show_main_menu()
	game.menu_buttons.start.pressed.emit()
	check(game.overlay.get_child_count()==0 and game.ui.get_children().any(func(child):return child is Panel and child.size.x>=1200),"Mission briefing opens as a separate preparation screen")
	await process_frame
	var briefing_panel: Control
	for child in game.ui.get_children():
		if child is Panel and child.size.x>=1200: briefing_panel=child; break
	check(briefing_panel!=null,"Large, independent preparation panel exists")
	var tactical_preview: Control=briefing_panel.find_child("MissionTacticalPreview",true,false)
	check(tactical_preview!=null and tactical_preview.mission_data.get("resources",[]).size()>0 and tactical_preview.mission_data.get("terrain_regions",[]).size()>0,"Mission briefing previews authored terrain and resource locations")
	check(briefing_panel.find_children("*","Button",true,false).any(func(item):return item is Button and item.text.contains("SIGNAL GESPERRT") and item.tooltip_text.contains("vorherigen Einsatz")),"Locked campaign missions explain their unlock condition")
	check(briefing_panel.find_children("*","Label",true,false).any(func(item):return item is Label and item.text=="SCHWIERIGKEIT"),"Resistance selection is clearly labeled as difficulty")
	check(briefing_panel.find_children("*","Label",true,false).any(func(item):return item is Label and item.text=="BEDROHUNG"),"Difficulty includes a quick threat indicator")
	for child in briefing_panel.get_children():
		if child is Label and child.autowrap_mode!=TextServer.AUTOWRAP_OFF:
			check(child.position.x+child.size.x<=briefing_panel.size.x,"Wrapped briefing text stays inside panel")
			check(child.size.y>=child.get_theme_font_size("font_size"),"Wrapped text has visible height")
	await capture("briefing_detailed")
	game.start_game()
	check(game.playing and not game.music.frontend and not game.music.frontend_player.playing,"Mission replaces frontend soundtrack")
	game.show_main_menu()
	check(game.music.frontend and game.music.frontend_player.playing,"Returning from mission restores menu score")
	game.show_credits()
	check(not game.music.frontend and game.music.layers[0].playing,"Layer sound test works after menu soundtrack")
	game.show_main_menu()
	check(game.music.frontend,"Leaving sound test restores menu score")
	game.music.music_volume=0
	game.music._process(10)
	check(game.music.frontend_player.volume_db<-55,"Menu music obeys volume setting")
	game.music.music_volume=0.65
	game.persist_settings()
	game.music.shutdown(); game.queue_free()
	for profile_path in ["user://frontend_commander_profile.json", "user://frontend_commander_profile.json.previous", "user://frontend_commander_profile.json.tmp"]:
		if FileAccess.file_exists(profile_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	await process_frame
	await create_timer(0.15).timeout
	print("FRONTEND: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
