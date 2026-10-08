extends SceneTree
var game: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	OS.set_environment("SOLARIT_DISABLE_ONLINE_STATS", "1")
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
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920,1080)
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
	var profile_dialog: Control = game.overlay.get_node("CommanderProfileDialog")
	var profile_notice: Label = profile_dialog.get_node("CommanderProfileNotice")
	var profile_validation: Label = profile_dialog.get_node("CommanderProfileValidation")
	var profile_confirm: Button = profile_dialog.get_node("ConfirmCommanderProfile")
	check(profile_notice.get_rect().end.y + 8 <= profile_validation.position.y, "Profile privacy note does not overlap validation feedback")
	check(profile_validation.get_rect().end.y + 8 <= profile_confirm.position.y, "Profile validation feedback clears the confirmation button (%s / %s)" % [profile_validation.get_rect(), profile_confirm.get_rect()])
	await capture("profile_dialog_layout")
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
	game.online_directory = load("res://scripts/online_directory.gd").new()
	game.online_directory.enabled = false
	game.online_directory.client_id = "frontend-test-client"
	game.add_child(game.online_directory)
	game.online_directory.lobbies_received.connect(game._on_online_lobbies_received)
	game.online_directory.status_changed.connect(game._on_online_directory_status)
	game.menu_buttons.multiplayer.pressed.emit()
	game._on_online_lobbies_received([], "")
	check(game.overlay.get_node_or_null("OnlineLobbyPanel")!=null,"Multiplayer opens the lobby directly from the main menu")
	var online_panel: Control = game.overlay.get_node("OnlineLobbyPanel")
	var lobby_panel_style := online_panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(lobby_panel_style != null and lobby_panel_style.bg_color.a >= 0.99,"Multiplayer dialog background is opaque so the menu cannot show through")
	check(online_panel.get_node_or_null("PublishPublicLobby") is CheckBox and not (online_panel.get_node("PublishPublicLobby") as CheckBox).button_pressed,"Public lobby listing requires an explicit opt-in")
	var publish_toggle: CheckBox = online_panel.get_node("PublishPublicLobby")
	var publish_hint: Label = online_panel.get_node("PublicLobbyHint")
	check(not publish_toggle.get_rect().intersects(publish_hint.get_rect()),"Public lobby explanation sits below its checkbox without overlapping")
	check(online_panel.get_node_or_null("OnlineDirectoryList") is ItemList and online_panel.get_node_or_null("OnlineAddress") is LineEdit,"Lobby browser and manual direct-connect remain available")
	check(online_panel.get_node_or_null("LocalAddressCopy") is Button and online_panel.get_node_or_null("PublicAddressCopy") is Button and online_panel.get_node_or_null("RefreshPublicAddress") is Button,"Lobby shows copy controls for local and external IP addresses")
	game._on_online_public_address_received("79.240.71.178",true)
	var external_ip_button: Button = online_panel.get_node("PublicAddressCopy")
	check(not external_ip_button.disabled and external_ip_button.text.contains("79.240.71.178"),"Successful external-IP lookup updates its copy control")
	var join_address: LineEdit = online_panel.get_node("OnlineAddress")
	check(join_address.text.is_empty() and (online_panel.get_node("JoinOnlineClient") as Button).disabled,"Direct join starts empty instead of suggesting localhost")
	check(join_address.placeholder_text.contains("Einladungscode"),"Join field explains private invite-code entry")
	var host_button: Button = online_panel.get_node("CreateOnlineHost")
	var client_button: Button = online_panel.get_node("JoinOnlineClient")
	var refresh_button: Button = online_panel.get_node("RefreshPublicLobbies")
	var public_list: ItemList = online_panel.get_node("OnlineDirectoryList")
	var public_join_button: Button = online_panel.get_node("JoinPublicLobby")
	check(not client_button.get_rect().intersects(refresh_button.get_rect()), "Lobby refresh button clears the manual join action")
	check(not host_button.get_rect().intersects(refresh_button.get_rect()), "Lobby refresh button clears the host action")
	check(not refresh_button.get_rect().intersects(public_list.get_rect()), "Lobby refresh button clears the public lobby list")
	check(not public_list.get_rect().intersects(public_join_button.get_rect()), "Public lobby list clears the selected-lobby action")
	check(not online_panel.get_node("LocalAddressCopy").get_rect().intersects(join_address.get_rect()) and not online_panel.get_node("PublicAddressCopy").get_rect().intersects(join_address.get_rect()),"IP copy controls have their own row above the direct-join address")
	check(online_panel.get_global_rect().end.y <= game.get_viewport_rect().size.y + 1,"Expanded multiplayer panel scales to fit the active screen (%s / %s)" % [online_panel.get_global_rect(), game.get_viewport_rect().size])
	var empty_state: Label = online_panel.get_node("OnlineDirectoryEmptyState")
	check(empty_state.visible and empty_state.text.contains("Keine offene Lobby gefunden") and public_list.item_count == 0,"Empty lobby directory explains how to create a public lobby")
	game._on_online_lobbies_received([{"lobby_id":"test-lobby", "nickname":"TESTHOST", "mode":"versus", "mission_name":"Das Veyra-Becken", "game_version":str(game.update_history.current_version), "address":"203.0.113.8", "port":2456, "expires_in":75}], "")
	online_panel = game.overlay.get_node("OnlineLobbyPanel")
	public_list = online_panel.get_node("OnlineDirectoryList")
	check(public_list.visible and public_list.item_count == 1 and public_list.get_item_text(0).contains("TESTHOST") and public_list.get_item_text(0).contains("läuft in"),"Public lobby row shows host details and remaining lifetime (%s)" % public_list.get_item_text(0))
	check(public_list.get_item_text(0).contains("HOST v%s" % str(game.update_history.current_version)) and not public_list.is_item_disabled(0),"Public lobby shows the host version and allows an exact version match")
	check(online_panel.get_node("OnlineDirectoryStatus").text.contains("letzte Suche"),"Lobby directory shows when its results were refreshed")
	game.online_directory_snapshot_ticks_msec = Time.get_ticks_msec() - 10000
	game._update_online_directory_rows()
	check(public_list.get_item_text(0).contains("läuft in 65 s ab"),"Lobby expiry countdown advances using a monotonic clock")
	game._on_online_lobbies_received([{"lobby_id":"version-mismatch", "nickname":"OLDHOST", "mode":"versus", "mission_name":"Das Veyra-Becken", "game_version":"0.36.9", "address":"203.0.113.10", "port":2456, "expires_in":75}], "")
	online_panel = game.overlay.get_node("OnlineLobbyPanel")
	public_list = online_panel.get_node("OnlineDirectoryList")
	check(public_list.is_item_disabled(0) and public_list.get_item_text(0).contains("ANDERE VERSION") and (online_panel.get_node("JoinPublicLobby") as Button).disabled,"Mismatched host version is shown and cannot be joined")
	game._on_online_lobbies_received([{"lobby_id":"stale-lobby", "nickname":"STALEHOST", "mode":"coop", "mission_name":"Testmission", "game_version":str(game.update_history.current_version), "address":"203.0.113.9", "port":2456, "expires_in":0}], "")
	online_panel = game.overlay.get_node("OnlineLobbyPanel")
	public_list = online_panel.get_node("OnlineDirectoryList")
	check(public_list.is_item_disabled(0) and public_list.get_item_text(0).contains("VERALTET") and (online_panel.get_node("JoinPublicLobby") as Button).disabled,"Expired lobbies are marked stale and cannot be joined")
	game._on_online_lobbies_received([], "")
	game.online.active=true; game.online.role="host"; game.online.mission_config=game.online_mission_config()
	game.online.required_invite_secret="00112233445566778899AABBCCDDEEFF"
	game.public_lobby_requested=false
	game._on_online_public_address_received("79.240.71.178",true)
	online_panel=game.overlay.get_node("OnlineLobbyPanel")
	var invite_button: Button=online_panel.get_node("PrivateLobbyInviteCodeCopy")
	check(not invite_button.disabled and invite_button.text.contains("SR07-") and not online_panel.has_node("PublishPublicLobby"),"Private host receives a shareable invite code without public listing")
	check(invite_button.tooltip_text.contains("Zugangsschlüssel"),"Invite-code help explains that it grants access")
	game.online.leave(false); game.public_lobby_requested=false; game.show_online_menu()
	game.online_directory.enabled = true
	game.online_directory.base_url = "http://127.0.0.1:1"
	var previous_lobby_check: int = game.online_directory_last_check_msec
	game._advance_online_directory(game.ONLINE_DIRECTORY_REFRESH_SECONDS + 0.1)
	check(game.online_directory_last_check_msec > previous_lobby_check and game.online_directory_loading,"Open lobby browser starts its automatic refresh interval")
	game.online_directory.enabled = false
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		root.content_scale_size = resolution
		await process_frame
		game.show_online_menu()
		online_panel = game.overlay.get_node("OnlineLobbyPanel")
		var global_panel_rect := online_panel.get_global_rect()
		check(global_panel_rect.position.x >= -1 and global_panel_rect.position.y >= -1 and global_panel_rect.end.x <= resolution.x + 1 and global_panel_rect.end.y <= resolution.y + 1,"Multiplayer panel fits %s (rect %s, viewport %s)" % [resolution, global_panel_rect, game.get_viewport_rect().size])
		check(online_panel.get_node("CreateOnlineHost").get_rect().end.y <= online_panel.get_node("RefreshPublicLobbies").position.y or not online_panel.get_node("CreateOnlineHost").get_rect().intersects(online_panel.get_node("RefreshPublicLobbies").get_rect()),"Host action stays clear of lobby refresh at %s" % resolution)
		await capture("multiplayer_directory_%d" % resolution.x)
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1920,1080)
	game.online_directory.enabled = true
	await capture("multiplayer_directory_layout")
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
