extends Control

const WORLD_RECT = Rect2(20,86,1530,944)
const SAVE_PATH = "user://quick_save.json"
const HIGHSCORE_PATH = "user://highscores.json"
const CAMPAIGN_PATH = "user://campaign_progress.json"
const MINIMUM_WINDOW_RESOLUTION := Vector2i(1920,1080)
const WINDOW_RESOLUTIONS := [Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
const ONLINE_DIRECTORY_REFRESH_SECONDS := 15.0
const ONLINE_DIRECTORY_LOBBY_TTL_SECONDS := 75
const MISSION_PATHS := ["res://data/veyra.json","res://data/dry_vein.json","res://data/khepri_pass.json"]
const OnlineSessionScript := preload("res://scripts/online_session.gd")
const OnlineStatsScript := preload("res://scripts/online_stats.gd")
const OnlineDirectoryScript := preload("res://scripts/online_directory.gd")
const PrivateLobbyCode := preload("res://scripts/private_lobby_code.gd")
const PlayerProfileScript := preload("res://scripts/player_profile.gd")
const MatchRecorderScript := preload("res://scripts/match_recorder.gd")
const MatchChartScript := preload("res://scripts/match_chart.gd")
var update_history := Catalog.read_json("res://data/update_history.json")
var update_manager: Node
var update_check_manual := false
var update_button: Button
var update_progress_label: Label
var update_progress_bar: ProgressBar
var update_progress_cancel: Button
var update_checked_this_session := false
var pending_startup_update: Dictionary = {}
var db: Catalog
var mission_index := 0
var sim: Simulation
var online: OnlineSession
var commander_profile
var online_stats: OnlineStats
var online_directory: OnlineDirectory
var online_directory_items: ItemList
var online_directory_empty_state: Label
var online_directory_message := "Noch nicht geladen"
var online_directory_last_refresh := ""
var online_directory_loading := false
var online_directory_snapshot_ticks_msec := 0
var online_directory_refresh_elapsed := 0.0
var online_directory_display_elapsed := 0.0
var online_directory_last_check_msec := 0
var online_directory_selected: Dictionary = {}
var public_lobby_closed_for_guest := false
var public_lobby_requested := false
var private_lobby_password := ""
var online_directory_status_label: Label
var online_stats_enabled := true
var online_stats_status := "Noch keine Serververbindung"
var online_server_status_text := "Noch nicht geprüft"
var online_server_status_online := false
var online_server_status_checked_at := 0
var online_server_status_label: Label
var online_highscore_cache: Dictionary = {}
var online_public_address := ""
var online_public_address_checked := false
var online_public_address_button: Button
var match_recorder := MatchRecorderScript.new()
var match_report_saved := false
var profile_dialog_open := false
var online_status_text := ""
var online_status_label: Label
var network_blend := 0.25
var lobby_mode := "versus"
var chat_box: Panel
var chat_log: RichTextLabel
var chat_input: LineEdit
var connection_label: Label
var renderer: WorldRenderer
var music: MusicDirector
var viewport: SubViewport
var view_container: SubViewportContainer
var ui := Control.new()
var overlay := Control.new()
var selected: Array = []
var inspected := 0
var groups: Dictionary = {}
var bookmarks: Dictionary = {}
var faction := "forge"
var difficulty := "normal"
var paused := true
var playing := false
var ended := false
var classic := false
var crt := 0
var placement := ""
var placement_rotation := 0
var attack_mode := false
var drag_start := Vector2.ZERO
var dragging := false
var middle_drag := false
var right_held := false
var right_panning := false
var right_start := Vector2.ZERO
var right_point := Vector2.ZERO
var harvest_mode := false
var harvest_button: Button
var unload_button: Button
var select_same := false
var group_last := 0
var group_time := 0.0
var status: Label
var energy_label: Label
var mission_clock: Label
var information: Label
var details_button: Button
var repair_button: Button
var selection_icons: Control
var selection_signature := ""
var alert_panel: Panel
var queue_label: Label
var production_bar: ProgressBar
var notification: Label
var objective: Label
var optional_objective: Label
var minimap: TacticalMap
var radar_caption: Label
var side_panel: Panel
var low_power_alerted := false
var buttons: Dictionary = {}
var requirement_marks: Dictionary = {}
var production_rows: Dictionary = {}
var production_empty_label: Label
var production_content: Control
var production_signature := ""
var production_target_factory_id := 0
var hover_panel: Panel
var hover_label: Label
var hovered_entity_id := 0
var pointer_local := Vector2(-10000,-10000)
const EDGE_SCROLL_BAND := 46.0
var category := "buildings"
var notice_timer := 0.0
var last_event := Vector2(400,1450)
var update_timer := 0.0
var autosave_timer := 120.0
var debug_label: Label
var accumulator := 0.0
var render_previous: Dictionary = {}
var render_current: Dictionary = {}
var edge_scroll := true
var health_mode := "damaged"
var save_config := ConfigFile.new()
var remap_action := ""
var intro_active := false
var intro_art: FrontendBackdrop
var menu_buttons: Dictionary = {}
var hotkeys := {"attack":KEY_A,"stop":KEY_S,"hold":KEY_H,"guard":KEY_G,"repair":KEY_R,"home":KEY_HOME,"event":KEY_SPACE,"save":KEY_F5,"load":KEY_F9}
var options_tab := "BILD"
const GOLD = Color("e7bd78")
const MINT = Color("79d9bd")
const MUTED = Color("b4a58d")
const PERFORMANCE_LOG_PATH := "user://performance_events_v2.csv"
const LOW_FPS_WARNING_THRESHOLD := 60.0
const LOW_FPS_CRITICAL_THRESHOLD := 50.0
const RECOVERY_FPS_THRESHOLD := 60.0
const LOW_FPS_TRIGGER_SECONDS := 1.0
const LOW_FPS_CRITICAL_TRIGGER_SECONDS := 0.8
const FPS_RECOVERY_TRIGGER_SECONDS := 1.0
var fps_label: Label
var performance_log_path := PERFORMANCE_LOG_PATH
var fps_sample_elapsed := 0.0
var fps_sample_frames := 0
var low_fps_seconds := 0.0
var low_fps_minimum := INF
var low_fps_weighted_sum := 0.0
var low_fps_recorded_seconds := 0.0
var low_fps_critical_seconds := 0.0
var low_fps_critical_minimum := INF
var low_fps_critical_weighted_sum := 0.0
var low_fps_critical_recorded_seconds := 0.0
var low_fps_recovery_seconds := 0.0
var low_fps_active := false
var low_fps_critical_logged := false
var fps_auto_profile := false
var profiler_overlay_visible := false
var performance_log_error_reported := false
var highscore_path := HIGHSCORE_PATH
var campaign_progress: Dictionary = {"format_version":1,"unlocked_mission":0,"tech_level":0,"completed":[],"mission_medals":{}}
var campaign_progress_path := CAMPAIGN_PATH
var run_id := ""
var highscore_mission_index := -1
var last_load_path := ""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	migrate_legacy_user_data()
	db=Catalog.new(MISSION_PATHS[mission_index])
	music=MusicDirector.new()
	add_child(music)
	setup_theme()
	setup_world()
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	load_settings()
	commander_profile=PlayerProfileScript.new()
	commander_profile.load_profile()
	online=OnlineSessionScript.new()
	online.name="OnlineSession"
	online.local_game_version=str(update_history.get("current_version", "unbekannt"))
	add_child(online)
	online.status_changed.connect(_on_online_status_changed)
	online.game_start_received.connect(_on_online_game_start)
	online.world_snapshot_received.connect(_on_online_world_snapshot)
	online.match_report_received.connect(_on_online_match_report)
	online.command_rejected.connect(notify)
	online.lobby_changed.connect(_refresh_online_lobby)
	online.chat_received.connect(_on_online_chat)
	online.connection_lost.connect(func():if playing: paused=true)
	online.rematch_received.connect(func():playing=false; paused=true; show_online_menu())
	online_stats_enabled=bool(save_config.get_value("online","enabled",true))
	if OS.get_environment("SOLARIT_DISABLE_ONLINE_STATS") == "1":
		online_stats_enabled=false
	else:
		online_stats=OnlineStatsScript.new()
		online_stats.name="OnlineStats"
		add_child(online_stats)
		online_stats.status_changed.connect(_on_online_stats_status)
		online_stats.highscores_received.connect(_on_online_highscores_received)
		online_stats.server_status_changed.connect(_on_online_server_status)
		online_stats.public_address_received.connect(_on_online_public_address_received)
		online_directory = OnlineDirectoryScript.new()
		online_directory.name = "OnlineDirectory"
		online_directory.client_id = online_stats.client_id
		online_directory.game_version = str(update_history.get("current_version", "unbekannt"))
		add_child(online_directory)
		online_directory.lobbies_received.connect(_on_online_lobbies_received)
		online_directory.publish_finished.connect(_on_public_lobby_published)
		online_directory.status_changed.connect(_on_online_directory_status)
	_configure_online_stats()
	load_campaign_progress()
	setup_update_manager()
	if not db.errors.is_empty():
		show_error("Spieldaten ungültig:\n"+"\n".join(db.errors))
		return
	if "--skip-intro" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_user_args(): show_main_menu()
	else: show_intro()
	if "--smoke" in OS.get_cmdline_user_args():
		start_game()
		get_tree().create_timer(3.0).timeout.connect(capture_smoke)
	elif "--frontend-smoke" in OS.get_cmdline_user_args():
		get_tree().create_timer(1.0).timeout.connect(capture_frontend_smoke)
	if update_manager.can_check() and not update_checked_this_session:
		update_checked_this_session=true
		update_manager.check_for_update()

func setup_theme() -> void:
	var t := Theme.new()
	t.default_font_size=19
	var normal := StyleBoxFlat.new()
	normal.bg_color=Color("342920")
	normal.border_color=Color("79604a")
	normal.set_border_width_all(1)
	normal.content_margin_left=15; normal.content_margin_right=15
	normal.content_margin_top=9; normal.content_margin_bottom=9
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color=Color("4b3827"); hover.border_color=MINT
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color=Color("5d472d"); pressed.border_color=GOLD; pressed.border_width_left=3
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color=Color("251e18"); disabled.border_color=Color("48392d")
	t.set_stylebox("normal","Button",normal)
	t.set_stylebox("hover","Button",hover)
	t.set_stylebox("pressed","Button",pressed)
	t.set_stylebox("focus","Button",hover)
	t.set_stylebox("disabled","Button",disabled)
	t.set_color("font_color","Button",Color("d5e3db"))
	t.set_color("font_disabled_color","Button",Color("8c7964"))
	t.set_color("font_color","Label",Color("d6e1d9"))
	t.set_color("font_color","CheckButton",Color("d6e1d9"))
	var tooltip := StyleBoxFlat.new()
	tooltip.bg_color=Color("302317"); tooltip.border_color=GOLD
	tooltip.set_border_width_all(1)
	tooltip.content_margin_left=9; tooltip.content_margin_right=9
	tooltip.content_margin_top=6; tooltip.content_margin_bottom=6
	t.set_stylebox("panel","TooltipPanel",tooltip)
	t.set_font_size("font_size","TooltipLabel",17)
	theme=t

func setup_world() -> void:
	view_container=SubViewportContainer.new()
	view_container.position=WORLD_RECT.position
	view_container.size=WORLD_RECT.size
	view_container.stretch=true
	view_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view_container.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(view_container)
	viewport=SubViewport.new()
	viewport.size=Vector2i(WORLD_RECT.size)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input=true
	view_container.add_child(viewport)
	renderer=WorldRenderer.new()
	renderer.logical_size=WORLD_RECT.size
	viewport.add_child(renderer)

func clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()

func modal_overlay_active() -> bool:
	return is_instance_valid(overlay) and overlay.get_child_count()>0

func suppress_world_hover() -> void:
	hovered_entity_id=0
	if is_instance_valid(renderer): renderer.hovered_entity_id=0
	if is_instance_valid(hover_panel): hover_panel.visible=false

func migrate_legacy_user_data() -> void:
	var destination:=OS.get_user_data_dir()
	var base_path:=destination.get_base_dir()
	for legacy_name in ["ASHLINE — Das Veyra-Becken", "ASHLINE - Das Veyra-Becken"]:
		var source:=base_path.path_join(legacy_name)
		if not DirAccess.dir_exists_absolute(source): continue
		DirAccess.make_dir_recursive_absolute(destination)
		for filename in DirAccess.get_files_at(source):
			var old_file:=source.path_join(filename)
			var new_file:=destination.path_join(filename)
			if not FileAccess.file_exists(new_file): DirAccess.copy_absolute(old_file,new_file)
		for folder in ["match_reports"]:
			var old_folder:=source.path_join(folder)
			if not DirAccess.dir_exists_absolute(old_folder): continue
			var new_folder:=destination.path_join(folder)
			DirAccess.make_dir_recursive_absolute(new_folder)
			for filename in DirAccess.get_files_at(old_folder):
				var old_file:=old_folder.path_join(filename)
				var new_file:=new_folder.path_join(filename)
				if not FileAccess.file_exists(new_file): DirAccess.copy_absolute(old_file,new_file)

func panel(parent: Node, rect: Rect2, color: Color = Color("241d18")) -> Panel:
	var p := Panel.new()
	p.position=rect.position; p.size=rect.size
	var style := StyleBoxFlat.new()
	style.bg_color=color; style.border_color=Color("65513e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color=Color(0,0,0,0.28); style.shadow_size=10; style.shadow_offset=Vector2(0,4)
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	return p

func label(parent: Node, text_value: String, pos: Vector2, font_size: int = 20, color: Color = Color("d6e1d9"), width: float = 0) -> Label:
	var l := Label.new()
	l.text=text_value; l.position=pos
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if width>0:
		l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x=width
		l.size.x=width
		l.clip_text=true
	parent.add_child(l)
	if width>0:
		var extent := l.get_theme_font("font").get_multiline_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size)
		l.size=Vector2(width,extent.y+font_size)
	return l

func add_version_signature(parent: Control) -> Label:
	var version_label:=label(parent,"SOLARIT: RANDSEKTOR 07  /  "+str(update_history.get("current_version","unbekannt")),Vector2(1510,1025),15,MUTED,360)
	version_label.name="GameVersionLabel"
	version_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return version_label

func button(parent: Node, text_value: String, rect: Rect2, callback: Callable) -> Button:
	var b: Button = preload("res://scripts/system_button.gd").new()
	b.clip_text=true
	b.text=text_value; b.position=rect.position; b.size=rect.size
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func show_main_menu() -> void:
	if is_instance_valid(online_stats): online_stats.stop_playing()
	if online!=null and online.active: online.leave(false)
	var scene_time := intro_art.elapsed if is_instance_valid(intro_art) else 0.0
	intro_active=false
	playing=false; paused=true; placement=""; renderer.placement=""
	suppress_world_hover()
	clear(ui); clear(overlay)
	view_container.visible=false
	var art := FrontendBackdrop.new()
	art.size=Vector2(1920,1080); art.elapsed=scene_time
	ui.add_child(art)
	label(ui,"VEYRA  /  RANDSEKTOR 07  /  2186",Vector2(96,65),17,MUTED)
	label(ui,"SOLARIT:\nRANDSEKTOR 07",Vector2(85,151),58,GOLD)
	label(ui,"DIE VEYRA-FRONT",Vector2(96,301),25,MINT)
	label(ui,"Unter der Asche einer fremden Welt\nbeginnt deine erste Kolonie.",Vector2(98,373),24,Color("cbd5c8"))
	label(ui,"KOMMANDO / BEREIT",Vector2(98,482),16,MUTED)
	menu_buttons.clear()
	menu_buttons.start=menu_button("01","EINSATZ WÄHLEN",526,show_briefing,true)
	menu_buttons.multiplayer=menu_button("02","MULTIPLAYER",600,show_online_menu)
	menu_buttons.load=menu_button("03","SPIELSTAND LADEN",658,func():show_load_dialog(show_main_menu))
	menu_buttons.load.disabled=not FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists("user://autosave.json")
	menu_buttons.options=menu_button("04","OPTIONEN",716,func():show_options(show_main_menu))
	menu_buttons.credits=menu_button("05","MUSIK & CREDITS",774,show_credits)
	menu_buttons.quit=menu_button("06","BEENDEN",832,func():music.shutdown(); get_tree().quit())
	menu_buttons.start.grab_focus()
	show_menu_commander()
	var replay := button(ui,"↺  INTRO ANSEHEN",Rect2(98,900,245,38),show_intro)
	replay.add_theme_font_size_override("font_size",16)
	menu_buttons.updates=button(ui,"UPDATEINFO",Rect2(360,900,190,38),func():show_updates(show_main_menu))
	menu_buttons.updates.add_theme_font_size_override("font_size",16)
	menu_buttons.highscores=button(ui,"BESTENLISTE",Rect2(567,900,200,38),func():show_highscores(show_main_menu))
	menu_buttons.highscores.add_theme_font_size_override("font_size",16)
	update_button=button(ui,"UPDATES PRÜFEN",Rect2(784,900,220,38),check_for_game_update)
	update_button.add_theme_font_size_override("font_size",16)
	ghost_button_style(replay); ghost_button_style(menu_buttons.updates); ghost_button_style(menu_buttons.highscores); ghost_button_style(update_button)
	if not commander_profile.has_identity(): show_profile_dialog(true,show_main_menu)
	update_button.disabled=not update_manager.can_check()
	if update_button.disabled:
		update_button.text="UPDATES AB RELEASE"
		update_button.tooltip_text="Dieser Build enthält noch keinen Veröffentlichungsfeed. GitHub-Releases werden automatisch eingebunden."
	label(ui,"SOLARIT-SIGNAL\nVEYRA-FRONT / 3 EINSÄTZE",Vector2(1320,96),16,Color("a7baad"))
	label(ui,"BASIS ERRICHTEN  /  RESSOURCEN SICHERN  /  GRENZE HALTEN",Vector2(96,1025),15,MUTED)
	add_version_signature(ui)
	music.start_frontend()
	# Staggered, short fades preserve immediate button response.
	var index := 0
	for child in ui.get_children():
		if child==art: continue
		child.modulate.a=0
		var tween := child.create_tween()
		tween.tween_property(child,"modulate:a",1.0,0.4).set_delay(minf(index*0.035,0.25))
		index+=1
	if not pending_startup_update.is_empty():
		var result := pending_startup_update.duplicate(true)
		pending_startup_update.clear()
		show_available_update(result)

func setup_update_manager() -> void:
	update_manager=load("res://scripts/update_manager.gd").new()
	var channel: Dictionary={}
	if FileAccess.file_exists("res://data/update_channel.json"):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json"))
		if parsed is Dictionary: channel=parsed
	update_manager.configure(str(update_history.get("current_version","0.0")),channel)
	add_child(update_manager)
	update_manager.update_check_finished.connect(_on_update_check_finished)
	update_manager.installer_download_finished.connect(_on_installer_download_finished)
	update_manager.download_progress_changed.connect(_on_update_download_progress)

func check_for_game_update() -> void:
	if update_manager==null or not update_manager.can_check():
		if is_instance_valid(update_button): notify("Der Updatefeed wird mit dem offiziellen GitHub-Release aktiviert.")
		return
	if not str(update_manager.latest_version).is_empty() and update_manager.is_newer_version(str(update_manager.latest_version),str(update_history.get("current_version","0.0"))):
		show_available_update({"version":update_manager.latest_version,"notes":update_manager.latest_notes})
		return
	update_check_manual=true
	if is_instance_valid(update_button): update_button.disabled=true; update_button.text="PRÜFE…"
	if not update_manager.check_for_update():
		if is_instance_valid(update_button): update_button.disabled=false; update_button.text="UPDATES PRÜFEN"

func _on_update_check_finished(result: Dictionary) -> void:
	if is_instance_valid(update_button):
		update_button.disabled=not update_manager.can_check()
		if bool(result.get("available",false)):
			update_button.text="UPDATE VERFÜGBAR · "+str(result.get("version",""))
			update_button.tooltip_text="Eine neue Version ist verfügbar. Anklicken, um den signaturgeprüften Installer zu laden."
		elif not bool(result.get("ok",false)):
			update_button.text="UPDATE-CHECK ERNEUT VERSUCHEN"
			update_button.tooltip_text=str(result.get("message","GitHub ist nicht erreichbar."))
		else:
			update_button.text="UPDATES PRÜFEN"
			update_button.tooltip_text="Das Spiel ist auf dem neuesten Stand."
	if bool(result.get("available",false)):
		if intro_active: pending_startup_update=result.duplicate(true)
		else: show_available_update(result)
	elif update_check_manual:
		if bool(result.get("ok",false)):
			show_update_current_dialog()
		else:
			notify(str(result.get("message","Die Update-Prüfung ist fehlgeschlagen.")))
	update_check_manual=false

func show_update_current_dialog() -> void:
	clear(overlay)
	var viewport_size := get_viewport_rect().size
	var dialog_size := Vector2(680, 300)
	var dialog_position := (viewport_size - dialog_size) * 0.5
	var p := panel(overlay, Rect2(dialog_position, dialog_size), Color("211b17"))
	p.name = "UpdateCurrentDialog"
	label(p, "SOLARIT: RANDSEKTOR 07 / UPDATE", Vector2(34, 28), 17, MINT)
	label(p, "Spiel ist aktuell", Vector2(34, 64), 36, GOLD)
	var version_label := label(p, "Installierte Version: v%s" % str(update_history.get("current_version", "unbekannt")), Vector2(36, 126), 20, Color("d5ded5"), 600)
	version_label.name = "CurrentVersion"
	label(p, "Es ist derzeit keine neuere Version verfügbar.", Vector2(36, 164), 17, MUTED, 600)
	button(p, "OK", Rect2(36, 218, 608, 48), func(): clear(overlay))

func show_available_update(result: Dictionary) -> void:
	clear(overlay)
	var p:=panel(overlay,Rect2(520,255,880,570),Color("211b17"))
	label(p,"SOLARIT: RANDSEKTOR 07 / UPDATE",Vector2(38,30),18,MINT)
	label(p,"INSTALLIERTE VERSION",Vector2(40,76),15,MUTED)
	var installed_version := label(p,"v"+str(update_history.get("current_version","unbekannt")),Vector2(40,99),34,Color("c8d8ce"))
	installed_version.name="InstalledVersion"
	label(p,"→",Vector2(389,99),32,MUTED)
	label(p,"NEUE VERSION",Vector2(470,76),15,MINT)
	var new_version := label(p,"v"+str(result.get("version","unbekannt")),Vector2(470,97),42,GOLD)
	new_version.name="NewVersion"
	var notes:=RichTextLabel.new()
	notes.position=Vector2(40,153); notes.size=Vector2(800,282); notes.bbcode_enabled=false; notes.scroll_active=true
	notes.add_theme_font_size_override("normal_font_size",19)
	notes.text=str(result.get("notes","" )).strip_edges()
	if notes.text.is_empty(): notes.text="Verbesserungen und Fehlerbehebungen für SOLARIT: RANDSEKTOR 07."
	p.add_child(notes)
	button(p,"HERUNTERLADEN & INSTALLIEREN",Rect2(40,470,500,54),func():begin_game_update())
	button(p,"SPÄTER",Rect2(562,470,278,54),func():clear(overlay))

func begin_game_update() -> void:
	clear(overlay)
	var p:=panel(overlay,Rect2(500,350,920,360),Color("211b17"))
	p.name="UpdateProgressPanel"
	label(p,"UPDATE WIRD VORBEREITET",Vector2(36,28),28,GOLD)
	update_progress_label=label(p,"Das Prüfsummen-Manifest wird geladen …",Vector2(38,93),19,MUTED,840)
	update_progress_label.name="UpdateProgressLabel"
	update_progress_bar=ProgressBar.new()
	update_progress_bar.name="UpdateProgressBar"
	update_progress_bar.position=Vector2(38,152); update_progress_bar.size=Vector2(844,24); update_progress_bar.max_value=100
	update_progress_bar.show_percentage=false
	p.add_child(update_progress_bar)
	update_progress_cancel=button(p,"ABBRECHEN",Rect2(38,235,844,52),cancel_game_update)
	if not update_manager.begin_installer_download():
		if update_manager.busy: return
		if is_instance_valid(overlay) and overlay.get_child_count()>0 and overlay.get_child(0)==p:
			clear(overlay)
			show_error("Das Update konnte nicht gestartet werden. Bitte prüfe deine Internetverbindung und versuche es erneut.")

func _on_update_download_progress(stage: String, downloaded_bytes: int, total_bytes: int) -> void:
	if not is_instance_valid(update_progress_label) or not is_instance_valid(update_progress_bar): return
	match stage:
		"manifest":
			update_progress_label.text="Prüfsummen-Manifest wird geladen …"
			update_progress_bar.value=0
		"installer":
			var downloaded_text:=format_download_size(downloaded_bytes)
			var total_text:=format_download_size(total_bytes)
			if total_bytes>0:
				var percent:=clampi(roundi(float(downloaded_bytes)*100.0/float(total_bytes)),0,100)
				update_progress_bar.value=percent
				update_progress_label.text="Installer wird geladen · %s von %s (%d%%)" % [downloaded_text,total_text,percent]
			else:
				update_progress_label.text="Installer wird geladen · %s" % downloaded_text
		"verify":
			update_progress_bar.value=100
			update_progress_label.text="Download vollständig · SHA-256-Prüfsumme wird kontrolliert …"

func format_download_size(byte_count: int) -> String:
	return "%.1f MB" % (float(byte_count)/1048576.0)

func cancel_game_update() -> void:
	if is_instance_valid(update_manager): update_manager.cancel_installer_download()
	clear(overlay)
	update_progress_label=null
	update_progress_bar=null
	update_progress_cancel=null
	notify("Update-Download abgebrochen.")

func _on_installer_download_finished(success: bool, message: String) -> void:
	if not success:
		update_progress_label=null; update_progress_bar=null; update_progress_cancel=null
		clear(overlay)
		show_error(message)
		return
	if update_manager.launch_installer():
		if is_instance_valid(update_progress_label): update_progress_label.text="Download geprüft · Windows-Setup geöffnet. Folge den Schritten im Setup-Fenster."
		if is_instance_valid(update_progress_bar): update_progress_bar.value=100
		if is_instance_valid(update_progress_cancel):
			update_progress_cancel.text="SETUP-FENSTER IST GEÖFFNET"
			update_progress_cancel.disabled=true
	else:
		update_progress_label=null; update_progress_bar=null; update_progress_cancel=null
		clear(overlay)
		show_error("Der Installer wurde geprüft, konnte aber nicht gestartet werden. Du findest ihn unter user://updates.")

func menu_button(number: String, text_value: String, y: float, callback: Callable, primary: bool = false) -> Button:
	var b := button(ui,number+"     /     "+text_value,Rect2(96,y,510,64 if primary else 48),callback)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size",21 if primary else 18)
	var style := StyleBoxFlat.new()
	style.set_border_width_all(0)
	style.bg_color=Color(0.20,0.15,0.10,0.72) if primary else Color(0.045,0.055,0.055,0.36)
	style.border_color=Color("7e694f") if primary else Color(0.25,0.39,0.37,0.38)
	style.border_width_left=3 if primary else 0
	style.border_width_bottom=1
	style.content_margin_left=18
	style.shadow_color=Color(0,0,0,0.16); style.shadow_size=4; style.shadow_offset=Vector2(0,2)
	var hover: StyleBoxFlat = style.duplicate()
	hover.set_border_width_all(0)
	hover.bg_color=Color(0.08,0.12,0.115,0.82); hover.border_color=MINT
	hover.border_width_left=3; hover.shadow_color=Color(MINT.r,MINT.g,MINT.b,0.12); hover.shadow_size=7
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color=Color("59452d")
	var focus_style: StyleBoxFlat=style.duplicate()
	focus_style.set_border_width_all(0)
	focus_style.bg_color=Color(0.20,0.15,0.10,0.90) if primary else Color(0.08,0.12,0.115,0.82)
	focus_style.border_color=GOLD if primary else MINT
	focus_style.border_width_left=3 if primary else 3
	focus_style.border_width_bottom=1
	focus_style.shadow_color=Color(GOLD.r,GOLD.g,GOLD.b,0.10); focus_style.shadow_size=7; focus_style.shadow_offset=Vector2(0,2)
	b.add_theme_stylebox_override("normal",style)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",pressed)
	b.add_theme_stylebox_override("focus",focus_style)
	b.add_theme_color_override("font_color",GOLD if primary else Color("c8d3cc"))
	b.add_theme_color_override("font_hover_color",Color("f0e2c6"))
	if primary:
		var arrow := Label.new()
		arrow.text="→"; arrow.position=Vector2(462,17); arrow.size=Vector2(28,30)
		arrow.add_theme_font_size_override("font_size",22)
		arrow.add_theme_color_override("font_color",GOLD)
		arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(arrow)
	b.mouse_entered.connect(func():music.cue("select",0.3))
	return b

func ghost_button_style(target: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color=Color(0.04,0.055,0.052,0.20)
	normal.set_border_width_all(0)
	normal.border_width_bottom=1
	normal.border_color=Color(0.45,0.40,0.32,0.38)
	normal.content_margin_left=8; normal.content_margin_right=8
	var hover: StyleBoxFlat=normal.duplicate()
	hover.bg_color=Color(0.08,0.13,0.12,0.58); hover.border_color=MINT
	hover.border_width_bottom=2
	target.add_theme_stylebox_override("normal",normal)
	target.add_theme_stylebox_override("hover",hover)
	target.add_theme_stylebox_override("focus",hover)
	target.add_theme_stylebox_override("pressed",hover)
	target.add_theme_color_override("font_color",Color("b5b2a3"))
	target.add_theme_color_override("font_hover_color",Color("e7d7b8"))

func show_intro() -> void:
	intro_active=true; playing=false; paused=true
	view_container.visible=false
	clear(ui); clear(overlay)
	intro_art=FrontendBackdrop.new()
	intro_art.intro=true; intro_art.size=Vector2(1920,1080)
	intro_art.completed.connect(skip_intro)
	ui.add_child(intro_art)
	add_version_signature(ui)
	var skip := button(ui,"ÜBERSPRINGEN  /  ESC",Rect2(1580,26,292,43),skip_intro)
	skip.add_theme_font_size_override("font_size",16)
	skip.mouse_filter=Control.MOUSE_FILTER_STOP
	skip.focus_mode=Control.FOCUS_ALL
	skip.z_index=100
	music.start_frontend(true)

func skip_intro() -> void:
	if intro_active:
		show_main_menu()

# Intro input must be handled before GUI controls can consume it.
# _unhandled_input() is too late for Escape/Enter/Space and mouse clicks
# whenever a Control handles the event first.
func _input(event: InputEvent) -> void:
	if intro_active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			skip_intro()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			skip_intro()
			get_viewport().set_input_as_handled()
		return
	# Escape is handled in _input(), not _unhandled_input(), because focused GUI controls
	# can consume it before the gameplay handler sees it. This keeps ESC reliable in HUD,
	# catalog, pause and overlay screens. Remapping and chat input retain priority.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if remap_action=="":
			if not (is_instance_valid(chat_input) and chat_input.has_focus()):
				if harvest_mode:
					harvest_mode=false
				elif placement!="":
					placement=""; renderer.placement=""
				elif playing:
					if paused and not ended: resume_game()
					elif not ended: show_pause()
				elif overlay.get_child_count()>0:
					clear(overlay)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouse:
		pointer_local=get_global_transform_with_canvas().affine_inverse()*event.position
	if modal_overlay_active():
		right_held=false; right_panning=false; middle_drag=false; dragging=false
		if is_instance_valid(renderer): renderer.selecting=false
		suppress_world_hover()
		return
	# Once started in the world, finish the gesture even when the pointer crosses the HUD.
	if not right_held or not playing or paused or not event is InputEventMouse: return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var local: Vector2 = inverse*event.position
	if event is InputEventMouseMotion:
		if not right_panning and local.distance_to(right_start)>6:
			right_panning=true; renderer.camera-=(local-right_start)/renderer.zoom
		elif right_panning: renderer.camera-=inverse.basis_xform(event.relative)/renderer.zoom
		clamp_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		if not right_panning and WORLD_RECT.has_point(local): issue_context_order(right_point)
		right_held=false; right_panning=false
		get_viewport().set_input_as_handled()

func mission_index_for_id(id: String) -> int:
	for index in range(MISSION_PATHS.size()):
		var probe:=Catalog.new(MISSION_PATHS[index])
		if str(probe.mission.get("id",""))==id: return index
	return -1

func select_mission(index: int) -> void:
	if index<0 or index>int(campaign_progress.unlocked_mission): notify("Dieser Einsatz wird erst nach dem vorherigen Missionssieg freigegeben."); return
	mission_index=clampi(index,0,MISSION_PATHS.size()-1)
	db=Catalog.new(MISSION_PATHS[mission_index])
	playing=false; paused=true
	show_briefing()

func mission_objective_brief() -> String:
	var lines: Array[String]=[]
	for item in db.mission.get("objectives",[]):
		var objective: Dictionary=item
		var prefix: String="HAUPT" if bool(objective.get("primary",false)) else ("SICHERN" if str(objective.get("type",""))=="protect" else "OPTIONAL")
		lines.append(prefix+"  ·  "+str(objective.get("text","")))
	return "\n".join(lines)

func show_briefing() -> void:
	clear(ui); clear(overlay)
	view_container.visible=false
	var art := FrontendBackdrop.new()
	art.size=Vector2(1920,1080)
	ui.add_child(art)
	var veil := ColorRect.new()
	veil.color=Color(0.025,0.035,0.038,0.50); veil.size=Vector2(1920,1080); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(veil)
	label(ui,"SOLARIT: RANDSEKTOR 07   /   EINSATZVORBEREITUNG",Vector2(72,34),17,MINT)
	var p := panel(ui,Rect2(300,64,1320,950),Color("202a29"))
	p.clip_contents=true
	var rail := ColorRect.new(); rail.color=MINT; rail.position=Vector2.ZERO; rail.size=Vector2(5,950); rail.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(rail)
	label(p,"EINSATZ / %02d     ·     VEYRA-FRONT" % (mission_index+1),Vector2(48,27),17,MINT)
	label(p,str(db.mission.get("display_name",db.mission.get("name","Einsatz"))),Vector2(48,62),42,GOLD)
	var description:=label(p,db.mission.briefing,Vector2(48,116),19,Color("d5ded5"),1215)
	description.name="MissionDescription"; description.size=Vector2(1215,96); description.clip_contents=true
	label(p,"KAMPAGNENFOLGE  ·  EINSATZ %02d / %02d" % [mission_index+1,MISSION_PATHS.size()],Vector2(48,234),14,MUTED)
	for i in range(MISSION_PATHS.size()):
		var preview:=Catalog.new(MISSION_PATHS[i])
		var unlocked:=i<=int(campaign_progress.unlocked_mission)
		var mission_button:=button(p,("%02d  %s" % [i+1,str(preview.mission.get("short_name",preview.mission.get("display_name","Einsatz")))]) if unlocked else ("%02d  SIGNAL GESPERRT"%[i+1]),Rect2(48+i*406,260,386,55),func():select_mission(i))
		mission_button.disabled=not unlocked
		mission_button.tooltip_text="" if unlocked else "Wird nach dem Sieg im vorherigen Einsatz freigeschaltet."
		var mission_style:=StyleBoxFlat.new(); mission_style.bg_color=Color("173732") if i==mission_index else Color("263331"); mission_style.border_color=MINT if i==mission_index else Color("485b55"); mission_style.set_border_width_all(1); mission_style.set_corner_radius_all(4)
		mission_button.add_theme_stylebox_override("normal",mission_style); mission_button.add_theme_color_override("font_color",Color("82e3c0") if unlocked and i==mission_index else (Color("d5ded5") if unlocked else MUTED))
		var completed_missions: Array=campaign_progress.get("completed",[])
		var mission_id:=str(preview.mission.get("id",""))
		var progress_segment:=ColorRect.new()
		progress_segment.position=Vector2(48+i*406,321); progress_segment.size=Vector2(386,3)
		progress_segment.color=GOLD if completed_missions.has(mission_id) else (MINT if i==mission_index else (Color("52746b") if unlocked else Color("3b3027")))
		progress_segment.mouse_filter=Control.MOUSE_FILTER_IGNORE
		p.add_child(progress_segment)
		var medals_value: Variant=campaign_progress.get("mission_medals",{})
		var saved_medal:=str(medals_value.get(mission_id,"")) if medals_value is Dictionary else ""
		var medal_label:=label(p,("BESTE MEDAILLE  ·  "+saved_medal) if not saved_medal.is_empty() else "NOCH KEINE MEDAILLE",Vector2(48+i*406,328),12,medal_color(saved_medal))
		medal_label.name="MissionMedal%02d"%i
		medal_label.tooltip_text="Deine beste dauerhaft gespeicherte Missionswertung." if not saved_medal.is_empty() else "Wird nach einem Missionssieg angezeigt."
	label(p,"KOMMANDO WÄHLEN",Vector2(48,352),14,MUTED)
	var index := 0
	for id in db.factions:
		var f: Dictionary = db.factions[id]
		var b := button(p,f.name+"\n"+f.tag,Rect2(48+index*406,378,386,76),func():faction=id; show_briefing())
		var accent:=Color(str(f.get("color","69d6c0")))
		var card := StyleBoxFlat.new(); card.bg_color=Color("173732") if faction==id else Color("263331"); card.border_color=accent if faction==id else accent.darkened(0.45); card.set_border_width_all(1); card.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal",card); b.add_theme_color_override("font_color",accent if faction==id else Color("d5ded5"))
		var faction_rail:=ColorRect.new(); faction_rail.color=accent; faction_rail.position=Vector2(0,0); faction_rail.size=Vector2(4,76); faction_rail.mouse_filter=Control.MOUSE_FILTER_IGNORE; b.add_child(faction_rail)
		var insignia:=ColorRect.new(); insignia.color=Color(accent,0.15); insignia.position=Vector2(16,15); insignia.size=Vector2(46,46); insignia.mouse_filter=Control.MOUSE_FILTER_IGNORE; b.add_child(insignia)
		var initial:=Label.new(); initial.text=str(f.name).substr(0,1); initial.position=Vector2(16,15); initial.size=Vector2(46,46); initial.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; initial.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; initial.add_theme_color_override("font_color",accent); initial.add_theme_font_size_override("font_size",23); initial.mouse_filter=Control.MOUSE_FILTER_IGNORE; b.add_child(initial)
		b.tooltip_text=f.description
		index+=1
	label(p,db.factions[faction].description,Vector2(48,464),17,Color(str(db.factions[faction].get("color","69d6c0"))),1215)
	label(p,"SCHWIERIGKEIT",Vector2(48,508),14,MUTED)
	index=0
	for id in ["easy","normal","hard"]:
		var names := {"easy":"Ruhig","normal":"Ausgewogen","hard":"Entschlossen"}
		var b := button(p,names[id],Rect2(48+index*406,534,386,48),func():difficulty=id; show_briefing())
		var card := StyleBoxFlat.new(); card.bg_color=Color("173732") if difficulty==id else Color("263331"); card.border_color=MINT if difficulty==id else Color("485b55"); card.set_border_width_all(1); card.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal",card); b.add_theme_color_override("font_color",Color("82e3c0") if difficulty==id else Color("d5ded5"))
		index+=1
	var resistance_copy: String={"easy":"Ruhig · längere Vorwarnung und kleinere feindliche Angriffe.","normal":"Ausgewogen · regulärer Druck und mittlere Angriffsgruppen.","hard":"Entschlossen · kurze Vorwarnung, größere Gruppen und häufigere Angriffe."}.get(difficulty,"Ausgewogen")
	label(p,resistance_copy,Vector2(48,574),14,MINT,740)
	var threat_level:=1 if difficulty=="easy" else (2 if difficulty=="normal" else 3)
	label(p,"BEDROHUNG",Vector2(842,574),12,MUTED,100)
	var threat_names: Array[String]=["NIEDRIG","MITTEL","HOCH"]
	label(p,threat_names[threat_level-1],Vector2(946,572),13,Color("e8b963") if threat_level<3 else Color("e06d4e"),112)
	for threat_index in range(5):
		var threat_mark:=ColorRect.new(); threat_mark.position=Vector2(1064+threat_index*42,578); threat_mark.size=Vector2(34,6)
		threat_mark.color=Color("e8b963") if threat_index<threat_level*2-1 else Color("3b3a35")
		threat_mark.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(threat_mark)
	label(p,"AUFTRAG",Vector2(48,606),14,MUTED)
	label(p,mission_objective_brief(),Vector2(48,631),16,Color("d5ded5"),720)
	label(p,"AUFBAUROUTE",Vector2(48,730),13,MUTED)
	label(p,str(db.mission.get("briefing_hint","Impulswerk → Raffinerie → Werft · Späher erkunden die Engstelle")),Vector2(48,753),15,Color("d5ded5"),720)
	label(p,"NÄCHSTE FREIGABE",Vector2(48,790),13,MUTED)
	var unlock_text := "Kampagne abgeschlossen" if mission_index>=MISSION_PATHS.size()-1 else "Sieg schaltet Einsatz %02d frei" % (mission_index+2)
	label(p,unlock_text,Vector2(48,812),15,MINT,720)
	label(p,"TAKTISCHE LAGE",Vector2(832,606),14,MUTED)
	var tactical_preview := MissionTacticalPreview.new()
	tactical_preview.name="MissionTacticalPreview"
	tactical_preview.position=Vector2(802,631); tactical_preview.size=Vector2(470,180); tactical_preview.mission_data=db.mission
	tactical_preview.tooltip_text="Einsatzkarte mit Gelände, Solaritfeldern, bekannten Gegnern und Hauptziel"
	p.add_child(tactical_preview)
	label(p,"RANDSEKTOR 07   ·   %d × %d FELDER   ·   SOLARITVORKOMMEN" % [int(db.mission.get("width",64)),int(db.mission.get("height",64))],Vector2(802,820),12,MUTED,470)
	button(p,"ZURÜCK ZUM HAUPTMENÜ",Rect2(48,854,350,58),show_main_menu)
	button(p,"MULTIPLAYER",Rect2(420,854,340,58),show_online_menu)
	var launch := button(p,"EINSATZ STARTEN     →",Rect2(798,854,474,58),start_game)
	launch.add_theme_color_override("font_color",GOLD); launch.add_theme_font_size_override("font_size",21)

func local_owner() -> int:
	return sim.view_owner if sim!=null else online.local_owner()

func online_mission_config() -> Dictionary:
	var config:=online.mission_config.duplicate(true) if online.active else {}
	config.merge({"mission":str(db.mission.get("id","")),"faction":faction,"difficulty":difficulty,"tech_level":int(campaign_progress.tech_level),"host_nickname":str(commander_profile.data.nickname),"game_version":str(update_history.get("current_version","unbekannt"))},true)
	if not config.has("mode"): config.mode=lobby_mode
	return config

func _refresh_online_lobby() -> void:
	if is_instance_valid(overlay) and overlay.get_node_or_null("OnlineLobbyPanel")!=null: show_online_menu()

func show_online_menu() -> void:
	var draft:=chat_input.text if is_instance_valid(chat_input) else ""
	clear(overlay)
	var lobby_size := Vector2(1300, 870) if online.active else Vector2(1100, 940)
	var viewport_size := get_viewport_rect().size
	var lobby_scale := minf(1.0, minf(viewport_size.x / lobby_size.x, viewport_size.y / lobby_size.y))
	var lobby_position := (viewport_size - lobby_size * lobby_scale) * 0.5
	# Keep the title screen from bleeding through this large, text-heavy dialog.
	var p:=panel(overlay,Rect2(lobby_position,lobby_size),Color(0.055,0.075,0.07,1.0))
	p.scale = Vector2.ONE * lobby_scale
	p.name="OnlineLobbyPanel"
	label(p,"SOLARIT: RANDSEKTOR 07 / MULTIPLAYER",Vector2(38,24),18,MINT)
	label(p,"1:1-Duell & Koop",Vector2(38,54),38,GOLD)
	label(p,"Duell: eigene Basis und Solarit · gleicher Start · kein KI-Spieler. Koop: gemeinsam gegen die KI.",Vector2(40,113),17,Color("d5ded5"),1210)
	if not online.active:
		online_server_status_label = label(p, "SERVERSTATUS  ·  " + online_server_status_text, Vector2(40, 139), 14, MINT, 760)
		button(p, "STATUS PRÜFEN", Rect2(835, 130, 215, 36), func(): _check_online_server_status(true))
		label(p, "EINSATZNETZ", Vector2(40, 164), 14, MUTED)
		label(p, "Wähle deinen Einstieg in den Einsatz.", Vector2(40, 185), 17, Color("d5ded5"))
		var duel := button(p, "1:1-DUELL\nZwei Kommandanten · gleicher Start", Rect2(40, 219, 495, 76), func(): lobby_mode = "versus"; show_online_menu())
		var coop := button(p, "KOOPERATION\nGemeinsam gegen die KI", Rect2(555, 219, 505, 76), func(): lobby_mode = "coop"; show_online_menu())
		for choice in [duel, coop]:
			choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
			choice.add_theme_font_size_override("font_size", 16)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.20,0.15,0.10,0.86) if (choice == duel and lobby_mode == "versus") or (choice == coop and lobby_mode == "coop") else Color(0.025,0.04,0.04,0.42)
			style.border_color = GOLD if (choice == duel and lobby_mode == "versus") or (choice == coop and lobby_mode == "coop") else Color(0.25,0.39,0.37,0.38)
			style.border_width_left = 3 if (choice == duel and lobby_mode == "versus") or (choice == coop and lobby_mode == "coop") else 0
			style.border_width_bottom = 1
			style.content_margin_left = 16
			choice.add_theme_stylebox_override("normal", style)
		label(p,"NETZWERK / DIREKTVERBINDUNG",Vector2(40,318),13,MINT)
		var publish_toggle := CheckBox.new()
		publish_toggle.name = "PublishPublicLobby"
		publish_toggle.text = "Öffentliche Lobby veröffentlichen"
		publish_toggle.position = Vector2(40, 344)
		publish_toggle.size = Vector2(480, 38)
		publish_toggle.add_theme_color_override("font_color", Color("d5ded5"))
		p.add_child(publish_toggle)
		var publish_hint := label(p,"Nur mit Häkchen erscheint deine Lobby bis zu 75 Sekunden in der öffentlichen Liste. UDP %d zum Spiele-PC weiterleiten." % OnlineSession.DEFAULT_PORT,Vector2(40,393),13,MUTED,1010)
		publish_hint.name = "PublicLobbyHint"
		label(p,"LOBBY-PASSWORT · ALS HOST FESTLEGEN, ALS GAST EINGEBEN",Vector2(40,418),13,MINT)
		var lobby_password := LineEdit.new()
		lobby_password.name = "LobbyPassword"
		lobby_password.position = Vector2(40,441); lobby_password.size = Vector2(1010,40)
		lobby_password.placeholder_text = "Passwort für private Lobby (mindestens 8 Zeichen)"
		lobby_password.secret = true; lobby_password.max_length = 128
		lobby_password.text = private_lobby_password
		lobby_password.tooltip_text = "Dieses Passwort gibst du nur direkt an Mitspieler weiter. Empfehlung: mindestens 12 Zeichen."
		p.add_child(lobby_password)
		lobby_password.text_changed.connect(func(value: String): private_lobby_password = value)
		publish_toggle.toggled.connect(func(is_public: bool): lobby_password.editable = not is_public)
		lobby_password.editable = not publish_toggle.button_pressed
		label(p,"Private Spieler benötigen Host-IP und Passwort. Öffentliche Lobbys verwenden keinen Passwortschutz.",Vector2(40,485),13,MUTED,1010)
		label(p,"DEINE LOKALE IP (HEIMNETZ)",Vector2(40,513),13,MUTED)
		var local_address := _local_ipv4_address()
		var local_copy_text := local_address + "  ·  KOPIEREN" if local_address_button_enabled(local_address) else local_address
		var local_address_button := button(p,local_copy_text,Rect2(40,537,495,40),func(): DisplayServer.clipboard_set(local_address))
		local_address_button.name = "LocalAddressCopy"
		local_address_button.disabled = not local_address_button_enabled(local_address)
		local_address_button.tooltip_text = "Lokale IPv4-Adresse in die Zwischenablage kopieren. Nur im eigenen Heimnetz erreichbar."
		label(p,"DEINE EXTERNE IP (INTERNET)",Vector2(555,513),13,MUTED)
		online_public_address_button = button(p,_public_address_button_text(),Rect2(555,537,416,40),func():
			if not online_public_address.is_empty(): DisplayServer.clipboard_set(online_public_address))
		online_public_address_button.name = "PublicAddressCopy"
		online_public_address_button.disabled = online_public_address.is_empty()
		online_public_address_button.tooltip_text = "Die öffentliche IPv4 wird nur für diese Abfrage an den Online-Dienst übermittelt und dort nicht gespeichert."
		var refresh_public_address := button(p,"NEU",Rect2(979,537,71,40),_request_online_public_address)
		refresh_public_address.name = "RefreshPublicAddress"
		refresh_public_address.tooltip_text = "Externe IP erneut abfragen"
		label(p,"HOST-IP ODER EINLADUNGSCODE / DIREKT BEITRETEN",Vector2(40,589),13,MUTED)
		var address:=LineEdit.new()
		address.name="OnlineAddress"; address.text=online.reconnect_address
		address.placeholder_text="Host-IP oder Hostname"
		address.tooltip_text="Host-IP oder Hostname eingeben. Für eine private Lobby auch das vereinbarte Passwort angeben. Über das Internet muss UDP %d zum Host-PC weitergeleitet sein." % OnlineSession.DEFAULT_PORT
		address.position=Vector2(40,613); address.size=Vector2(1010,42); p.add_child(address)
		var create_host := button(p,"SPIEL ERSTELLEN  /  HOST",Rect2(40,663,495,46),func():
			var private_secret := PrivateLobbyCode.password_secret(private_lobby_password)
			if not publish_toggle.button_pressed and private_secret.is_empty():
				notify("Lege für eine private Lobby ein Passwort mit mindestens 8 Zeichen fest.")
				return
			var result:=online.host()
			if result!=OK: online_status_text="Host konnte nicht starten (%d)."%result; show_online_menu(); return
			if not publish_toggle.button_pressed: online.required_invite_secret = private_secret
			var config := online_mission_config()
			online.configure_lobby(config)
			public_lobby_closed_for_guest = false
			public_lobby_requested = publish_toggle.button_pressed
			if not public_lobby_requested: _request_online_public_address()
			if publish_toggle.button_pressed and is_instance_valid(online_directory):
				online_directory_message = "Lobby wird veröffentlicht …"
				online_directory.publish_lobby(str(commander_profile.data.profile_id),str(commander_profile.data.nickname),str(config.get("mode", lobby_mode)),str(config.get("mission", db.mission.get("id", ""))),str(db.mission.get("display_name", db.mission.get("name", "Einsatz"))),OnlineSession.DEFAULT_PORT)
			show_online_menu())
		create_host.name = "CreateOnlineHost"
		var join_client := button(p,"SPIEL BEITRETEN  /  CLIENT",Rect2(555,663,495,46),func():
			var target_address := address.text.strip_edges()
			var target_port := online.reconnect_port
			var invite_secret := PrivateLobbyCode.password_secret(private_lobby_password) if not private_lobby_password.is_empty() else ""
			if not private_lobby_password.is_empty() and invite_secret.is_empty():
				notify("Das Lobby-Passwort muss mindestens 8 Zeichen haben.")
				return
			var result:=online.join(target_address,target_port,invite_secret)
			if result!=OK: online_status_text="Verbindung fehlgeschlagen (%d)."%result
			show_online_menu())
		join_client.name = "JoinOnlineClient"
		join_client.disabled = address.text.strip_edges().is_empty()
		address.text_changed.connect(func(value: String): join_client.disabled = value.strip_edges().is_empty())
		join_client.tooltip_text = "Verbindet mit der Host-IP. Für private Lobbys zusätzlich das Passwort im Passwortfeld eingeben."
		label(p,"ÖFFENTLICHE LOBBYS",Vector2(40,727),14,MINT)
		var refresh_lobbies := button(p,"LOBBYS AKTUALISIEREN",Rect2(790,716,260,38),func():
			_check_online_lobbies()
			show_online_menu())
		refresh_lobbies.name = "RefreshPublicLobbies"
		online_directory_empty_state = label(p, _online_directory_empty_text(), Vector2(58, 762), 17, MUTED, 970)
		online_directory_empty_state.name = "OnlineDirectoryEmptyState"
		online_directory_empty_state.size = Vector2(970, 50)
		online_directory_empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		online_directory_empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		online_directory_empty_state.visible = _last_public_lobbies.is_empty()
		online_directory_items = ItemList.new()
		online_directory_items.name = "OnlineDirectoryList"
		online_directory_items.position = Vector2(40, 762)
		online_directory_items.size = Vector2(1010, 50)
		online_directory_items.select_mode = ItemList.SELECT_SINGLE
		online_directory_items.visible = not _last_public_lobbies.is_empty()
		p.add_child(online_directory_items)
		online_directory_status_label = label(p,_online_directory_status_text(),Vector2(40,822),13,MUTED,1010)
		online_directory_status_label.name = "OnlineDirectoryStatus"
		var join_lobby := button(p,"AUSGEWÄHLTE LOBBY BEITRETEN",Rect2(700,816,350,42),func():
			if online_directory_selected.is_empty(): return
			var entry := online_directory_selected
			var result := online.join(str(entry.get("address", "")), int(entry.get("port", OnlineSession.DEFAULT_PORT)))
			if result != OK: online_status_text = "Verbindung fehlgeschlagen (%d)." % result
			show_online_menu())
		join_lobby.name = "JoinPublicLobby"
		join_lobby.disabled = online_directory_selected.is_empty()
		online_directory_items.item_selected.connect(_on_online_directory_item_selected)
		for entry in _last_public_lobbies:
			_add_online_directory_entry(entry)
		join_lobby.disabled = online_directory_selected.is_empty()
		if online_directory_items.item_count == 0 and online_directory_message == "Noch nicht geladen":
			_check_online_lobbies()
		_check_online_server_status()
		if not online_public_address_checked:
			_request_online_public_address()
	else:
		if online.is_client(): online.set_nickname(str(commander_profile.data.nickname))
		var config:=online.mission_config
		var host_game_version := str(config.get("game_version", "unbekannt"))
		online_status_label=label(p,"HOSTVERSION v%s  ·  %s" % [host_game_version,online_status_text],Vector2(40,157),18,MINT,1190)
		if online.is_host() and public_lobby_requested:
			label(p,"ÖFFENTLICHE LOBBY  ·  " + online_directory_message,Vector2(40,184),13,MINT,1200)
		elif online.is_host():
			var external_copy_text := "HOST-IP  ·  %s  ·  KOPIEREN" % online_public_address if not online_public_address.is_empty() else "HOST-IP  ·  EXTERNE IP WIRD ERMITTELT …"
			var external_copy := button(p,external_copy_text,Rect2(40,179,590,34),func():
				if online_public_address.is_empty(): return
				DisplayServer.clipboard_set(online_public_address)
				notify("Host-IP kopiert."))
			external_copy.name = "PrivateLobbyHostAddressCopy"
			external_copy.alignment = HORIZONTAL_ALIGNMENT_LEFT
			external_copy.add_theme_font_size_override("font_size",15)
			external_copy.disabled = online_public_address.is_empty()
			external_copy.tooltip_text = "Diese externe IP zusammen mit UDP-Port %d und dem Lobby-Passwort an Mitspieler weitergeben." % OnlineSession.DEFAULT_PORT
			var password_copy := button(p,"LOBBY-PASSWORT  ·  KOPIEREN",Rect2(650,179,600,34),func():
				DisplayServer.clipboard_set(private_lobby_password)
				notify("Lobby-Passwort kopiert."))
			password_copy.name = "PrivateLobbyPasswordCopy"
			password_copy.alignment = HORIZONTAL_ALIGNMENT_LEFT
			password_copy.add_theme_font_size_override("font_size",15)
			password_copy.disabled = private_lobby_password.is_empty()
			password_copy.tooltip_text = "Teile das Passwort nur mit den eingeladenen Spielern."
		var prefix: String="host" if online.is_host() else "client"
		label(p,"DEINE FRAKTION / FARBE",Vector2(40,213),14,MUTED)
		var factions:=OptionButton.new()
		factions.name="OnlineFaction"; factions.position=Vector2(40,240); factions.size=Vector2(265,44)
		for item in OnlineSession.FACTIONS:
			factions.add_item(str(db.factions[item].name))
			factions.set_item_tooltip(factions.item_count - 1, str(db.factions[item].description))
		factions.select(maxi(0,OnlineSession.FACTIONS.find(str(config.get(prefix+"_faction","forge")))))
		var colors:=OptionButton.new()
		colors.name="OnlineColor"; colors.position=Vector2(320,240); colors.size=Vector2(270,44)
		var color_names:=["Cyan","Rot","Violett","Blau","Gelb","Grün","Rosa","Elfenbein"]
		for index in color_names.size():
			colors.add_item(color_names[index])
			var swatch:=Image.create(18,18,false,Image.FORMAT_RGBA8)
			swatch.fill(Color(OnlineSession.COLORS[index]))
			colors.set_item_icon(index,ImageTexture.create_from_image(swatch))
			var occupied_color := str(config.get("client_color" if online.is_host() else "host_color", ""))
			if OnlineSession.COLORS[index] == occupied_color and OnlineSession.COLORS[index] != str(config.get(prefix+"_color", "")): colors.set_item_disabled(index, true)
		colors.select(maxi(0,OnlineSession.COLORS.find(str(config.get(prefix+"_color",OnlineSession.COLORS[0])))))
		factions.disabled=online.mission_started; colors.disabled=online.mission_started
		factions.item_selected.connect(func(index):online.set_profile(OnlineSession.FACTIONS[index],OnlineSession.COLORS[colors.selected]))
		colors.item_selected.connect(func(index):online.set_profile(OnlineSession.FACTIONS[factions.selected],OnlineSession.COLORS[index]))
		p.add_child(factions); p.add_child(colors)
		label(p,"KARTE / STARTSOLARIT",Vector2(620,213),14,MUTED)
		var maps:=OptionButton.new()
		maps.name="OnlineMap"; maps.position=Vector2(620,240); maps.size=Vector2(360,44)
		for path in MISSION_PATHS: maps.add_item(str(Catalog.new(path).mission.get("display_name","Einsatz")))
		maps.select(maxi(0,mission_index_for_id(str(config.get("mission","")))))
		maps.disabled=not online.is_host() or online.mission_started
		maps.item_selected.connect(func(index):
			mission_index=index; db=Catalog.new(MISSION_PATHS[index])
			online.configure_lobby(online_mission_config()))
		p.add_child(maps)
		var credits:=OptionButton.new()
		credits.name="OnlineCredits"; credits.position=Vector2(995,240); credits.size=Vector2(255,44)
		var amounts: Array=[2000,4200,6000,10000]
		for amount in amounts: credits.add_item("%d Solarit"%amount)
		credits.select(maxi(0,amounts.find(int(config.get("start_credits",4200)))))
		credits.disabled=not online.is_host() or online.mission_started
		credits.item_selected.connect(func(index):
			var changed:=online.mission_config.duplicate(true); changed.start_credits=amounts[index]; online.configure_lobby(changed))
		p.add_child(credits)
		var host_name:=PlayerProfileScript.sanitize_network_nickname(str(config.get("host_nickname","Kommandant")))
		var guest_name:=PlayerProfileScript.sanitize_network_nickname(str(config.get("client_nickname","Kommandant")))
		var host_faction_name:=str(db.factions.get(str(config.get("host_faction","forge")),{}).get("name","Fraktion"))
		var guest_faction_name:=str(db.factions.get(str(config.get("client_faction","drift")),{}).get("name","Fraktion"))
		label(p,"EINSATZGRUPPE",Vector2(40,300),14,MINT)
		label(p,"01  %s  ·  HOST\n     %s   /   %s\n     %s"%[host_name,host_faction_name,lobby_color_label(str(config.get("host_color",""))),"✓ BEREIT" if online.host_ready else "○ NICHT BEREIT"],Vector2(40,327),17,Color("d7dfd5"),540)
		label(p,"02  %s\n     %s   /   %s\n     %s"%[guest_name if online.connected else "WARTET AUF MITSPIELER ...",guest_faction_name if online.connected else "—",lobby_color_label(str(config.get("client_color",""))) if online.connected else "",("✓ BEREIT" if online.guest_ready else "○ NICHT BEREIT") if online.connected else "○ OFFEN"],Vector2(430,327),17,Color("d7dfd5"),390)
		var current_map_preview := MissionTacticalPreview.new()
		current_map_preview.name = "OnlineMapPreview"
		current_map_preview.position = Vector2(850, 307)
		current_map_preview.size = Vector2(370, 84)
		current_map_preview.mission_data = db.mission
		current_map_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(current_map_preview)
		var ready_label:="BEREITSCHAFT ZURÜCKNEHMEN" if (online.host_ready if online.is_host() else online.guest_ready) else "BEREIT"
		var ready:=button(p,ready_label,Rect2(40,400,550,52),func():online.set_ready(not (online.host_ready if online.is_host() else online.guest_ready)))
		ready.disabled=online.mission_started or not online.connected
		if online.is_host():
			var launch:=button(p,"EINSATZ STARTEN",Rect2(620,400,630,52),start_game)
			launch.disabled=not online.can_start() or online.mission_started
			var launch_reason:="EINSATZ STARTEN" if online.can_start() else ("WARTET AUF MITSPIELER" if not online.connected else ("SPIELER 2 IST NICHT BEREIT" if not online.guest_ready else "HOST MUSS BEREIT SEIN"))
			label(p,launch_reason,Vector2(626,457),13,MUTED,610)
		build_online_chat(p,Rect2(40,485,1210,245),true)
		chat_input.text=draft
	var disconnect_button := button(p,"VERBINDUNG TRENNEN",Rect2(40,lobby_size.y-82,280,42),func():
		if is_instance_valid(online_directory): online_directory.close_lobby()
		public_lobby_requested = false
		private_lobby_password = ""
		online.leave()
		show_main_menu())
	disconnect_button.name = "DisconnectOnline"
	var back_button := button(p,"ZURÜCK",Rect2(340,lobby_size.y-82,250,42),func():clear(overlay))
	back_button.name = "BackOnline"

func lobby_color_label(color_code: String) -> String:
	var color_names := {"19ddd4": "CYAN", "f34c32": "ROT", "b967ef": "VIOLETT", "408bf4": "BLAU", "f1c744": "GELB", "74ce47": "GRÜN", "f478bf": "ROSA", "eee0bc": "ELFENBEIN"}
	return "■ " + str(color_names.get(color_code.to_lower(), "FARBE"))

func build_online_chat(parent: Control, rect: Rect2, expanded: bool) -> void:
	chat_box=panel(parent,rect,Color("151e1c",0.95))
	chat_box.name="OnlineChat"; chat_box.visible=expanded; chat_box.z_index=90
	label(chat_box,"/ EINSATZKANAL · ENTER SENDEN · ESC FOKUS LÖSEN",Vector2(14,10),14,MINT)
	chat_log=RichTextLabel.new()
	chat_log.name="ChatHistory"; chat_log.position=Vector2(14,38); chat_log.size=Vector2(rect.size.x-28,rect.size.y-104)
	chat_log.bbcode_enabled=false; chat_log.scroll_following=true
	chat_box.add_child(chat_log)
	chat_input=LineEdit.new()
	chat_input.name="ChatInput"; chat_input.max_length=300
	chat_input.placeholder_text="Nachricht an den anderen Spieler …"
	chat_input.position=Vector2(14,rect.size.y-52); chat_input.size=Vector2(rect.size.x-150,38)
	chat_box.add_child(chat_input)
	chat_input.text_submitted.connect(func(text):
		if online.send_chat(text): chat_input.clear()
		else: notify("Chat: kurze Nachricht eingeben oder einen Moment warten."))
	chat_input.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			chat_input.release_focus()
			if playing: chat_box.visible=false
			chat_input.accept_event())
	button(chat_box,"SENDEN",Rect2(rect.size.x-124,rect.size.y-52,110,38),func():chat_input.text_submitted.emit(chat_input.text))
	refresh_chat()

func refresh_chat() -> void:
	if not is_instance_valid(chat_log): return
	chat_log.clear()
	for entry in online.chat_history:
		var sender:=str(entry.get("sender","SYSTEM"))
		var stamp:=Time.get_time_string_from_system().substr(0,5) if not entry.has("time") else str(entry.time)
		chat_log.push_color(MUTED); chat_log.add_text(stamp+"  ")
		chat_log.push_color(MINT if sender=="SYSTEM" else GOLD); chat_log.add_text(sender)
		chat_log.push_color(Color("d4ddd7")); chat_log.add_text("\n"+str(entry.get("message",""))+"\n")
		chat_log.pop()
		chat_log.pop()
		chat_log.pop()

func _on_online_chat(_sender: String, _message: String) -> void:
	refresh_chat()
	if playing and is_instance_valid(chat_box): chat_box.visible=true

func toggle_chat() -> void:
	if not is_instance_valid(chat_box): return
	chat_box.visible=true
	chat_input.grab_focus()

func _on_online_status_changed(message: String) -> void:
	if playing and sim!=null and sim.online_mode=="versus" and not online.active:
		paused=true
		show_online_menu()
	online_status_text=message
	if is_instance_valid(online_status_label):
		var host_version := str(online.mission_config.get("game_version", "unbekannt")) if online.active else ""
		online_status_label.text="HOSTVERSION v%s  ·  %s" % [host_version,message] if not host_version.is_empty() else message
	if playing: notify(message)
	if is_instance_valid(overlay) and overlay.get_node_or_null("OnlineLobbyPanel")!=null: show_online_menu()

func _check_online_server_status(force: bool = false) -> void:
	if not is_instance_valid(online_stats):
		online_server_status_text = "NICHT GEPRÜFT · ONLINE-STATISTIK AUS"
		online_server_status_online = false
		if is_instance_valid(online_server_status_label): online_server_status_label.text = "SERVERSTATUS  ·  " + online_server_status_text
		return
	var now := Time.get_ticks_msec()
	if not force and online_server_status_checked_at > 0 and now - online_server_status_checked_at < 30000: return
	online_server_status_checked_at = now
	online_server_status_text = "PRÜFE API …"
	if is_instance_valid(online_server_status_label): online_server_status_label.text = "SERVERSTATUS  ·  " + online_server_status_text
	online_stats.check_server_status()

var _last_public_lobbies: Array = []

func _check_online_lobbies() -> void:
	online_directory_refresh_elapsed = 0.0
	online_directory_last_check_msec = Time.get_ticks_msec()
	if not is_instance_valid(online_directory):
		online_directory_loading = false
		online_directory_message = "Lobby-Dienst nicht verfügbar"
		_refresh_online_directory_view()
		return
	online_directory_loading = true
	online_directory_message = "Suche aktive Lobbys …"
	_refresh_online_directory_view()
	online_directory.list_lobbies()

func _on_online_lobbies_received(entries: Array, message: String) -> void:
	online_directory_loading = false
	_last_public_lobbies = entries.duplicate(true)
	online_directory_snapshot_ticks_msec = Time.get_ticks_msec()
	online_directory_last_refresh = Time.get_time_string_from_system().substr(0, 5)
	if not message.is_empty():
		online_directory_message = message
	elif entries.is_empty():
		online_directory_message = "Keine offenen öffentlichen Lobbys"
	else:
		online_directory_message = "%d offene %s" % [entries.size(), "Lobby" if entries.size() == 1 else "Lobbys"]
	online_directory_selected.clear()
	if is_instance_valid(overlay) and overlay.get_node_or_null("OnlineLobbyPanel") != null:
		show_online_menu()
	else:
		_refresh_online_directory_view()

func _on_online_directory_status(message: String) -> void:
	online_directory_message = message
	_refresh_online_directory_view()
	if is_instance_valid(overlay) and overlay.get_node_or_null("OnlineLobbyPanel") != null:
		show_online_menu()

func _online_directory_status_text() -> String:
	if online_directory_loading:
		return "Suche aktive Lobbys · Aktualisierung alle %d s …" % int(ONLINE_DIRECTORY_REFRESH_SECONDS)
	var stale_count := 0
	for entry in _last_public_lobbies:
		if entry is Dictionary and _online_lobby_seconds_remaining(entry) <= 0:
			stale_count += 1
	if stale_count == _last_public_lobbies.size() and stale_count > 0:
		return "%d veraltete %s · aktualisiere automatisch alle %d s" % [stale_count, "Lobby" if stale_count == 1 else "Lobbys", int(ONLINE_DIRECTORY_REFRESH_SECONDS)]
	if not online_directory_last_refresh.is_empty():
		return "%s  ·  letzte Suche %s Uhr  ·  automatische Suche alle %d s" % [online_directory_message, online_directory_last_refresh, int(ONLINE_DIRECTORY_REFRESH_SECONDS)]
	return online_directory_message

func _online_directory_empty_text() -> String:
	if online_directory_loading:
		return "Suche aktive Lobbys …"
	if not _last_public_lobbies.is_empty():
		return ""
	if online_directory_message in ["Noch nicht geladen", "Keine offenen öffentlichen Lobbys"]:
		return "Keine offene Lobby gefunden.\nAls Host kannst du oben eine Lobby veröffentlichen."
	return online_directory_message

func _refresh_online_directory_view() -> void:
	if is_instance_valid(online_directory_status_label):
		online_directory_status_label.text = _online_directory_status_text()
	if is_instance_valid(online_directory_empty_state):
		online_directory_empty_state.text = _online_directory_empty_text()
		online_directory_empty_state.visible = _last_public_lobbies.is_empty()
	if is_instance_valid(online_directory_items):
		online_directory_items.visible = not _last_public_lobbies.is_empty()
		_update_online_directory_rows()
	var join_button := overlay.get_node_or_null("OnlineLobbyPanel/JoinPublicLobby") as Button if is_instance_valid(overlay) else null
	if is_instance_valid(join_button):
		join_button.disabled = online_directory_selected.is_empty() or _online_lobby_is_stale(online_directory_selected) or not _online_lobby_version_matches(online_directory_selected)

func _add_online_directory_entry(entry: Dictionary) -> void:
	if not is_instance_valid(online_directory_items): return
	var index := online_directory_items.add_item(_online_lobby_line(entry))
	online_directory_items.set_item_metadata(index, entry.duplicate(true))
	online_directory_items.set_item_disabled(index, _online_lobby_is_stale(entry) or not _online_lobby_version_matches(entry))

func _online_lobby_seconds_remaining(entry: Dictionary) -> int:
	var remaining := int(entry.get("expires_in", ONLINE_DIRECTORY_LOBBY_TTL_SECONDS))
	if not entry.has("expires_in") and entry.has("last_seen"):
		remaining = ONLINE_DIRECTORY_LOBBY_TTL_SECONDS - maxi(0, int(Time.get_unix_time_from_system()) - int(entry.last_seen))
	var elapsed := maxi(0, Time.get_ticks_msec() - online_directory_snapshot_ticks_msec) / 1000
	return maxi(0, remaining - elapsed)

func _online_lobby_is_stale(entry: Dictionary) -> bool:
	return _online_lobby_seconds_remaining(entry) <= 0

func _online_lobby_version_matches(entry: Dictionary) -> bool:
	return OnlineSession.game_versions_match(str(entry.get("game_version", "")), str(update_history.get("current_version", "")))

func _online_lobby_line(entry: Dictionary) -> String:
	var mode_name := "1:1-DUELL" if str(entry.get("mode", "")) == "versus" else "KOOP"
	var remaining := _online_lobby_seconds_remaining(entry)
	var age_seconds := ONLINE_DIRECTORY_LOBBY_TTL_SECONDS - remaining
	var freshness := "VERALTET · Host vor %d s zuletzt gesehen" % age_seconds
	if remaining > 0:
		var last_seen_text := "gerade eben" if age_seconds < 5 else "vor %d s" % age_seconds
		freshness = "%s · läuft in %d s ab" % [last_seen_text, remaining]
	var version_text := "HOST v%s" % str(entry.get("game_version", "unbekannt"))
	if not _online_lobby_version_matches(entry): version_text += " · ANDERE VERSION"
	return "%s  ·  %s  ·  %s  ·  %s  ·  %s:%s  ·  %s" % [str(entry.get("nickname", "Kommandant")), version_text, mode_name, str(entry.get("mission_name", "Einsatz")), str(entry.get("address", "")), str(entry.get("port", OnlineSession.DEFAULT_PORT)), freshness]

func _update_online_directory_rows() -> void:
	if not is_instance_valid(online_directory_items): return
	for index in online_directory_items.item_count:
		var entry: Variant = online_directory_items.get_item_metadata(index)
		if not entry is Dictionary: continue
		var stale := _online_lobby_is_stale(entry)
		var incompatible := not _online_lobby_version_matches(entry)
		online_directory_items.set_item_text(index, _online_lobby_line(entry))
		online_directory_items.set_item_disabled(index, stale or incompatible)
		if stale and not online_directory_selected.is_empty() and str(online_directory_selected.get("lobby_id", "")) == str(entry.get("lobby_id", "")):
			online_directory_selected.clear()
			online_directory_items.deselect(index)

func _on_online_directory_item_selected(index: int) -> void:
	if not is_instance_valid(online_directory_items): return
	var entry: Variant = online_directory_items.get_item_metadata(index)
	if entry is Dictionary and not _online_lobby_is_stale(entry) and _online_lobby_version_matches(entry):
		online_directory_selected = entry.duplicate(true)
		var join_button := overlay.get_node_or_null("OnlineLobbyPanel/JoinPublicLobby") as Button
		if is_instance_valid(join_button): join_button.disabled = false
	else:
		online_directory_selected.clear()
		var join_button := overlay.get_node_or_null("OnlineLobbyPanel/JoinPublicLobby") as Button
		if is_instance_valid(join_button): join_button.disabled = true
		if entry is Dictionary and not _online_lobby_version_matches(entry): notify("Versionskonflikt · Lobby nutzt v%s, installiert ist v%s" % [str(entry.get("game_version", "unbekannt")), str(update_history.get("current_version", "unbekannt"))])

func _on_public_lobby_published(ok: bool, message: String, address: String) -> void:
	if ok:
		online_directory_message = message + " · UDP %d muss weitergeleitet sein" % OnlineSession.DEFAULT_PORT
		_last_public_lobbies.clear()
	else:
		online_directory_message = "Nicht veröffentlicht · " + message
	if is_instance_valid(overlay) and overlay.get_node_or_null("OnlineLobbyPanel") != null:
		show_online_menu()

func _on_online_server_status(message: String, is_online: bool) -> void:
	online_server_status_text = message
	online_server_status_online = is_online
	if is_instance_valid(online_server_status_label):
		online_server_status_label.text = "SERVERSTATUS  ·  " + message
		online_server_status_label.add_theme_color_override("font_color", MINT if is_online else GOLD)

func _local_ipv4_address() -> String:
	var fallback := ""
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var parts := address.split(".")
		if parts.size() != 4:
			continue
		var first := int(parts[0])
		var second := int(parts[1])
		if (first == 10) or (first == 192 and second == 168) or (first == 172 and second >= 16 and second <= 31):
			return address
		if fallback.is_empty():
			fallback = address
	return fallback if not fallback.is_empty() else "Keine lokale IPv4-Adresse gefunden"

func local_address_button_enabled(address: String) -> bool:
	return address != "Keine lokale IPv4-Adresse gefunden"

func _public_address_button_text() -> String:
	if not online_public_address.is_empty():
		return online_public_address + "  ·  KOPIEREN"
	if not online_stats_enabled:
		return "Online-Abfrage deaktiviert"
	return "Externe IP wird ermittelt …" if not online_public_address_checked else "Externe IP nicht verfügbar"

func _request_online_public_address() -> void:
	if not is_instance_valid(online_stats) or not online_stats.enabled:
		online_public_address_checked = true
		if is_instance_valid(online_public_address_button):
			online_public_address_button.text = _public_address_button_text()
			online_public_address_button.disabled = true
		return
	online_public_address_checked = false
	if is_instance_valid(online_public_address_button):
		online_public_address_button.text = _public_address_button_text()
		online_public_address_button.disabled = true
	online_stats.request_public_address()

func _on_online_public_address_received(address: String, success: bool) -> void:
	online_public_address_checked = true
	online_public_address = address if success else ""
	if is_instance_valid(online_public_address_button):
		online_public_address_button.text = _public_address_button_text()
		online_public_address_button.disabled = online_public_address.is_empty()
	if online.is_host() and not public_lobby_requested:
		if is_instance_valid(overlay) and overlay.get_node_or_null("OnlineLobbyPanel") != null:
			show_online_menu()

func _advance_online_directory(delta: float) -> void:
	if not is_instance_valid(overlay) or overlay.get_node_or_null("OnlineLobbyPanel") == null or online.active:
		online_directory_refresh_elapsed = 0.0
		online_directory_display_elapsed = 0.0
		return
	if not is_instance_valid(online_directory) or not online_directory.enabled:
		return
	online_directory_display_elapsed += delta
	if online_directory_display_elapsed >= 1.0:
		online_directory_display_elapsed = fmod(online_directory_display_elapsed, 1.0)
		_refresh_online_directory_view()
	if online_directory_loading or online_directory.active or not online_directory.queue.is_empty():
		return
	online_directory_refresh_elapsed += delta
	if online_directory_refresh_elapsed >= ONLINE_DIRECTORY_REFRESH_SECONDS:
		_check_online_lobbies()

func _on_online_game_start(config: Dictionary) -> void:
	var index:=mission_index_for_id(str(config.get("mission","")))
	if index<0: online.leave(); notify("Online-Einsatz nicht verfügbar: Missionsdaten stimmen nicht überein."); return
	mission_index=index
	faction=str(config.get("faction",faction))
	difficulty=str(config.get("difficulty",difficulty))

	db=Catalog.new(MISSION_PATHS[mission_index])
	start_game()

func _on_online_world_snapshot(snapshot: Dictionary) -> void:
	if not online.is_client() or sim==null: return
	if sim.restore(snapshot)!=OK:
		online.leave(); notify("Online-Spielstand ungültig · Verbindung beendet."); return
	match_recorder.observe(sim)
	render_previous=render_current
	render_current=capture_render_state()
	network_blend=0.0
	accumulator=0.0
	update_hud()
	if sim.result!="" and not ended: ended=true; show_end()

func start_game() -> void:
	intro_active=false
	if online.is_host() and not online.mission_started and not online.can_start(): return
	sim=Simulation.new(db,faction,difficulty,int(campaign_progress.tech_level))
	if online.active and online.is_versus():
		sim.configure_versus(online.mission_config,online.local_owner())
		if online.is_client(): sim.restore(sim.snapshot_for(1))
	if online.is_host() and not online.mission_started: online.begin_mission(online_mission_config())
	run_id=create_run_id()
	if online.active: run_id="online:"+online.session_id+":"+str(online.mission_sequence)
	if is_instance_valid(online_stats): online_stats.begin_playing()
	match_report_saved=false
	var player_side:=local_owner()
	var opponent_name:="Gegner-KI"
	if online.active and sim.online_mode=="versus":
		opponent_name=str(online.mission_config.get("client_nickname" if online.is_host() else "host_nickname", "Gegner"))
	var side_names: Array[String]=[]
	if player_side==0:
		side_names.append(str(commander_profile.data.nickname)); side_names.append(opponent_name)
	else:
		side_names.append(opponent_name); side_names.append(str(commander_profile.data.nickname))
	match_recorder.begin(sim,{
		"match_id":run_id,
		"game_version":str(update_history.get("current_version", "unbekannt")),
		"mode":"duel" if sim.online_mode=="versus" else ("coop" if online.active else "singleplayer"),
		"side_0_nickname":side_names[0],
		"side_1_nickname":side_names[1]
	})
	render_previous=capture_render_state(); render_current=render_previous.duplicate(true)
	connect_sim()
	selected=[]; groups={}; ended=false; accumulator=0; production_target_factory_id=0
	right_held=false; right_panning=false; middle_drag=false; harvest_mode=false
	var cores:=sim.buildings(local_owner(),"core")
	renderer.camera=cores[0].pos if not cores.is_empty() else Vector2(320,320)
	renderer.zoom=1.25
	clamp_camera()
	playing=true; paused=false; placement=""; renderer.placement=""
	online.set_authority(sim)
	clear(overlay)
	view_container.visible=true
	build_hud()
	music.start(sim)
	music.cue("complete")
	save_game("user://autosave.json",false)
	notify("1:1-Duell begonnen. Beide Spieler starten gleich. Zerstöre den feindlichen Baukern." if sim.online_mode=="versus" else str(db.mission.get("start_message","Einsatz begonnen.")))

func connect_sim() -> void:
	inspected=0
	renderer.sim=sim
	renderer.combat_fx.reset()
	renderer.preserve_loaded_visuals=false
	sim.presentation.connect(on_presentation)
	renderer.visual_bursts.clear()
	sim.event.connect(on_event)

func build_hud() -> void:
	clear(ui)
	buttons.clear()
	var top := panel(ui,Rect2(20,16,1880,64))
	label(top,"SOLARIT",Vector2(18,4),11,MUTED)
	status=label(top,"",Vector2(18,21),21,Color("d8d1c4"),165)
	label(top,"ENERGIE / FREI",Vector2(203,4),11,MUTED)
	energy_label=label(top,"",Vector2(203,21),21,MINT,150)
	label(top,"ZEIT",Vector2(380,4),11,MUTED)
	mission_clock=label(top,"",Vector2(380,21),16,Color("d8d1c4"),95)
	status.size.y=30; energy_label.size.y=30; mission_clock.size.y=25
	status.tooltip_text="Solarit ist die Bau- und Produktionswährung. Energie zeigt Verbrauch / Erzeugung; Gebäudeüberlastung verlangsamt Bau und Fahrzeugmontage, pausiert Geschütze und Reparaturen. Schwere Fahrzeuge benötigen zusätzlich freie Energie zum Start der Montage."
	label(top,"AUFTRAG",Vector2(610,4),11,MUTED)
	objective=label(top,sim.hud_objective_text(),Vector2(610,23),15,Color("d8d1c4"),530)
	optional_objective=label(top,sim.optional_objective_progress_text() if not online.active else "",Vector2(610,44),11,MINT,560)
	fps_label=label(top,"FPS --",Vector2(1197,18),16,MINT,112)
	fps_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.tooltip_text="Bildrate live. Einbruchprotokoll ab 60 FPS: performance_events_v2.csv (unter Windows im Godot-Appdatenordner)."
	button(top,"PAUSE / ESC",Rect2(1695,8,166,40),show_pause)
	var side := panel(ui,Rect2(1570,86,330,944))
	side_panel=side
	minimap=TacticalMap.new()
	minimap.position=Vector2(1400,820); minimap.size=Vector2(164,138); minimap.sim=sim
	minimap.navigate.connect(func(point):renderer.camera=point; clamp_camera())
	ui.add_child(minimap)
	radar_caption=label(side,"RADAR OFFLINE",Vector2(18,12),11,MUTED,120)
	radar_caption.tooltip_text="Signalstation errichten und mit Energie versorgen, um den Radar zu aktivieren."
	information=label(side,"",Vector2(76,30),13,Color("cbd9d0"),236)
	information.mouse_filter=Control.MOUSE_FILTER_STOP
	information.tooltip_text="Anklicken: technische Daten und Reparatur"
	information.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: show_entity_details())
	details_button=button(top,"OBJEKTINFO",Rect2(1330,8,160,40),func():
		if placement!="": rotate_placement(1)
		else: show_entity_details())
	repair_button=button(top,"REPARIEREN · R",Rect2(1498,8,180,40),repair_selection)
	details_button.add_theme_font_size_override("font_size",14)
	repair_button.add_theme_font_size_override("font_size",14)
	var build_tab := button(side,"BAU",Rect2(18,118,92,38),func():category="buildings"; build_hud())
	var unit_tab := button(side,"FAHRZEUGE",Rect2(116,118,92,38),func():category="units"; build_hud())
	var production_tab := button(side,"PRODUKTION",Rect2(214,118,92,38),func():category="production"; build_hud())
	build_tab.add_theme_font_size_override("font_size",14)
	for tab in [build_tab,unit_tab,production_tab]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var tab_style: StyleBoxFlat=tab.get_theme_stylebox(state).duplicate()
			tab_style.content_margin_left=4; tab_style.content_margin_right=4
			tab.add_theme_stylebox_override(state,tab_style)
	unit_tab.add_theme_font_size_override("font_size",11)
	production_tab.add_theme_font_size_override("font_size",11)
	var active_tab: Button = build_tab if category=="buildings" else (unit_tab if category=="units" else production_tab)
	var active_style: StyleBoxFlat = active_tab.get_theme_stylebox("normal").duplicate()
	active_style.border_color=GOLD; active_style.border_width_bottom=3
	active_tab.add_theme_stylebox_override("normal",active_style)
	active_tab.add_theme_color_override("font_color",GOLD)
	selection_icons=Control.new()
	selection_icons.mouse_filter=Control.MOUSE_FILTER_IGNORE
	side.add_child(selection_icons); selection_signature=""
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.name="CatalogScroll"
	catalog_scroll.position=Vector2(18,168)
	catalog_scroll.size=Vector2(294,744)
	catalog_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	catalog_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	catalog_scroll.mouse_filter=Control.MOUSE_FILTER_PASS
	side.add_child(catalog_scroll)
	var catalog_content := Control.new()
	catalog_content.custom_minimum_size=Vector2(274,0)
	catalog_scroll.add_child(catalog_content)
	production_content=catalog_content if category=="production" else null
	var y := 0
	var catalog_count := 0
	production_rows.clear()
	production_empty_label=null
	production_signature=""
	if category=="production":
		var factories:=sim.buildings(local_owner(),"factory",false)
		factories.sort_custom(func(a,b):return int(a.id)<int(b.id))
		if factories.is_empty():
			production_empty_label=label(catalog_content,"KEINE FAHRZEUGWERFT\n\nErrichte im Tab Bau eine Fahrzeugwerft. Dort werden alle Fahrzeuge montiert.",Vector2(6,10),15,MUTED,302)
			production_empty_label.size.y=125
			production_signature=""
	else:
		if category=="units":
			var target_text: String="AUTOMATIK · KÜRZESTE WARTESCHLANGE"
			if production_target_factory_id>0 and sim.entities.has(production_target_factory_id):
				target_text="ZIELWERFT %02d · HIER EINREIHEN"%production_factory_number(production_target_factory_id)
			var target_banner:=label(catalog_content,target_text,Vector2(4,2),11,MINT if production_target_factory_id>0 else MUTED,266)
			target_banner.size.y=22
			target_banner.tooltip_text="Im Tab Produktion eine Werft auswählen. Neue Fahrzeuge werden dann gezielt dort eingereiht."
			y=25
		var table: Dictionary = db.buildings if category=="buildings" else db.units
		for id in table:
			if id=="core": continue
			catalog_count+=1
			var d: Dictionary = table[id]
			var b := button(catalog_content,"",Rect2(0,y,274,72),func():catalog_click(id,false))
			b.clip_contents=true
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size",12)
			for state in ["normal","hover","pressed","disabled","focus"]:
				var style: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
				style.content_margin_left=61
				style.content_margin_right=76 if category=="units" else 5
				b.add_theme_stylebox_override(state,style)
			var icon := IndustrialThumbnail.new()
			icon.name="CatalogArtwork"
			icon.sim=sim; icon.team_owner=local_owner(); icon.kind=id; icon.position=Vector2(6,10); icon.size=Vector2(47,46)
			icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(icon)
			var marker:=ColorRect.new()
			marker.position=Vector2.ZERO; marker.size=Vector2(3,72); marker.color=Color("9e524c"); marker.visible=false
			marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(marker); requirement_marks[id]=marker
			var activity_bar := ProgressBar.new()
			activity_bar.name="CatalogActivityBar"
			activity_bar.position=Vector2(61,61)
			activity_bar.size=Vector2(136,4) if category=="units" else Vector2(206,4)
			activity_bar.show_percentage=false
			activity_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
			activity_bar.visible=false
			activity_bar.add_theme_font_size_override("font_size",1)
			var activity_fill := StyleBoxFlat.new()
			activity_fill.bg_color=MINT
			activity_bar.add_theme_stylebox_override("fill",activity_fill)
			var activity_background := StyleBoxFlat.new()
			activity_background.bg_color=Color("18110c")
			activity_bar.add_theme_stylebox_override("background",activity_background)
			b.add_child(activity_bar)
			if category=="units":
				var minus:=button(b,"−",Rect2(201,5,24,25),catalog_adjust_quantity.bind(id,-1))
				minus.name="QtyMinus"
				minus.tooltip_text="1 entfernen"
				var qty:=label(b,"×0",Vector2(225,7),11,MUTED,26)
				qty.name="QtyLabel"; qty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; qty.mouse_filter=Control.MOUSE_FILTER_IGNORE
				var plus:=button(b,"+",Rect2(250,5,24,25),catalog_adjust_quantity.bind(id,1))
				plus.name="QtyPlus"
				plus.tooltip_text="1 hinzufügen"
				var up:=button(b,"↑",Rect2(214,34,28,24),catalog_adjust_priority.bind(id,-1))
				up.name="PriorityUp"; up.tooltip_text="Nach oben"
				var down:=button(b,"↓",Rect2(246,34,28,24),catalog_adjust_priority.bind(id,1))
				down.name="PriorityDown"; down.tooltip_text="Nach unten"
				for compact in [minus,plus,up,down]:
					compact.add_theme_font_size_override("font_size",13)
					for compact_state in ["normal","hover","pressed","disabled","focus"]:
						var compact_style: StyleBoxFlat=compact.get_theme_stylebox(compact_state).duplicate()
						compact_style.content_margin_left=2; compact_style.content_margin_right=2
						compact_style.content_margin_top=1; compact_style.content_margin_bottom=1
						compact.add_theme_stylebox_override(compact_state,compact_style)
			b.tooltip_text="%s\n%s\nBauzeit: %s s\nVoraussetzungen: %s" % [d.name,d.description,d.time,", ".join(d.get("requires",[]))]
			b.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_RIGHT: catalog_click(id,true); b.accept_event())
			buttons[id]=b
			y+=78
	catalog_content.custom_minimum_size=Vector2(274,maxf(744,y-6))
	queue_label=label(side,"",Vector2(18,857),16,MUTED,264)
	production_bar=ProgressBar.new()
	production_bar.position=Vector2(18,842); production_bar.size=Vector2(264,8)
	production_bar.show_percentage=false
	production_bar.add_theme_font_size_override("font_size",1)
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color=GOLD
	production_bar.add_theme_stylebox_override("fill",progress_style)
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color=Color("18110c")
	production_bar.add_theme_stylebox_override("background",progress_background)
	side.add_child(production_bar)
	production_bar.size=Vector2(264,8)
	harvest_button=button(side,"FELD WÄHLEN",Rect2(18,903,138,32),func():
		harvest_mode=true; attack_mode=false; placement=""; notify("Solaritfeld mit Linksklick zuweisen. Rechtsklick auf Solarit sammelt ebenfalls."))
	unload_button=button(side,"ABLADEN",Rect2(164,903,138,32),func():
		dispatch_order(selected,Vector2.ZERO,"return"); harvest_mode=false; notify("Sammler kehrt zur Raffinerie zurück."))
	harvest_button.add_theme_font_size_override("font_size",13)
	unload_button.add_theme_font_size_override("font_size",13)
	harvest_button.tooltip_text="Nur für ausgewählte Solarit-Sammler: ein Solaritfeld als Sammelziel wählen."
	unload_button.tooltip_text="Nur für ausgewählte Solarit-Sammler: Ladung zur Raffinerie zurückbringen."
	# These are unit-context actions, not generic construction controls. update_hud()
	# only reveals them while at least one own harvester is selected.
	harvest_button.visible=false
	unload_button.visible=false
	var bottom := panel(ui,Rect2(20,1042,1880,28))
	label(bottom,"LMB Auswahl   RMB Klick: Befehl · Ziehen: Karte   A Angriff   S Stopp   H Halten   Strg+1–9 Gruppen   F5/F9 Speichern/Laden",Vector2(12,4),14,MUTED)
	alert_panel=panel(ui,Rect2(32,975,1515,45),Color(0.16,0.10,0.055,0.86))
	alert_panel.visible=false
	notification=label(ui,"",Vector2(44,985),19,GOLD,1460)
	hover_panel=panel(ui,Rect2(0,0,244,56),Color("211a15",0.96))
	hover_panel.z_index=80; hover_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; hover_panel.visible=false
	hover_label=label(hover_panel,"",Vector2(10,7),14,Color("dce4dc"),224)
	debug_label=label(ui,"",Vector2(36,100),17,Color("bdf3ce"))
	if online.active:
		connection_label=label(ui,"VERBINDE …",Vector2(1050,102),16,MINT,430)
		connection_label.size.y=32
		button(ui,"CHAT · ENTER",Rect2(36,145,175,36),toggle_chat)
		build_online_chat(ui,Rect2(36,188,590,295),false)
	update_hud()

func catalog_factories_for_controls() -> Array:
	var factories:=sim.buildings(local_owner(),"factory",false)
	factories.sort_custom(func(a,b): return int(a.id)<int(b.id))
	if production_target_factory_id>0:
		return factories.filter(func(factory): return int(factory.id)==production_target_factory_id)
	return factories

func catalog_queue_count(kind: String) -> int:
	var count:=0
	for factory in catalog_factories_for_controls():
		for job in factory.queue:
			if str(job.kind)==kind: count+=1
	return count

func catalog_priority_target(kind: String, direction: int) -> Dictionary:
	for factory in catalog_factories_for_controls():
		if not factory.complete: continue
		if direction<0:
			for queue_index in range(2,factory.queue.size()):
				if str(factory.queue[queue_index].kind)==kind:
					return {"factory_id":int(factory.id),"queue_index":queue_index}
		else:
			for queue_index in range(1,maxi(1,factory.queue.size()-1)):
				if queue_index<factory.queue.size()-1 and str(factory.queue[queue_index].kind)==kind:
					return {"factory_id":int(factory.id),"queue_index":queue_index}
	return {}

func catalog_adjust_quantity(kind: String, delta: int) -> void:
	if paused or delta==0: return
	if delta>0:
		catalog_click(kind,false)
		return
	var factories:=catalog_factories_for_controls()
	for factory_index in range(factories.size()-1,-1,-1):
		var factory: Dictionary=factories[factory_index]
		for queue_index in range(factory.queue.size()-1,-1,-1):
			if str(factory.queue[queue_index].kind)!=kind: continue
			if submit_player_command({"type":"cancel_queue_at","owner_id":local_owner(),"factory_id":int(factory.id),"queue_index":queue_index}):
				music.cue("error")
				update_hud()
			return

func catalog_adjust_priority(kind: String, direction: int) -> void:
	if paused or direction not in [-1,1]: return
	var target:=catalog_priority_target(kind,direction)
	if target.is_empty(): return
	if submit_player_command({"type":"move_queue","owner_id":local_owner(),"factory_id":int(target.factory_id),"queue_index":int(target.queue_index),"direction":direction}):
		music.cue("select")
		update_hud()

func catalog_click(id: String, cancel: bool) -> void:
	if paused: return
	if db.buildings.has(id):
		if cancel: placement=""; renderer.placement=""; return
		var block_reason:=catalog_block_reason(id)
		if block_reason!="": notify(block_reason); music.cue("error"); return
		placement=id; placement_rotation=0; renderer.placement_rotation=0; renderer.placement=id; attack_mode=false
		notify("%s: R / E dreht, Q dreht zurück. Baufläche anklicken; Rechtsklick bricht ab." % db.buildings[id].name)
	else:
		if cancel: submit_player_command({"type":"cancel_produce","owner_id":local_owner(),"kind":id})
		else:
			var block_reason:=catalog_block_reason(id)
			if block_reason!="": notify(block_reason); music.cue("error"); return
			var amount := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
			for i in amount:
				var packet: Dictionary={"type":"produce","owner_id":local_owner(),"kind":id}
				if production_target_factory_id>0: packet.producer_id=production_target_factory_id
				if not submit_player_command(packet): notify("Produktion nicht möglich: Solarit, Anforderung oder Warteschlange prüfen."); music.cue("error"); break
	update_hud()

func catalog_block_reason(id: String) -> String:
	var reasons: Array[String]=[]
	var missing:=sim.missing_requirements(id,local_owner())
	if not missing.is_empty(): reasons.append("Voraussetzungen nicht erfüllt: "+", ".join(missing))
	var available:=int(sim.credits[local_owner()])
	var needed:=sim.cost(id,local_owner())
	if available<needed: reasons.append("Solarit reicht nicht aus (%d von %d benötigt)"%[available,needed])
	if production_target_factory_id>0:
		if not sim.entities.has(production_target_factory_id): reasons.append("Zielwerft nicht verfügbar")
		elif sim.entities[production_target_factory_id].queue.size()>=12: reasons.append("Zielwerft-Warteschlange ist voll")
	return " · ".join(reasons)

func submit_player_command(packet: Dictionary) -> bool:
	if sim!=null and sim.online_mode=="versus" and (not online.active or not online.connected or ended): return false
	if online!=null and online.is_client(): return online.send_command(packet)
	if online!=null and online.is_host(): return online.submit_local_host_command(packet)
	return sim.submit_command(packet,local_owner())

func production_factory_number(factory_id: int) -> int:
	var factories:=sim.buildings(local_owner(),"factory",false)
	factories.sort_custom(func(a,b):return int(a.id)<int(b.id))
	for index in factories.size():
		if int(factories[index].id)==factory_id: return index+1
	return 0

func focus_production_building(building_id: int) -> void:
	if not sim.entities.has(building_id): return
	production_target_factory_id=0 if production_target_factory_id==building_id else building_id
	selected=[building_id]
	inspected=0
	renderer.camera=sim.entities[building_id].pos
	clamp_camera()
	update_hud()
	if production_target_factory_id==building_id: notify("Neue Fahrzeuge werden gezielt in Werft %02d eingereiht."%production_factory_number(building_id))
	else: notify("Automatische Verteilung auf die kürzeste Warteschlange aktiv.")

func construction_phase_label(progress: float) -> String:
	if progress < 0.25: return "FUNDAMENT"
	if progress < 0.50: return "RAHMEN"
	if progress < 0.85: return "MONTAGE"
	if progress < 1.0: return "INBETRIEBNAHME"
	return "BETRIEBSBEREIT"

func localized_armor_label(value: String) -> String:
	return {"light":"LEICHT","medium":"MITTEL","heavy":"SCHWER","structure":"GEBÄUDE"}.get(value,value.to_upper())

func localized_order_label(value: String) -> String:
	return {"GUARD":"BEWACHEN","ATTACK":"ANGRIFF","HOLD":"POSITION HALTEN","MOVE":"BEWEGEN","STOP":"STOPP","REPAIR":"REPARIEREN","IDLE":"BEREIT"}.get(value,value.replace("_"," ").to_upper())

func catalog_activity_state(id: String) -> Dictionary:
	var result := {"active":false,"line":"","ratio":-1.0,"tooltip":""}
	if db.buildings.has(id):
		var active_sites: Array = sim.buildings(local_owner(),id,false)
		active_sites = active_sites.filter(func(site): return not bool(site.complete))
		if not active_sites.is_empty():
			active_sites.sort_custom(func(a,b): return int(a.id) < int(b.id))
			var site: Dictionary = active_sites[0]
			var ratio: float = clampf(float(site.get("build_progress",0.0)) / maxf(0.01,float(sim.definition(site).time)),0.0,1.0)
			var count: int = active_sites.size()
			result.active = true
			result.line = "IM BAU · %d%% · %s%s" % [int(ratio * 100.0), construction_phase_label(ratio), " · +%d" % (count - 1) if count > 1 else ""]
			result.ratio = ratio
			result.tooltip = "Aktive Baustelle: %s · %d%% · %s" % [sim.definition(site).name, int(ratio * 100.0), construction_phase_label(ratio)]
			return result
		var upgrade_sites: Array = sim.buildings(local_owner(),id)
		upgrade_sites = upgrade_sites.filter(func(site): return bool(site.get("upgrading",false)))
		if not upgrade_sites.is_empty():
			upgrade_sites.sort_custom(func(a,b): return int(a.id) < int(b.id))
			var site: Dictionary = upgrade_sites[0]
			var ratio: float = clampf(float(site.get("upgrade_progress",0.0)) / maxf(0.01,float(site.get("upgrade_time",1.0))),0.0,1.0)
			result.active = true
			result.line = "AUSBAU · %d%% · STUFE %d" % [int(ratio * 100.0), int(site.get("upgrade_target",1))]
			result.ratio = ratio
			result.tooltip = "Ausbau läuft: %s · Stufe %d → %d · %d%%" % [sim.definition(site).name, int(site.get("upgrade_level",0)), int(site.get("upgrade_target",1)), int(ratio * 100.0)]
			return result
	else:
		var total_orders := 0
		for factory in sim.buildings(local_owner(),"factory"):
			for job_index in range(factory.queue.size()):
				var job: Dictionary = factory.queue[job_index]
				if str(job.kind) != id:
					continue
				total_orders += 1
				if job_index == 0:
					var unit_def: Dictionary = db.units[id]
					var production_time: float = maxf(0.01,float(unit_def.time) * (0.85 if int(factory.get("upgrade_level",0)) > 0 else 1.0))
					var ratio: float = clampf(float(factory.progress) / production_time,0.0,1.0)
					result.active = true
					result.line = "MONTAGE · %d%% · WERFT %02d" % [int(ratio * 100.0), production_factory_number(int(factory.id))]
					result.ratio = ratio
					result.tooltip = "Produktion aktiv: %s · %d%% in Werft %02d" % [unit_def.name, int(ratio * 100.0), production_factory_number(int(factory.id))]
					return result
		if total_orders > 0:
			result.active = true
			result.line = "WARTESCHLANGE · %d AUFTRÄGE" % total_orders
			result.tooltip = "%d Produktionsaufträge für dieses Fahrzeug eingereiht." % total_orders
	return result

func update_hud() -> void:
	if not playing or sim==null or not is_instance_valid(status): return
	var ui_started:=Time.get_ticks_usec() if renderer.profile_enabled else 0
	var p := sim.power(local_owner())
	radar_caption.text="RADAR AKTIV" if not sim.buildings(local_owner(),"radar").is_empty() and sim.powered(local_owner()) else "RADAR OFFLINE"
	status.text=format_score(int(sim.credits[local_owner()]))
	energy_label.text="%+d"%int(p.y-p.x)
	energy_label.modulate=Color("ffb17c") if p.x>p.y else Color.WHITE
	energy_label.tooltip_text="Verbrauch %d / Erzeugung %d · freie Energie %+d"%[int(p.x),int(p.y),int(p.y-p.x)]
	mission_clock.text="%02d:%02d"%[int(sim.time)/60,int(sim.time)%60]
	if is_instance_valid(objective): objective.text=sim.hud_objective_text()
	if is_instance_valid(optional_objective): optional_objective.text=sim.optional_objective_progress_text() if not online.active else ""
	if p.x>p.y and not low_power_alerted:
		notify("ENERGIE KNAPP / IMPULSWERK BAUEN"); music.cue("alarm")
		minimap.ping(renderer.camera,GOLD)
	low_power_alerted=p.x>p.y
	selected=selected.filter(func(id):return sim.entities.has(int(id)))
	if production_target_factory_id>0 and (not sim.entities.has(production_target_factory_id) or sim.entities[production_target_factory_id].owner!=local_owner()): production_target_factory_id=0
	for k in groups: groups[k]=groups[k].filter(func(id):return sim.entities.has(int(id)))
	if inspected>0 and (not sim.entities.has(inspected) or not sim.is_visible(sim.entities[inspected],local_owner())): inspected=0
	renderer.selected=selected+[inspected] if inspected>0 else selected
	refresh_selection_icons()
	var has_harvester := false
	for id in selected:
		if not sim.entities.has(int(id)): continue
		var selected_entity: Dictionary=sim.entities[int(id)]
		if selected_entity.owner==local_owner() and selected_entity.kind=="harvester" and selected_entity.complete:
			has_harvester=true
	# Harvester commands must not occupy the construction/production footer for buildings.
	# Showing them only in the matching unit context avoids misleading FELD WÄHLEN / ABLADEN
	# buttons while a construction site, factory or other building is selected.
	harvest_button.visible=has_harvester
	unload_button.visible=has_harvester
	harvest_button.disabled=not has_harvester
	unload_button.disabled=not has_harvester
	details_button.disabled=placement=="" and selected.is_empty() and inspected==0
	details_button.text="DREHEN · R" if placement!="" else "OBJEKTINFO"
	repair_button.disabled=selected.is_empty() or inspected>0
	repair_button.text="REPARATUR AUS" if selected.size()==1 and sim.entities[int(selected[0])].building and sim.entities[int(selected[0])].repair else "REPARIEREN · R"
	information.add_theme_color_override("font_color",MUTED)
	if selected.size()==1 or inspected>0:
		var e: Dictionary = sim.entities[inspected if inspected>0 else int(selected[0])]
		information.add_theme_color_override("font_color",sim.team_color(e.owner).lightened(0.15))
		var states := {"SEARCH_RESOURCE":"Sucht Solarit", "MOVE_TO_RESOURCE":"Fährt zum Solarit", "HARVEST":"Sammelt", "RETURN_TO_BASE":"Kehrt zurück", "UNLOAD":"Lädt ab", "IDLE":"Wartet auf Auftrag", "EVADE":"Weicht Angriff aus"}
		information.text="%s\nHP %d/%d · %s\n%s" % [TeamIdentity.symbol(e.owner)+" "+sim.definition(e).name,int(e.hp),int(e.max_hp),localized_armor_label(str(sim.definition(e).armor)),states.get(e.harvest_state,e.harvest_state)+" · %d / %d"%[int(e.cargo),int(db.rules.harvest_capacity)] if e.kind=="harvester" else localized_order_label(str(e.order))]
		if e.building and e.owner==local_owner():
			if not e.complete:
				var build_ratio: float=clampf(float(e.get("build_progress",0.0))/maxf(0.01,float(sim.definition(e).time)),0.0,1.0)
				var build_phase: String=construction_phase_label(build_ratio)
				information.text="%s\nHP %d/%d · %s\nBAU %d%% · %s"%[TeamIdentity.symbol(e.owner)+" "+sim.definition(e).name,int(e.hp),int(e.max_hp),localized_armor_label(str(sim.definition(e).armor)),int(build_ratio*100.0),build_phase]
			elif e.kind=="factory" and not e.queue.is_empty():
				var active_job: Dictionary=e.queue[0]
				var active_def: Dictionary=db.units[str(active_job.kind)]
				var active_time: float=maxf(0.01,float(active_def.time)*(0.85 if int(e.get("upgrade_level",0))>0 else 1.0))
				var active_ratio: float=clampf(float(e.progress)/active_time,0.0,1.0)
				information.text="%s\nHP %d/%d · %s\nMONTAGE: %s · %d%%\nQUEUE: %d"%[TeamIdentity.symbol(e.owner)+" "+sim.definition(e).name,int(e.hp),int(e.max_hp),localized_armor_label(str(sim.definition(e).armor)),active_def.name,int(active_ratio*100.0),e.queue.size()]
			elif e.get("upgrading",false):
				var upgrade_ratio: float=clampf(float(e.get("upgrade_progress",0.0))/maxf(0.01,float(e.get("upgrade_time",1.0))),0.0,1.0)
				information.text="%s\nHP %d/%d · %s\nAUSBAU STUFE %d · %d%%"%[TeamIdentity.symbol(e.owner)+" "+sim.definition(e).name,int(e.hp),int(e.max_hp),localized_armor_label(str(sim.definition(e).armor)),int(e.get("upgrade_target",1)),int(upgrade_ratio*100.0)]
		if e.kind=="harvester": information.text=information.text.replace("\n"+states.get(e.harvest_state,e.harvest_state),"\nAUTO / "+states.get(e.harvest_state,e.harvest_state))
		elif not e.building:
			var weapon_id: String = sim.definition(e).get("weapon","")
			information.text+=" · "+{"pulse":"ENERGIEIMPULS", "cannon":"PANZERKANONE", "mortar":"BELAGERUNG", "shard":"SPLITTERSALVE", "lance":"ENERGIELANZE", "flame":"FLAMMENKEGEL", "breaker":"GEBÄUDEBRECHER"}.get(weapon_id,"UNBEWAFFNET")
		if inspected>0: information.text="◆ FEIND / %s\n%s\nIntegrität %d / %d" % [db.factions[sim.factions[e.owner]].name,sim.definition(e).name,int(e.hp),int(e.max_hp)]
	elif selected.size()>1: information.text="%d FAHRZEUGE AUSGEWÄHLT\nRechtsklick: Formation bewegen" % selected.size()
	else: information.text="1:1-DUELL\nEigene Basis aufbauen.\nFeindlichen Baukern zerstören." if sim.online_mode=="versus" else str(db.mission.get("hud_hint","BECKEN / KOMMANDO\nImpulswerk → Raffinerie → Werft\nSpäher erkunden das Becken."))
	for id in buttons:
		var d: Dictionary = db.buildings[id] if db.buildings.has(id) else db.units[id]
		var count := 0
		for f in sim.buildings(local_owner(),"factory"):
			for j in f.queue:
				if j.kind==id: count+=1
		var missing:=sim.missing_requirements(id,local_owner())
		var affordable: bool=sim.credits[local_owner()]>=sim.cost(id,local_owner())
		var locked: bool=int(d.get("campaign_level",0))>sim.campaign_tech_level
		var roles := {"scout":"AUFKLÄRUNG","tank":"KAMPFPANZER","harvester":"RESSOURCENFÖRDERUNG","siege":"FERNUNTERSTÜTZUNG","raider":"STURMFAHRZEUG","lancer":"ENERGIEWAFFE","scorcher":"NAHKAMPF / FEUER","bulwark":"SCHWERER DURCHBRUCH","power":"ENERGIEVERSORGUNG","refinery":"SOLARITVERARBEITUNG","factory":"FAHRZEUGMONTAGE","tower":"BASISVERTEIDIGUNG","radar":"TAKTISCHES RADAR","repair":"INSTANDSETZUNG","armory":"FAHRZEUGAUSBAU"}
		var availability: String=str(roles.get(id,"BASISMODUL"))
		if locked: availability="FREIGABE: EINSATZ %02d"%(int(d.campaign_level)+1)
		elif not missing.is_empty(): availability="BENÖTIGT: "+str(missing[0]).trim_prefix("Gebäude: ")
		elif not affordable: availability="FEHLEN %d SOLARIT"%ceili(sim.cost(id,local_owner())-sim.credits[local_owner()])
		var price: String="%d Solarit · %s s%s"%[sim.cost(id,local_owner()),d.time,"  ×%d"%count if count>0 and db.buildings.has(id) else ""]
		var activity: Dictionary = catalog_activity_state(id)
		var detail_line: String = activity.line if bool(activity.active) else availability
		buttons[id].text="%s%s\n%s\n%s" % ["🔒 " if locked else "",d.name,price,detail_line]
		buttons[id].set_meta("catalog_state","locked" if locked else ("prerequisite" if not missing.is_empty() else ("credits" if not affordable else ("active" if bool(activity.active) else "available"))))
		buttons[id].disabled=false
		# Keep the catalog's neutral surfaces and original unit artwork intact.
		# Only the label and narrow edge marker carry the blocker state.
		buttons[id].modulate=Color.WHITE
		buttons[id].get_node("CatalogArtwork").modulate=Color(0.4,0.4,0.4) if locked else Color.WHITE
		buttons[id].add_theme_color_override("font_color",Color("c07d70") if not missing.is_empty() else (Color("d6b56f") if not affordable else (MINT if bool(activity.active) else Color("d8d1c4"))))
		requirement_marks[id].visible=not bool(activity.active) and (not missing.is_empty() or not affordable)
		requirement_marks[id].color=Color("9e524c") if not missing.is_empty() else Color("d6b56f")
		var status_lines: Array[String]=[]
		if not missing.is_empty(): status_lines.append("VORAUSSETZUNGEN NICHT ERFÜLLT: "+", ".join(missing))
		if not affordable: status_lines.append("SOLARIT REICHT NICHT AUS: %d vorhanden, %d benötigt"%[int(sim.credits[local_owner()]),sim.cost(id,local_owner())])
		if bool(activity.active) and str(activity.tooltip) != "": status_lines.append(str(activity.tooltip))
		if status_lines.is_empty(): status_lines.append("BAUPLATZ WÄHLEN" if db.buildings.has(id) else "BEREIT / Linksklick reiht die Produktion ein")
		var energy_text: String="Energie Gebäude: %+d"%int(d.get("power",0))
		if int(d.get("power_required",0))>0: energy_text+="\nMontage benötigt %d freie Energie"%int(d.power_required)
		var compact_status: String=" · ".join(status_lines) if not status_lines.is_empty() else ""
		buttons[id].tooltip_text="%s\n%d Solarit · %s s\n%s" % [d.description,sim.cost(id,local_owner()),d.time,compact_status]
		var activity_bar := buttons[id].get_node_or_null("CatalogActivityBar") as ProgressBar
		if activity_bar != null:
			activity_bar.visible = bool(activity.active) and float(activity.ratio) >= 0.0
			activity_bar.value = clampf(float(activity.ratio), 0.0, 1.0) * 100.0
		if db.units.has(id):
			var qty_label:=buttons[id].get_node_or_null("QtyLabel") as Label
			var qty_minus:=buttons[id].get_node_or_null("QtyMinus") as Button
			var qty_plus:=buttons[id].get_node_or_null("QtyPlus") as Button
			var priority_up:=buttons[id].get_node_or_null("PriorityUp") as Button
			var priority_down:=buttons[id].get_node_or_null("PriorityDown") as Button
			var queued_count:=catalog_queue_count(id)
			if qty_label!=null: qty_label.text="×%d"%queued_count
			if qty_minus!=null: qty_minus.disabled=queued_count<=0
			if qty_plus!=null:
				var control_factories:=catalog_factories_for_controls()
				var target_full:=control_factories.is_empty()
				if not control_factories.is_empty():
					target_full=true
					for control_factory in control_factories:
						if control_factory.queue.size()<12:
							target_full=false
							break
				qty_plus.disabled=locked or not missing.is_empty() or not affordable or target_full
			if priority_up!=null: priority_up.disabled=catalog_priority_target(id,-1).is_empty()
			if priority_down!=null: priority_down.disabled=catalog_priority_target(id,1).is_empty()
	queue_label.text=""
	queue_label.visible=false
	production_bar.value=0
	production_bar.visible=false
	refresh_production_list()
	minimap.camera=renderer.camera; minimap.world_view=WORLD_RECT.size/renderer.zoom
	debug_label.visible=profiler_overlay_visible
	if profiler_overlay_visible:
		debug_label.text="FPS %d · %.1f ms | MOBIL %d · NEBEL %d · AUSSERHALB %d · GEBÄUDE %d · VFX %d\nZEICHNEN %.1f ms · Terrain %.1f · Ruinen %.1f · Bauten %.1f · Fahrzeuge %.1f\nPASS · Spuren %.1f · Geschosse %.1f · Treffer %.1f · Explosionen %.1f · Rauch %.1f · Sicht %.1f\nSIM %.1f ms · SOLARIT %d · WRACKS %d · SCHÜSSE %d · EINSCHLÄGE %d · EFFEKTE %d\nDRAW %d · KACHELN %d/%d · GEBÄUDE-CACHE %d/%d · FAHRZEUGE %d/%d · PROC %.2f ms" % [Engine.get_frames_per_second(),1000.0/maxf(1,Engine.get_frames_per_second()),renderer.visible_mobile_count,renderer.culled_mobile_fog_count,renderer.culled_mobile_offscreen_count,renderer.visible_building_count,renderer.active_vfx_count,renderer.profile_total_ms,renderer.profile_terrain_ms,renderer.profile_ground_fx_ms,renderer.profile_buildings_ms,renderer.profile_vehicles_ms,renderer.profile_tracks_ms,renderer.profile_projectiles_ms,renderer.profile_impacts_ms,renderer.profile_explosions_ms,renderer.profile_smoke_ms,renderer.profile_fog_ms,renderer.profile_sim_ms,renderer.profile_solarit_count,renderer.profile_ruin_count,renderer.profile_projectile_count,renderer.profile_impact_count,renderer.profile_particle_count,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),renderer.visible_terrain_chunk_count,renderer.terrain_detail_chunks.size(),renderer.building_cache_hits,renderer.building_cache_misses,renderer.vehicle_cache_hits,renderer.vehicle_cache_misses,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0]
		debug_label.text+="\nVFX-POOL %d aktiv / %d frei · erstellt %d / recycelt %d / Spitze %d" % [renderer.combat_fx.particles.size(),renderer.combat_fx.free_particles.size(),renderer.combat_fx.particle_pool_created,renderer.combat_fx.particle_pool_reused,renderer.combat_fx.particle_pool_peak]
		debug_label.text+="\nWRACK-PASS %.2f ms · HUD-UPDATE %.2f ms" % [renderer.profile_wrecks_ms,renderer.profile_ui_ms]
	else:
		debug_label.text="FPS %d · %.1f ms | MOBIL %d NEBEL %d RAND %d\nGEBÄUDE %d VFX %d DRAW %d · CHUNK %d/%d · CACHE %d/%d\nPROC %.2f ms · KI %s · MUSIK %s" % [Engine.get_frames_per_second(),1000.0/maxf(1,Engine.get_frames_per_second()),renderer.visible_mobile_count,renderer.culled_mobile_fog_count,renderer.culled_mobile_offscreen_count,renderer.visible_building_count,renderer.active_vfx_count,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),renderer.visible_terrain_chunk_count,renderer.terrain_detail_chunks.size(),renderer.vehicle_cache_hits,renderer.vehicle_cache_misses,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,sim.ai_state,music.state]
	fit_wrapped(information)
	information.size.y=78
	fit_wrapped(queue_label)
	if renderer.profile_enabled: renderer.profile_ui_ms=float(Time.get_ticks_usec()-ui_started)/1000.0

func refresh_production_list() -> void:
	if category!="production": return
	var factories:=sim.buildings(local_owner(),"factory",false)
	factories.sort_custom(func(a,b):return int(a.id)<int(b.id))
	if production_content==null: return
	var signature_parts: Array[String]=[]
	signature_parts.append("target:%d"%production_target_factory_id)
	for factory in factories:
		var jobs: Array[String]=[]
		for job in factory.queue: jobs.append("%s:%d"%[str(job.kind),int(job.get("paid",0))])
		signature_parts.append("%d|%s|%s"%[int(factory.id),str(factory.complete),",".join(jobs)])
	var signature: String=";".join(signature_parts)
	if signature!=production_signature: rebuild_production_list(factories,signature)
	for index in factories.size():
		var factory: Dictionary=factories[index]
		var row: Button=production_rows.get(int(factory.id))
		if row==null: continue
		var heading: String="WERFT %02d%s"%[index+1," · ZIEL" if production_target_factory_id==int(factory.id) else ""]
		if not factory.complete:
			var build_pct:=int(float(factory.build_progress)/maxf(1.0,float(sim.definition(factory).time))*100.0)
			row.text="%s · IM BAU\n%s · %d%%"%[heading,construction_phase_label(float(build_pct)/100.0),build_pct]
			continue
		if factory.queue.is_empty():
			row.text="%s · BEREIT\nJETZT: — · ALS NÄCHSTES: —"%heading
			row.tooltip_text="Diese Werft ist online und wartet auf einen Produktionsauftrag."
			continue
		var current_kind: String=str(factory.queue[0].kind)
		var current_def: Dictionary=db.units[current_kind]
		var production_time:=float(current_def.time)*(0.85 if int(factory.get("upgrade_level",0))>0 else 1.0)
		var completion:=clampi(int(factory.progress/maxf(1.0,production_time)*100.0),0,99)
		var job_progress := production_content.get_node_or_null("JobProgress%d"%int(factory.id)) as ProgressBar
		if job_progress: job_progress.value=completion
		var next_text: String="—"
		if factory.queue.size()>1:
			next_text=production_unit_short_name(str(factory.queue[1].kind))
		row.text="%s · MONTAGE %d%%\nJETZT: %s · NÄCHST: %s"%[heading,completion,production_unit_short_name(current_kind),next_text]
		row.tooltip_text="%s\nLäuft: %s (%d%%)\nDanach: %s\nGesamte Warteschlange: %d Fahrzeuge"%[heading,current_def.name,completion,next_text,factory.queue.size()]

func production_unit_short_name(kind: String) -> String:
	var name_value: String=str(db.units.get(kind,{}).get("name",kind))
	return name_value.get_slice("·",1).strip_edges() if name_value.contains("·") else name_value.replace("Solarit-","")

func rebuild_production_list(factories: Array, signature: String) -> void:
	for child in production_content.get_children(): child.queue_free()
	production_rows.clear()
	production_empty_label=null
	var y:=0.0
	if factories.is_empty():
		production_empty_label=label(production_content,"KEINE FAHRZEUGWERFT\n\nErrichte im Tab Bau eine Fahrzeugwerft. Dort werden alle Fahrzeuge montiert.",Vector2(6,10),15,MUTED,302)
		production_empty_label.size.y=125
		y=135
	else:
		var automatic:=button(production_content,"AUTOMATIK · KÜRZESTE QUEUE",Rect2(0,y,314,34),func():production_target_factory_id=0; update_hud())
		automatic.add_theme_font_size_override("font_size",11)
		automatic.tooltip_text="Neue Aufträge automatisch der Werft mit der kürzesten Warteschlange zuweisen."
		if production_target_factory_id==0:
			automatic.add_theme_color_override("font_color",MINT)
		y+=40
		for factory_index in factories.size():
			var factory: Dictionary=factories[factory_index]
			var factory_id:=int(factory.id)
			var header:=button(production_content,"",Rect2(0,y,314,52),focus_production_building.bind(factory_id))
			header.alignment=HORIZONTAL_ALIGNMENT_LEFT
			header.add_theme_font_size_override("font_size",12)
			header.tooltip_text="Anklicken: als Zielwerft für neue Aufträge auswählen; erneut anklicken: zurück zur Automatik."
			if production_target_factory_id==factory_id:
				var target_style: StyleBoxFlat=header.get_theme_stylebox("normal").duplicate()
				target_style.border_color=MINT; target_style.border_width_left=3
				header.add_theme_stylebox_override("normal",target_style)
			production_rows[factory_id]=header
			y+=56
			if factory.queue.is_empty():
				var empty:=label(production_content,"Warteschlange leer",Vector2(10,y+2),13,MUTED,314)
				empty.size.y=22; y+=25
			else:
				for queue_index in factory.queue.size():
					var job: Dictionary=factory.queue[queue_index]
					var item_panel:=panel(production_content,Rect2(0,y,314,56 if queue_index==0 else 43),Color("27302b",0.92) if queue_index==0 else Color("30251b",0.92))
					item_panel.clip_contents=true
					var unit_name: String=str(db.units[str(job.kind)].name)
					var state_text: String="MONTAGE" if queue_index==0 else ("ALS NÄCHSTES" if queue_index==1 else "WARTET")
					var job_copy:=label(item_panel,"%02d  %s\n%s"%[queue_index+1,unit_name,state_text],Vector2(7,2),11,Color("d6e1d9") if queue_index==0 else MUTED,170)
					job_copy.size.y=36
					if queue_index==0:
						var progress := ProgressBar.new()
						progress.name="JobProgress%d"%factory_id
						progress.position=Vector2(7,y+43); progress.size=Vector2(230,5); progress.show_percentage=false
						var fill := StyleBoxFlat.new(); fill.bg_color=MINT
						progress.add_theme_stylebox_override("fill",fill)
						var background := StyleBoxFlat.new(); background.bg_color=Color("18110c")
						progress.add_theme_stylebox_override("background",background)
						progress.add_theme_font_size_override("font_size",1)
						production_content.add_child(progress)
					var priority:=button(item_panel,"↑",Rect2(184,5,23,27),move_production_order.bind(factory_id,queue_index,-1))
					priority.tooltip_text="Als Nächstes produzieren"
					priority.disabled=queue_index<=1 or not factory.complete
					priority.add_theme_color_override("font_color",MINT)
					var demote:=button(item_panel,"↓",Rect2(210,5,23,27),move_production_order.bind(factory_id,queue_index,1))
					demote.tooltip_text="Nach unten"
					demote.disabled=queue_index==0 or queue_index>=factory.queue.size()-1 or not factory.complete
					var cancel:=button(item_panel,"×",Rect2(236,5,23,27),cancel_production_order.bind(factory_id,queue_index))
					for action in [priority,demote,cancel]:
						action.add_theme_font_size_override("font_size",15)
						for style_name in ["normal","hover","pressed","disabled","focus"]:
							var small_style: StyleBoxFlat=action.get_theme_stylebox(style_name).duplicate()
							small_style.content_margin_left=2; small_style.content_margin_right=2
							small_style.content_margin_top=2; small_style.content_margin_bottom=2
							action.add_theme_stylebox_override(style_name,small_style)
						action.size=Vector2(23,27)
					cancel.tooltip_text="Diesen Auftrag abbrechen · %d Solarit Erstattung"%int(float(job.get("paid",0))*float(db.rules.cancel_refund))
					cancel.add_theme_color_override("font_color",Color("c07d70"))
					y+=60 if queue_index==0 else 47
			y+=10
	production_content.custom_minimum_size=Vector2(314,maxf(744,y))
	production_signature=signature

func cancel_production_order(factory_id: int, queue_index: int) -> void:
	if submit_player_command({"type":"cancel_queue_at","owner_id":local_owner(),"factory_id":factory_id,"queue_index":queue_index}): music.cue("error"); update_hud()

func move_production_order(factory_id: int, queue_index: int, direction: int) -> void:
	var packet: Dictionary={"type":"move_queue","owner_id":local_owner(),"factory_id":factory_id,"queue_index":queue_index,"direction":direction}
	if direction<0:
		packet.type="prioritize_queue"
	if submit_player_command(packet): music.cue("select"); update_hud()

func prioritize_production_order(factory_id: int, queue_index: int) -> void:
	# Backward-compatible helper for older UI call sites.
	move_production_order(factory_id,queue_index,-1)

func capture_render_state() -> Dictionary:
	var state := {}
	if sim==null: return state
	for id in sim.entities:
		var e: Dictionary=sim.entities[id]
		if e.building: continue
		state[id]=[e.pos,e.angle,e.turret]
	return state

func rotate_placement(direction: int) -> void:
	if paused or placement=="": return
	placement_rotation=posmod(placement_rotation+direction,4)
	renderer.placement_rotation=placement_rotation
	music.cue("rotate")
	notify("%s · %d° · R / E drehen, Q zurück" % [db.buildings[placement].name,placement_rotation*90])
	update_hud(); renderer.queue_redraw()

func repair_selection() -> void:
	if paused or inspected>0 or selected.is_empty(): return
	if submit_player_command({"type":"repair","owner_id":local_owner(),"ids":selected.duplicate()}):
		music.cue("repair")
		notify("Reparatur umgeschaltet. Fahrzeuge fahren zum Servicehangar; Reparaturen kosten Solarit.")
	else: notify("Reparatur nicht möglich: fertigen Servicehangar, Energie und erreichbaren Zugang prüfen. Baustellen zuerst fertigstellen.")
	update_hud()

func entity_details_text(e: Dictionary) -> String:
	var d: Dictionary = sim.definition(e)
	var armor := {"light":"Leicht", "medium":"Mittel", "heavy":"Schwer", "structure":"Gebäude"}
	var sight:=int(d.vision)+(4*int(e.get("upgrade_level",0)) if e.kind=="radar" else 0)
	var text_value := "%s\n\nZUSTAND\nIntegrität: %d / %d HP · %d%%\nPanzerung: %s\nSichtweite: %d Felder\n\n" % [d.description,int(e.hp),int(e.max_hp),int(e.hp/e.max_hp*100),armor.get(d.armor,d.armor),sight]
	if d.has("weapon"):
		var w: Dictionary = db.weapons[d.weapon]
		text_value+="BEWAFFNUNG\nSchaden: %s · Reichweite: %s\nNachladezeit: %s s\n\n" % [w.damage,w.range,w.reload]
	else: text_value+="BEWAFFNUNG\nUnbewaffnet\n\n"
	if e.building:
		text_value+="BETRIEB\nEnergie: %+d · %s\n" % [d.get("power",0),"Betriebsbereit" if e.complete else "Im Bau"]
		if int(d.get("max_level",0))>0:
			var level:=int(e.get("upgrade_level",0))
			text_value+="AUSBAU\nStufe %d / %d · Kampagnenstufe %d\n" % [level,d.max_level,sim.campaign_tech_level]
			if e.get("upgrading",false): text_value+="Ausbau auf Stufe %d: %d%% abgeschlossen.\n" % [e.upgrade_target,int(float(e.upgrade_progress)/maxf(1.0,float(e.upgrade_time))*100)]
			elif level<d.max_level:
				var unlocks: Array=d.get("upgrade_campaign_levels",[])
				var required_tech:=int(unlocks[level+1]) if level+1<unlocks.size() else level+1
				text_value+="Nächster Ausbau: %d Solarit · %s s · Freigabe ab Kampagnenstufe %d.\n" % [d.upgrade_costs[level+1],d.upgrade_times[level+1],required_tech]
			if e.kind=="armory": text_value+="Freigaben: Dorn ab Stufe 1 · Prisma und Wall ab Stufe 2.\n"
			elif e.kind=="factory": text_value+="Freigabe: Glut ab Stufe 1 · Montagezeit −15%.\n"
			elif e.kind=="refinery": text_value+="Solarit-Erlös: +%d%%.\n" % [level*20]
			elif e.kind=="radar": text_value+="Zusätzliche Netzsicht: +%d Felder.\n" % [level*4]
	else:
		text_value+="ANTRIEB\nTempo: %.0f · Auftrag: %s\n" % [float(d.speed)*float(db.factions[sim.factions[e.owner]].speed),e.order.to_upper()]
		if e.kind=="harvester": text_value+="Ladung: %d / %d Solarit\n" % [int(e.cargo),int(db.rules.harvest_capacity)]
	text_value+="\nREPARATUR\n%.0f HP/s · %.1f Solarit pro HP\nBis zur vollen Integrität: %.1f Solarit\n" % [db.rules.repair_rate,db.rules.repair_cost,(e.max_hp-e.hp)*float(db.rules.repair_cost)]
	if e.owner!=local_owner(): text_value+="Feindliches Objekt: keine Reparaturbefehle möglich."
	elif e.building:
		text_value+="Gebäudereparatur: "+("AKTIV" if e.repair else "AUS")+"\nMit Reparieren oder R ein-/ausschalten. Solarit wird nur für tatsächlich reparierte HP abgezogen."
	else: text_value+="Servicehangar repariert im Umkreis von 100 automatisch, wenn Energie und Solarit vorhanden sind. Reparieren oder R schickt dieses Fahrzeug zum Hangar. Sammler warten bis zur vollständigen Reparatur und arbeiten danach automatisch weiter; Kampffahrzeugen danach neue Befehle erteilen."
	return text_value

func show_entity_details() -> void:
	var ids: Array = [inspected] if inspected>0 else selected
	if ids.is_empty() or not sim.entities.has(int(ids[0])): return
	var e: Dictionary = sim.entities[int(ids[0])]
	if not sim.is_visible(e,local_owner()): return
	paused=not online.active; music.set_paused(paused); dragging=false; renderer.selecting=false
	clear(overlay)
	var p := panel(overlay,Rect2(470,110,980,850))
	label(p,"OBJEKTINFO / "+("EIGENE EINHEIT" if e.owner==local_owner() else "FEIND"),Vector2(34,24),18,MINT)
	label(p,sim.definition(e).name,Vector2(34,58),35,GOLD,912)
	var portrait := IndustrialThumbnail.new()
	portrait.sim=sim; portrait.entity_id=e.id; portrait.kind=e.kind
	portrait.position=Vector2(35,127); portrait.size=Vector2(160,170); portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(portrait)
	portrait.scale=Vector2.ONE*2.8
	var details := RichTextLabel.new()
	details.name="EntityDetails"; details.position=Vector2(227,132); details.size=Vector2(716,574)
	details.add_theme_font_size_override("normal_font_size",22); details.add_theme_constant_override("line_separation",5)
	details.text=entity_details_text(e); p.add_child(details)
	var can_upgrade: bool=e.building and e.owner==local_owner() and e.complete and not e.get("upgrading",false) and sim.definition(e).has("max_level") and int(e.get("upgrade_level",0))<int(sim.definition(e).max_level)
	if can_upgrade:
		var next_level:=int(e.get("upgrade_level",0))+1
		var d: Dictionary=sim.definition(e)
		var unlocks: Array=d.get("upgrade_campaign_levels",[])
		var required_tech:=int(unlocks[next_level]) if next_level<unlocks.size() else next_level
		can_upgrade=required_tech<=sim.campaign_tech_level and sim.credits[local_owner()]>=int(d.upgrade_costs[next_level])
	var is_upgradeable: bool=e.building and sim.definition(e).has("max_level")
	var action_label: String="AUSBAU: "+str(sim.definition(e).name) if is_upgradeable else ("REPARATUR EIN / AUS" if e.building else "ZUM SERVICEHANGAR")
	var action := button(p,action_label,Rect2(34,727,440,48),func():
		if is_upgradeable: start_armory_upgrade(e.id)
		else: resume_game(); repair_selection())
	action.disabled=e.owner!=local_owner() or not e.complete
	if is_upgradeable: action.disabled=not can_upgrade
	button(p,"ZURÜCK ZUM SPIEL",Rect2(500,727,446,48),resume_game)

func start_armory_upgrade(id: int) -> void:
	if submit_player_command({"type":"upgrade","owner_id":local_owner(),"id":id}):
		music.cue("build"); resume_game(); notify("Gebäudeausbau begonnen. Neue Funktionen gelten nach der Fertigstellung.")
	else:
		notify("Ausbau gesperrt: Solarit, Energie oder Kampagnenfreigabe prüfen.")

func refresh_selection_icons() -> void:
	if not is_instance_valid(selection_icons): return
	var ids: Array = [inspected] if inspected>0 else selected
	var signature := str(ids)
	if signature==selection_signature: return
	selection_signature=signature; clear(selection_icons)
	information.position=Vector2(76,30) if ids.size()==1 else Vector2(18,30)
	information.custom_minimum_size.x=236 if ids.size()==1 else 284
	information.size.x=information.custom_minimum_size.x
	if ids.size()==1 and sim.entities.has(int(ids[0])):
		var portrait := IndustrialThumbnail.new()
		portrait.sim=sim; portrait.entity_id=int(ids[0]); portrait.kind=sim.entities[int(ids[0])].kind
		portrait.position=Vector2(18,28); portrait.size=Vector2(50,50)
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		selection_icons.add_child(portrait)
	elif ids.size()>1:
		for i in mini(6,ids.size()):
			var icon := IndustrialThumbnail.new()
			icon.sim=sim; icon.entity_id=int(ids[i]); icon.kind=sim.entities[int(ids[i])].kind
			icon.position=Vector2(18+i*48,74); icon.size=Vector2(44,38); icon.scale=Vector2.ONE*0.78
			icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			selection_icons.add_child(icon)

func fit_wrapped(control: Label) -> void:
	var extent := control.get_theme_font("font").get_multiline_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,control.size.x,control.get_theme_font_size("font_size"))
	control.size.y=extent.y+6

func show_world_entity_hover(entity_id: int, local: Vector2) -> bool:
	if not playing or paused or placement!="" or harvest_mode or dragging or not WORLD_RECT.has_point(local) or not sim.entities.has(entity_id):
		hovered_entity_id=0; renderer.hovered_entity_id=0
		hover_label.text=""; hover_panel.visible=false
		return false
	var hovered: Dictionary=sim.entities[entity_id]
	var hovered_name: String=str(sim.definition(hovered).name)
	if hovered_name.is_empty():
		hovered_entity_id=0; renderer.hovered_entity_id=0
		hover_label.text=""; hover_panel.visible=false
		return false
	hovered_entity_id=entity_id; renderer.hovered_entity_id=entity_id
	var team_name: String="Eigene Einheit" if hovered.owner==local_owner() else "Feindliche Einheit"
	hover_label.text="%s · %s\n%d / %d HP · %s"%[team_name,hovered_name,int(hovered.hp),int(hovered.max_hp),localized_armor_label(str(sim.definition(hovered).armor))]
	fit_wrapped(hover_label)
	hover_label.size.y=maxf(38.0,hover_label.size.y)
	hover_panel.size.y=hover_label.size.y+14.0
	var hover_x: float=local.x+20.0
	if hover_x+hover_panel.size.x>WORLD_RECT.end.x-8.0: hover_x=local.x-hover_panel.size.x-20.0
	var hover_y: float=local.y+18.0
	if hover_y+hover_panel.size.y>WORLD_RECT.end.y-8.0: hover_y=local.y-hover_panel.size.y-18.0
	hover_panel.position=Vector2(clampf(hover_x,WORLD_RECT.position.x+8.0,WORLD_RECT.end.x-hover_panel.size.x-8.0),clampf(hover_y,WORLD_RECT.position.y+8.0,WORLD_RECT.end.y-hover_panel.size.y-8.0))
	hover_panel.visible=not hover_label.text.strip_edges().is_empty()
	return hover_panel.visible

func update_world_hover(local: Vector2) -> void:
	var hover_enabled:=playing and not paused and placement=="" and not harvest_mode and not dragging and WORLD_RECT.has_point(local)
	var entity_id:=entity_at(screen_world(local)) if hover_enabled else 0
	show_world_entity_hover(entity_id,local)

func screen_world(local: Vector2) -> Vector2:
	return renderer.camera+(local-WORLD_RECT.position-WORLD_RECT.size*0.5-renderer.visual_offset)/renderer.zoom

func edge_scroll_direction(local: Vector2) -> Vector2:
	var direction:=Vector2.ZERO
	direction.x-=clampf((WORLD_RECT.position.x+EDGE_SCROLL_BAND-local.x)/EDGE_SCROLL_BAND,0.0,1.0)
	direction.x+=clampf((local.x-(WORLD_RECT.end.x-EDGE_SCROLL_BAND))/EDGE_SCROLL_BAND,0.0,1.0)
	direction.y-=clampf((WORLD_RECT.position.y+EDGE_SCROLL_BAND-local.y)/EDGE_SCROLL_BAND,0.0,1.0)
	direction.y+=clampf((local.y-(WORLD_RECT.end.y-EDGE_SCROLL_BAND))/EDGE_SCROLL_BAND,0.0,1.0)
	return direction.normalized() if direction.length()>1.0 else direction

func entity_at(point: Vector2) -> int:
	var best := 0
	var distance := 32.0
	for e in sim.entities.values():
		if e.owner!=local_owner() and not sim.is_visible(e,local_owner()): continue
		if e.building:
			var d: Dictionary = sim.definition(e)
			var footprint := sim.footprint(e)
			if Rect2(e.pos-Vector2(sim.footprint(e)[0],sim.footprint(e)[1])*sim.grid.tile*0.5,Vector2(sim.footprint(e)[0],sim.footprint(e)[1])*sim.grid.tile).has_point(point): best=e.id
		elif e.pos.distance_to(point)<distance: distance=e.pos.distance_to(point); best=e.id
	return best

func _unhandled_input(event: InputEvent) -> void:
	if online.active and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ENTER:
		toggle_chat(); get_viewport().set_input_as_handled(); return
	if is_instance_valid(chat_input) and chat_input.has_focus(): return
	if intro_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if remap_action!="":
			if event.keycode==KEY_ESCAPE:
				remap_action=""; notify("TASTENÄNDERUNG ABGEBROCHEN"); show_options(show_pause if playing else show_main_menu,"STEUERUNG"); return
			var action_name := remap_action
			hotkeys[action_name]=event.keycode; remap_action=""; persist_settings(); notify("TASTE ZUGEWIESEN: "+action_name.to_upper()); show_options(show_pause if playing else show_main_menu,"STEUERUNG"); return
		if event.keycode==KEY_ESCAPE:
			if harvest_mode: harvest_mode=false; return
			if placement!="": placement=""; renderer.placement=""; return
			if playing:
				if paused and not ended: resume_game()
				elif not ended: show_pause()
			else: clear(overlay)
			return
		if not playing: return
		if modal_overlay_active(): return
		if event.keycode==hotkeys.load: load_game(); return
		if event.keycode==hotkeys.save: save_game(); return
		if paused: return
		if placement!="" and event.keycode in [KEY_R,KEY_E,KEY_Q]:
			rotate_placement(-1 if event.keycode==KEY_Q else 1); return
		if event.keycode==KEY_F3:
			profiler_overlay_visible=not profiler_overlay_visible
			renderer.profile_enabled=profiler_overlay_visible or fps_auto_profile
			update_hud()
		if event.keycode==hotkeys.attack and not selected.is_empty(): attack_mode=true; notify("Angriffsmarsch: Ziel mit Linksklick setzen.")
		if event.keycode==hotkeys.stop: dispatch_order(selected,Vector2.ZERO,"stop")
		if event.keycode==hotkeys.hold: dispatch_order(selected,Vector2.ZERO,"hold")
		if event.keycode==hotkeys.guard: dispatch_order(selected,Vector2.ZERO,"guard")
		if event.keycode==hotkeys.repair: repair_selection()
		if event.keycode==hotkeys.home: renderer.camera=sim.buildings(local_owner(),"core")[0].pos if not sim.buildings(local_owner(),"core").is_empty() else renderer.camera
		if event.keycode==hotkeys.event: renderer.camera=last_event
		if event.keycode>=KEY_1 and event.keycode<=KEY_9:
			var key: int = event.keycode-KEY_0
			if event.ctrl_pressed: groups[key]=selected.duplicate(); notify("Gruppe %d gespeichert." % key)
			else:
				selected=groups.get(key,[]).duplicate()
				if group_last==key and Time.get_ticks_msec()/1000.0-group_time<0.4 and not selected.is_empty():
					if sim.entities.has(int(selected[0])): renderer.camera=sim.entities[int(selected[0])].pos
				group_last=key; group_time=Time.get_ticks_msec()/1000.0
		if event.keycode>=KEY_F1 and event.keycode<=KEY_F4 and event.keycode!=KEY_F3:
			if event.shift_pressed: bookmarks[event.keycode]=renderer.camera
			elif bookmarks.has(event.keycode): renderer.camera=bookmarks[event.keycode]
	if not playing or paused or modal_overlay_active(): return
	var local := get_local_mouse_position()
	if pointer_local.x>-9000: local=pointer_local
	if event is InputEventMouse:
		local=get_global_transform_with_canvas().affine_inverse()*event.position
	var in_world := WORLD_RECT.has_point(local)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE: middle_drag=event.pressed and in_world
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and in_world: renderer.zoom=minf(2.5 if not classic else 1.5,renderer.zoom+0.25); clamp_camera()
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and in_world: renderer.zoom=maxf(0.75,renderer.zoom-0.25); clamp_camera()
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if event.pressed and in_world:
				if placement!="" or harvest_mode:
					placement=""; renderer.placement=""; harvest_mode=false; return
				right_held=true; right_panning=false; right_start=local; right_point=screen_world(local)
			elif not event.pressed and right_held:
				if not right_panning and in_world: issue_context_order(right_point)
				right_held=false; right_panning=false
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and in_world:
				var point := screen_world(local)
				if harvest_mode:
					var cell := sim.grid.cell(point)
					if not sim.grid.inside(cell) or sim.explored[local_owner()][cell.y*sim.grid.width+cell.x]==0 or float(sim.grid.resources.get(sim.grid.key(cell),0))<=0:
						notify("Wähle ein Solaritfeld."); music.cue("error"); return
					dispatch_order(selected,point,"harvest"); harvest_mode=false
					renderer.command_marker=point; renderer.marker_time=0.8
					notify("Solaritfeld zugewiesen. Der Sammler sammelt und lädt automatisch ab."); return
				if placement!="":
					var reason := sim.build_reason(placement,local_owner(),sim.grid.cell(point),placement_rotation)
					if reason=="": submit_player_command({"type":"build","owner_id":local_owner(),"kind":placement,"rotation":placement_rotation,"cell":[sim.grid.cell(point).x,sim.grid.cell(point).y]}); placement=""; renderer.placement=""
					else: notify(reason); music.cue("error")
					return
				if attack_mode: dispatch_order(selected,point,"attack_move"); attack_mode=false; music.cue("move"); return
				drag_start=point; dragging=true; select_same=event.double_click or event.ctrl_pressed
				renderer.selecting=true; renderer.selection_rect=Rect2(point,Vector2.ZERO)
			elif not event.pressed and dragging:
				var point := screen_world(local)
				inspected=0
				if not event.shift_pressed: selected=[]
				if point.distance_to(drag_start)>8:
					var rect := Rect2(drag_start,point-drag_start).abs()
					for e in sim.entities.values():
						if e.owner==local_owner() and not e.building and rect.has_point(e.pos) and not selected.has(e.id): selected.append(e.id)
				else:
					var id := entity_at(point)
					if id>0 and sim.entities[id].owner==local_owner():
						if select_same:
							for e in sim.entities.values():
								if e.owner==local_owner() and e.kind==sim.entities[id].kind and absf(e.pos.x-renderer.camera.x)<WORLD_RECT.size.x/2/renderer.zoom and absf(e.pos.y-renderer.camera.y)<WORLD_RECT.size.y/2/renderer.zoom and not selected.has(e.id): selected.append(e.id)
						elif not selected.has(id): selected.append(id)
					elif id>0:
						selected=[]; inspected=id
				dragging=false; renderer.selecting=false; music.cue("select"); update_hud()
	if event is InputEventMouseMotion:
		if middle_drag: renderer.camera-=event.relative/(renderer.zoom*(1.0/3.0 if classic else 1.0)); clamp_camera()
		if dragging: renderer.selection_rect=Rect2(drag_start,screen_world(local)-drag_start).abs()

func _process(dt: float) -> void:
	_advance_online_directory(dt)
	if is_instance_valid(online_directory) and not online_directory.published_lobby_id.is_empty():
		if not online.is_host() or online.connected or online.mission_started:
			online_directory.close_lobby()
			online_directory_message = "Öffentliche Lobby geschlossen · Mitspieler verbunden" if online.connected else "Öffentliche Lobby geschlossen"
			public_lobby_closed_for_guest = true
			if not online.connected: public_lobby_requested = false
	if is_instance_valid(renderer): renderer.visual_paused=paused
	if is_instance_valid(online_status_label) and online.active:
		var connection_state := "● VERBUNDEN" if online.connected else ("… VERBINDET" if online.role == "client" else "○ WARTET AUF MITSPIELER")
		online_status_label.text = connection_state + "  ·  UDP " + str(OnlineSession.DEFAULT_PORT) + ("  ·  PING %d MS" % online.ping_ms if online.ping_ms >= 0 else "")
	monitor_frame_rate(dt)
	if is_instance_valid(renderer): renderer.profile_sim_ms=0.0
	if is_instance_valid(connection_label):
		var sync: String="SYNCHRON" if online.is_host() or (online.last_snapshot_at>0 and Time.get_ticks_msec()-online.last_snapshot_at<1500) else "WARTE AUF SPIELSTAND"
		connection_label.text="%s · PING %s · %s"%["1:1" if online.is_versus() else "KOOP",str(online.ping_ms)+" ms" if online.ping_ms>=0 else "–",sync if online.connected else "GETRENNT"]
	if not playing or sim==null: return
	if paused or modal_overlay_active():
		suppress_world_hover()
		if paused and online.is_host(): online.advance_host(dt,sim)
		return
	if sim.online_mode=="versus" and (not online.active or not online.connected): return
	var step := 1.0/float(db.rules.tick_rate)
	var sim_started := Time.get_ticks_usec() if renderer.profile_enabled else 0
	if online.is_client():
		network_blend=minf(0.25,network_blend+dt)
	else:
		accumulator+=minf(dt,0.15)
		while accumulator>=step:
			render_previous=render_current
			sim.tick(step)
			match_recorder.observe(sim)
			render_current=capture_render_state()
			accumulator-=step
	if renderer.profile_enabled: renderer.profile_sim_ms=float(Time.get_ticks_usec()-sim_started)/1000.0
	if online.is_client():
		renderer.set_interpolation(render_previous,render_current,clampf(network_blend/0.25,0.0,1.0))
	else:
		renderer.set_interpolation(render_previous,render_current,clampf(accumulator/step,0.0,1.0))
	if online.is_host(): online.advance_host(dt,sim)
	var local := get_local_mouse_position()
	if pointer_local.x>-9000: local=pointer_local
	if WORLD_RECT.has_point(local):
		update_world_hover(local)
		renderer.placement=placement
		renderer.placement_rotation=placement_rotation
		var direction := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_J) or (selected.is_empty() and Input.is_key_pressed(KEY_A)): direction.x-=1
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_D): direction.x+=1
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): direction.y-=1
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_K) or (selected.is_empty() and Input.is_key_pressed(KEY_S)): direction.y+=1
		if is_instance_valid(chat_input) and chat_input.has_focus(): direction=Vector2.ZERO
		# With a selection, A/S issue combat orders. Arrow keys always pan.
		if edge_scroll and not (is_instance_valid(chat_input) and chat_input.has_focus()) and not dragging and not right_held and not middle_drag:
			direction+=edge_scroll_direction(local)
		renderer.camera+=direction*680*dt/renderer.zoom
		clamp_camera()
		if placement!="": renderer.placement_cell=sim.grid.cell(screen_world(local))
	else:
		hovered_entity_id=0
		renderer.hovered_entity_id=0
		hover_panel.visible=false
		renderer.placement=""
	notice_timer-=dt
	if is_instance_valid(alert_panel): alert_panel.visible=notice_timer>0 or placement!=""
	if is_instance_valid(notification): notification.modulate=Color(1,0.9+sin(notice_timer*10)*0.1,0.7+sin(notice_timer*10)*0.3) if notice_timer>4.5 else Color.WHITE
	if notice_timer<=0 and is_instance_valid(notification):
		if placement!="": notification.text="%d° · R / E drehen · Q zurück · %s" % [placement_rotation*90,sim.build_reason(placement,local_owner(),renderer.placement_cell,placement_rotation)]
		else: notification.text=""
	update_timer-=dt
	if update_timer<=0: update_hud(); update_timer=0.15
	autosave_timer-=dt
	if autosave_timer<=0: save_game("user://autosave.json",false); autosave_timer=120
	if sim.result!="" and not ended: ended=true; show_end()

func monitor_frame_rate(dt: float) -> void:
	if dt<=0.0: return
	fps_sample_elapsed+=dt
	fps_sample_frames+=1
	if fps_sample_elapsed<0.4: return
	var measured_fps:=float(fps_sample_frames)/fps_sample_elapsed
	if is_instance_valid(fps_label):
		fps_label.text="FPS %02d" % roundi(measured_fps)
		fps_label.add_theme_color_override("font_color",MINT if measured_fps>=60.0 else (GOLD if measured_fps>=50.0 else Color("ff765f")))
	if playing and sim!=null:
		record_performance_sample(measured_fps,fps_sample_elapsed)
	fps_sample_elapsed=0.0
	fps_sample_frames=0

func record_performance_sample(measured_fps: float, sample_seconds: float) -> void:
	if measured_fps<LOW_FPS_WARNING_THRESHOLD:
		if not fps_auto_profile and not profiler_overlay_visible:
			fps_auto_profile=true
			renderer.profile_enabled=true
		low_fps_seconds+=sample_seconds
		low_fps_minimum=minf(low_fps_minimum,measured_fps)
		low_fps_weighted_sum+=measured_fps*sample_seconds
		low_fps_recorded_seconds+=sample_seconds
		low_fps_recovery_seconds=0.0
		if measured_fps<LOW_FPS_CRITICAL_THRESHOLD:
			low_fps_critical_seconds+=sample_seconds
			low_fps_critical_minimum=minf(low_fps_critical_minimum,measured_fps)
			low_fps_critical_weighted_sum+=measured_fps*sample_seconds
			low_fps_critical_recorded_seconds+=sample_seconds
		else:
			low_fps_critical_seconds=0.0
			low_fps_critical_minimum=INF
			low_fps_critical_weighted_sum=0.0
			low_fps_critical_recorded_seconds=0.0
		if not low_fps_active and low_fps_seconds>=LOW_FPS_TRIGGER_SECONDS:
			low_fps_active=true
			write_performance_event("LOW_FPS_WARNING",low_fps_seconds,low_fps_minimum,low_fps_weighted_sum/maxf(low_fps_recorded_seconds,0.001))
		elif low_fps_active and not low_fps_critical_logged and low_fps_critical_seconds>=LOW_FPS_CRITICAL_TRIGGER_SECONDS:
			low_fps_critical_logged=true
			write_performance_event("LOW_FPS_CRITICAL",low_fps_critical_seconds,low_fps_critical_minimum,low_fps_critical_weighted_sum/maxf(low_fps_critical_recorded_seconds,0.001))
		elif low_fps_active:
			write_performance_event("LOW_FPS_SAMPLE",sample_seconds,measured_fps,measured_fps)
	elif low_fps_active:
		if measured_fps>=RECOVERY_FPS_THRESHOLD:
			low_fps_recovery_seconds+=sample_seconds
		if low_fps_recovery_seconds>=FPS_RECOVERY_TRIGGER_SECONDS:
			write_performance_event("RECOVERED",low_fps_seconds,low_fps_minimum,low_fps_weighted_sum/maxf(low_fps_recorded_seconds,0.001))
			reset_low_fps_event()
	else:
		reset_low_fps_event()

func reset_low_fps_event() -> void:
	low_fps_seconds=0.0
	low_fps_minimum=INF
	low_fps_weighted_sum=0.0
	low_fps_recorded_seconds=0.0
	low_fps_critical_seconds=0.0
	low_fps_critical_minimum=INF
	low_fps_critical_weighted_sum=0.0
	low_fps_critical_recorded_seconds=0.0
	low_fps_recovery_seconds=0.0
	low_fps_active=false
	low_fps_critical_logged=false
	if fps_auto_profile:
		fps_auto_profile=false
		if is_instance_valid(renderer): renderer.profile_enabled=profiler_overlay_visible

func write_performance_event(event_type: String, duration: float, minimum_fps: float, average_fps: float) -> void:
	var directory:=performance_log_path.get_base_dir()
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var existed:=FileAccess.file_exists(performance_log_path)
	var file:=FileAccess.open(performance_log_path,FileAccess.READ_WRITE if existed else FileAccess.WRITE)
	if file==null:
		if not performance_log_error_reported:
			push_warning("Could not write performance log: "+error_string(FileAccess.get_open_error()))
			performance_log_error_reported=true
		return
	if existed: file.seek_end()
	else: file.store_line("timestamp,event,mission_time_s,duration_s,average_fps,minimum_fps,entities,units,buildings,friendly_units,enemy_units,friendly_buildings,enemy_buildings,visible_units,fog_culled_units,offscreen_culled_units,visible_buildings,vfx,sim_projectiles,sim_impacts,particles,tracks,visual_bursts,ruins,craters,draw_calls,primitives,process_ms,physics_ms,frame_ms,unaccounted_frame_ms,render_ms,terrain_ms,ground_fx_ms,wrecks_ms,buildings_ms,vehicles_ms,tracks_ms,projectiles_ms,impacts_ms,explosions_ms,smoke_ms,fog_ms,sim_ms,ui_update_ms,vehicle_cache_size,vehicle_cache_queue,vehicle_cache_pending,vehicle_cache_hits,vehicle_cache_misses,building_cache_size,building_cache_queue,building_cache_pending,building_cache_hits,building_cache_misses,resolution,zoom")
	var total_units:=0
	var total_buildings:=0
	var friendly_units:=0
	var enemy_units:=0
	var friendly_buildings:=0
	var enemy_buildings:=0
	for entity in sim.entities.values():
		if entity.building:
			total_buildings+=1
			if entity.owner==local_owner(): friendly_buildings+=1
			else: enemy_buildings+=1
		else:
			total_units+=1
			if entity.owner==local_owner(): friendly_units+=1
			else: enemy_units+=1
	var process_ms:=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	var physics_ms:=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	var frame_ms:=1000.0/maxf(average_fps,0.01)
	var unaccounted_ms:=maxf(0.0,frame_ms-process_ms-physics_ms)
	var viewport_size:=renderer.get_viewport_rect().size
	var values:Array = [Time.get_datetime_string_from_system(false),event_type,"%.1f"%sim.time,"%.2f"%duration,"%.2f"%average_fps,"%.2f"%minimum_fps,str(sim.entities.size()),str(total_units),str(total_buildings),str(friendly_units),str(enemy_units),str(friendly_buildings),str(enemy_buildings),str(renderer.visible_mobile_count),str(renderer.culled_mobile_fog_count),str(renderer.culled_mobile_offscreen_count),str(renderer.visible_building_count),str(renderer.active_vfx_count),str(sim.projectiles.size()),str(sim.effects.size()),str(renderer.combat_fx.particles.size()),str(renderer.tracks.size()),str(renderer.visual_bursts.size()),str(renderer.combat_fx.ruins.size()),str(renderer.combat_fx.craters.size()),str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),"%.2f"%process_ms,"%.2f"%physics_ms,"%.2f"%frame_ms,"%.2f"%unaccounted_ms,"%.2f"%renderer.profile_total_ms,"%.2f"%renderer.profile_terrain_ms,"%.2f"%renderer.profile_ground_fx_ms,"%.2f"%renderer.profile_wrecks_ms,"%.2f"%renderer.profile_buildings_ms,"%.2f"%renderer.profile_vehicles_ms,"%.2f"%renderer.profile_tracks_ms,"%.2f"%renderer.profile_projectiles_ms,"%.2f"%renderer.profile_impacts_ms,"%.2f"%renderer.profile_explosions_ms,"%.2f"%renderer.profile_smoke_ms,"%.2f"%renderer.profile_fog_ms,"%.2f"%renderer.profile_sim_ms,"%.2f"%renderer.profile_ui_ms,str(renderer.vehicle_texture_cache.size()),str(renderer.vehicle_cache_queue.size()),str(renderer.vehicle_cache_pending.size()),str(renderer.vehicle_cache_hits),str(renderer.vehicle_cache_misses),str(renderer.building_texture_cache.size()),str(renderer.building_cache_queue.size()),str(renderer.building_cache_pending.size()),str(renderer.building_cache_hits),str(renderer.building_cache_misses),"%dx%d"%[roundi(viewport_size.x),roundi(viewport_size.y)],"%.2f"%renderer.zoom]
	var row:=PackedStringArray()
	for value in values: row.append(str(value))
	file.store_line(",".join(row))
	file.close()
	print("PERFORMANCE EVENT ",event_type," | "," FPS ",snappedf(average_fps,0.1)," min ",snappedf(minimum_fps,0.1)," | units ",total_units," buildings ",total_buildings," vfx ",renderer.active_vfx_count)

func clamp_camera() -> void:
	if sim==null: return
	var half := WORLD_RECT.size*0.5/renderer.zoom
	var max_size := Vector2(sim.grid.width,sim.grid.height)*sim.grid.tile
	renderer.camera.x=clampf(renderer.camera.x,minf(half.x,max_size.x/2),maxf(max_size.x-half.x,max_size.x/2))
	renderer.camera.y=clampf(renderer.camera.y,minf(half.y,max_size.y/2),maxf(max_size.y-half.y,max_size.y/2))

func dispatch_order(ids: Array, point: Vector2, order: String = "move", target_id: int = 0) -> bool:
	var actors := ids.duplicate()
	if order in ["harvest","return"]: actors=actors.filter(func(id):return sim.entities.has(int(id)) and sim.entities[int(id)].kind=="harvester")
	if actors.size()==1 and sim.entities.has(int(actors[0])) and sim.entities[int(actors[0])].kind=="factory" and order in ["move","attack","attack_move"]: order="rally"
	return submit_player_command({"type":order,"owner_id":local_owner(),"ids":actors,"point":[point.x,point.y],"target_id":target_id})

func issue_context_order(point: Vector2) -> void:
	var id := entity_at(point)
	var order := "move"
	if id>0 and sim.entities[id].owner!=local_owner(): order="attack"
	elif sim.grid.inside(sim.grid.cell(point)) and sim.explored[local_owner()][sim.grid.cell(point).y*sim.grid.width+sim.grid.cell(point).x]>0 and float(sim.grid.resources.get(sim.grid.key(sim.grid.cell(point)),0))>0: order="harvest"
	elif id>0 and sim.entities[id].owner==local_owner() and sim.entities[id].kind=="refinery": order="return"
	dispatch_order(selected,point,order,id if order=="attack" else 0)
	renderer.command_marker=point; renderer.marker_time=0.8; music.cue("move")
	if order=="harvest": notify("Solaritfeld zugewiesen: sammeln und automatisch abladen.")

func on_presentation(kind: String, data: Dictionary) -> void:
	if kind=="destroy" and data.has("id"):
		selected.erase(int(data.id))
		if inspected==int(data.id): inspected=0
		renderer.selected=selected.duplicate()
	var cell := sim.grid.cell(data.pos)
	if not sim.grid.inside(cell) or sim.fog[local_owner()][cell.y*sim.grid.width+cell.x]==0: return
	renderer.combat_fx.emit_effect(kind,data,renderer.camera.distance_to(data.pos))
	var distance_gain := clampf(1.0-renderer.camera.distance_to(data.pos)/1600.0,0.08,1.0)
	if kind=="shot": music.cue(renderer.combat_fx.family(data.weapon).to_lower()+"_shot",0.8*distance_gain)
	if kind=="impact": music.cue(renderer.combat_fx.family(data.weapon).to_lower()+"_impact",0.7*distance_gain)
	if kind=="destroy":
		if data.get("kind","")=="core": music.cue("alarm",0.6); music.cue("core_impact",0.9)
		notify(("EIGENES GEBÄUDE ZERSTÖRT" if data.building else "FAHRZEUG VERLOREN") if data.owner==local_owner() else ("FEINDLICHES GEBÄUDE ZERSTÖRT" if data.building else "FEINDLICHES FAHRZEUG ZERSTÖRT"))
		if is_instance_valid(minimap): minimap.ping(data.pos,Color("f34c32"))
	if kind=="hit" and data.owner==local_owner() and not data.building and notice_timer<=0:
		notify("FAHRZEUG UNTER BESCHUSS"); music.cue("alarm")
		if is_instance_valid(minimap): minimap.ping(data.pos,Color("f34c32"))

func on_event(kind: String, pos: Vector2, message: String) -> void:
	var visible := false
	if sim!=null:
		var cell := sim.grid.cell(pos)
		visible=sim.grid.inside(cell) and sim.fog[local_owner()][cell.y*sim.grid.width+cell.x]>0
	if kind in ["shot","explosion"]:
		if visible:
			if kind=="explosion": music.cue(kind,clampf(1.0-pos.distance_to(renderer.camera)/1200.0,0.05,0.8))
	else:
		if not visible: return
		renderer.visual_event(kind,pos)
		music.cue(kind)
		if message!="": notify(message)
		last_event=pos
		if kind in ["alarm","complete","ready"] and is_instance_valid(minimap): minimap.ping(pos,GOLD if kind=="alarm" else sim.team_color(local_owner()))

func notify(message: String) -> void:
	if is_instance_valid(notification): notification.text=message; fit_wrapped(notification)
	notice_timer=6.0
	if is_instance_valid(alert_panel): alert_panel.visible=true

func show_pause() -> void:
	if not playing: return
	paused=not online.active; music.set_paused(paused); dragging=false; renderer.selecting=false; right_held=false; middle_drag=false
	clear(overlay)
	var p := panel(overlay,Rect2(650,215,620,650),Color("2b221b"))
	label(p,"KOMMANDO UNTERBROCHEN",Vector2(40,32),18,MINT)
	label(p,"Pause",Vector2(40,74),48,GOLD)
	var actions := [["WEITERSPIELEN",resume_game],["SPEICHERN",func():save_game(); show_pause()],["LADEN",func():show_load_dialog(show_pause)],["OPTIONEN",func():show_options(show_pause)],["UPDATEINFO",func():show_updates(show_pause)],["EINSATZ NEU STARTEN",start_game],["HAUPTMENÜ",show_main_menu]]
	if online.active:
		actions=[["WEITERSPIELEN",resume_game],["CHAT",func():resume_game(); toggle_chat()],["OPTIONEN",func():show_options(show_pause)],["HAUPTMENÜ / TRENNEN",show_main_menu]]
	if sim.online_mode=="versus" and not online.active: actions=[["WIEDERBEITRETEN",show_online_menu],["HAUPTMENÜ",show_main_menu]]
	var y := 163
	for action in actions: button(p,action[0],Rect2(40,y,540,54),action[1]); y+=70

func resume_game() -> void:
	clear(overlay); paused=false; music.set_paused(false)

func show_end() -> void:
	if side_panel!=null:
		side_panel.modulate=Color(1,1,1,0.34)
		side_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if sim.online_mode=="versus" or (online.active and sim.online_mode=="coop"):
		show_online_end(); return
	paused=true
	if is_instance_valid(online_stats): online_stats.stop_playing()
	clear(overlay)
	var p := panel(overlay,Rect2(585,155,750,770),Color("2b221b"))
	label(p,"EINSATZ ABGESCHLOSSEN",Vector2(42,28),18,MINT)
	var end_title:=str(db.mission.get("victory_title","Sektor gesichert")) if sim.result=="victory" else str(db.mission.get("defeat_title","Signal verloren"))
	label(p,end_title,Vector2(42,72),43,GOLD)
	var s: Dictionary = sim.stats
	var result_score:=calculate_run_score() if sim.result=="victory" and not online.active else 0
	var newly_recorded:=record_commander_result("singleplayer",result_score)
	label(p,"KOMMANDANT / "+str(commander_profile.data.nickname).to_upper(),Vector2(44,132),15,MUTED)
	label(p,"Zeit                %02d:%02d\nSolarit geliefert   %d\nFahrzeuge gebaut     %d\nFahrzeuge verloren   %d\nFeinde zerstört      %d\nGebäude errichtet    %d\nGebäude verloren     %d" % [int(sim.time)/60,int(sim.time)%60,int(s.gathered),s.produced,s.lost,s.kills,s.built,s.buildings_lost],Vector2(44,164),23,Color("c8d8ce"))
	var optional_total:=optional_objective_count()
	var optional_done:=completed_optional_objective_count()
	var medal:=mission_completion_medal(optional_total,optional_done) if sim.result=="victory" else "NICHT ABGESCHLOSSEN"
	label(p,"BEWERTUNG  ·  %s     NEBENZIELE  %d / %d     BONUS  +%s" % [medal,optional_done,optional_total,format_score(optional_done*2500)],Vector2(44,375),17,GOLD,670)
	if sim.result=="victory":
		highscore_mission_index=mission_index
		if not online.active: record_campaign_victory(medal)
		var score_result := record_highscore() if not online.active else {"score": 0, "rank": 0, "new_best": false}
		if not online.active and is_instance_valid(online_stats) and int(score_result.get("score", 0)) > 0:
			online_stats.submit_highscore({
				"run_id": run_id,
				"mission": str(db.mission.get("id", "")),
				"mission_name": str(db.mission.get("name", db.mission.get("id", "Einsatz"))),
				"score": int(score_result.score),
				"time": float(sim.time),
				"difficulty": difficulty,
				"faction": str(db.factions[faction].name)
			})
		var ranking_text := "PUNKTE  %s    ·    PLATZ %s" % [format_score(int(score_result.score)),"%d / 10" % int(score_result.rank) if int(score_result.rank)>0 else "AUSSERHALB DER TOP 10"]
		if score_result.new_best: ranking_text+="    ·    NEUER BESTWERT"
		label(p,ranking_text,Vector2(44,435),18,GOLD,660)
		if bool(newly_recorded.get("new_best",false)): label(p,"NEUER PERSÖNLICHER REKORD",Vector2(44,492),16,MINT,660)
		label(p,"BESTENLISTE   "+leaderboard_preview(),Vector2(44,467),15,MINT,660)
	if sim.result=="victory" and mission_index<MISSION_PATHS.size()-1:
		button(p,"ERNEUT",Rect2(42,670,190,58),start_game)
		button(p,"NÄCHSTER EINSATZ",Rect2(247,670,255,58),func():select_mission(mission_index+1))
		button(p,"HAUPTMENÜ",Rect2(517,670,185,58),show_main_menu)
	else:
		button(p,"ERNEUT SPIELEN",Rect2(42,670,310,58),start_game)
		button(p,"HAUPTMENÜ",Rect2(392,670,310,58),show_main_menu)

func record_commander_result(mode: String, score: int) -> Dictionary:
	if sim == null or sim.result not in ["victory", "defeat"] or run_id.is_empty(): return {"new_best": false}
	if not match_report_saved:
		match_report_saved=match_recorder.finish(sim)
	if online.is_host() and match_report_saved: online.send_match_report(match_recorder.report)
	var mission_name := str(db.mission.get("display_name", db.mission.get("name", db.mission.get("id", ""))))
	var old_best := int(commander_profile.data.statistics.best_score)
	var did_record: bool = commander_profile.record_result({
		"result_id": run_id,
		"mode": mode,
		"outcome": str(sim.result),
		"active_seconds": float(sim.time),
		"score": score,
		"mission_name": mission_name,
		"mission": str(db.mission.get("id", "")),
		"match_report_id": run_id,
		"game_version": str(update_history.get("current_version", "unbekannt")),
		"difficulty": str(difficulty),
		"date": Time.get_date_string_from_system(false)
	})
	return {"recorded": did_record, "new_best": did_record and score > old_best and mode == "singleplayer" and sim.result == "victory"}

func _on_online_match_report(report: Dictionary) -> void:
	if sim==null or not online.is_client() or str(report.get("match_id", ""))!=run_id: return
	match_report_saved=match_recorder.store_host_report(report)

func _configure_online_stats() -> void:
	if not is_instance_valid(online_stats) or commander_profile == null:
		return
	online_stats.configure(commander_profile.data, online_stats_enabled, str(update_history.get("current_version", "unbekannt")))

func _on_online_stats_status(message: String) -> void:
	online_stats_status = message
	if not message.is_empty(): notify(message)

func _on_online_highscores_received(mission: String, entries: Array) -> void:
	online_highscore_cache[mission] = entries.duplicate(true)
	if is_instance_valid(overlay) and overlay.get_child_count() > 0:
		var panel_node := overlay.find_child("OnlineHighscoresPanel", true, false)
		if panel_node != null:
			show_highscores(show_main_menu, highscore_mission_index)

func show_menu_commander() -> void:
	# Keep the profile block to the right of the planet's outer glow (x <= 1651).
	label(ui, "KOMMANDANT", Vector2(1660, 64), 13, MUTED)
	var nickname := label(ui, str(commander_profile.data.nickname).to_upper() if commander_profile.has_identity() else "NICHT IDENTIFIZIERT", Vector2(1660, 86), 26, Color("e3e9df"))
	nickname.name = "MenuCommanderNickname"
	var nickname_font := nickname.get_theme_font("font")
	var point_size := 26
	while point_size > 12 and nickname_font.get_string_size(nickname.text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > 230:
		point_size -= 1
	nickname.add_theme_font_size_override("font_size", point_size)
	menu_buttons.commander = button(ui, "SPIELER WECHSELN" if commander_profile.has_identity() else "IDENTIFIKATION STARTEN", Rect2(1660, 124, 230, 28), func():show_profile_dialog(not commander_profile.has_identity(), show_main_menu, true))
	var link: Button = menu_buttons.commander
	link.name = "MenuCommanderChange"
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.add_theme_font_size_override("font_size", 13)
	link.add_theme_color_override("font_color", MUTED)
	link.add_theme_color_override("font_hover_color", MINT)
	link.add_theme_color_override("font_focus_color", MINT)
	link.add_theme_color_override("font_pressed_color", GOLD)
	for state in ["normal", "hover", "pressed", "disabled"]:
		link.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = MINT
	focus_style.border_width_bottom = 1
	link.add_theme_stylebox_override("focus", focus_style)

func show_profile_dialog(mandatory: bool, back: Callable = Callable(), return_to_menu: bool = false) -> void:
	if profile_dialog_open: return
	profile_dialog_open = true
	clear(overlay)
	var screen := get_viewport_rect().size
	var panel_size := Vector2(minf(760.0, screen.x - 48.0), minf(500.0, screen.y - 48.0))
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.016, 0.018, 0.70)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var p := panel(overlay, Rect2((screen - panel_size) * 0.5, panel_size), Color("202a29"))
	p.name = "CommanderProfileDialog"
	label(p, "SOLARIT / KOMMANDANTENAKTE", Vector2(34, 24), 17, MINT)
	label(p, "Identifikation", Vector2(34, 55), 37, GOLD)
	label(p, "Unter welchem Namen soll das Kommando dich führen?", Vector2(36, 111), 18, Color("d5ded5"), panel_size.x - 72)
	label(p, "SPIELERNAME", Vector2(36, 166), 13, MUTED)
	var entry := LineEdit.new()
	entry.name = "CommanderNickname"
	entry.text = str(commander_profile.data.get("nickname", ""))
	entry.max_length = 20
	entry.placeholder_text = "2 bis 20 Zeichen"
	entry.position = Vector2(36, 191)
	entry.size = Vector2(panel_size.x - 72, 46)
	entry.add_theme_font_size_override("font_size", 20)
	p.add_child(entry)
	var profile_notice := label(p, "Buchstaben, Zahlen, Leerzeichen, Bindestrich und Unterstrich sind möglich.\nNeue Bestenlisteneinträge verwenden den neuen Namen.\nMit aktivierter Online-Statistik werden Nickname und Siege an dl-home.de übertragen; abschaltbar unter Optionen → Profil.", Vector2(36, 253), 13, MUTED, panel_size.x - 72)
	profile_notice.name = "CommanderProfileNotice"
	var validation_y := maxf(326.0, profile_notice.position.y + profile_notice.size.y + 10.0)
	var validation := label(p, "Mindestens 2 Zeichen", Vector2(36, validation_y), 14, Color("c78262"), panel_size.x - 72)
	validation.name = "CommanderProfileValidation"
	var confirm := button(p, "BESTÄTIGEN", Rect2(panel_size.x - 256, panel_size.y - 62, 220, 42), func():
		if not commander_profile.set_nickname(entry.text):
			validation.text = "Name konnte nicht gespeichert werden."
			return
		_configure_online_stats()
		profile_dialog_open = false
		if mandatory or return_to_menu or not back.is_valid(): show_main_menu()
		else: show_commander_file(back)
	)
	confirm.name = "ConfirmCommanderProfile"
	confirm.disabled = PlayerProfileScript.validate_nickname(entry.text).is_empty()
	entry.text_changed.connect(func(value: String):
		var valid := not PlayerProfileScript.validate_nickname(value).is_empty()
		confirm.disabled = not valid
		validation.text = "Bereit zur Bestätigung" if valid else "2 bis 20 Zeichen · keine Steuerzeichen"
		validation.add_theme_color_override("font_color", MINT if valid else Color("c78262"))
	)
	if not mandatory:
		var cancel := button(p, "ABBRECHEN", Rect2(36, panel_size.y - 62, 190, 42), func():
			profile_dialog_open = false
			if back.is_valid(): back.call()
		)
		cancel.name = "CancelCommanderProfile"
	entry.grab_focus()

func show_commander_file(back: Callable = Callable()) -> void:
	if not commander_profile.has_identity(): show_profile_dialog(true, back); return
	clear(overlay)
	var screen := get_viewport_rect().size
	var panel_size := Vector2(minf(1120.0, screen.x - 48.0), minf(890.0, screen.y - 48.0))
	var p := panel(overlay, Rect2((screen - panel_size) * 0.5, panel_size), Color("202a29"))
	p.name = "CommanderDossier"
	var stats: Dictionary = commander_profile.data.statistics
	var all_modes: Array[String] = ["singleplayer", "duel", "coop"]
	var missions := 0
	var wins := 0
	var losses := 0
	for mode in all_modes:
		missions += int(stats[mode].missions)
		wins += int(stats[mode].wins)
		losses += int(stats[mode].losses)
	var rate := "— %" if wins + losses == 0 else ("%.1f %%" % (float(wins) / float(wins + losses) * 100.0)).replace(".", ",")
	label(p, "SOLARIT / KOMMANDANTENAKTE", Vector2(34, 24), 17, MINT)
	label(p, str(commander_profile.data.nickname).to_upper(), Vector2(34, 52), 39, GOLD)
	var rename := button(p, "SPIELERNAME ÄNDERN", Rect2(panel_size.x - 275, 40, 236, 40), func(): show_profile_dialog(false, back))
	rename.add_theme_font_size_override("font_size", 14)
	label(p, "DIENSTSTATISTIK", Vector2(36, 112), 14, MUTED)
	label(p, "%d\nEINSÄTZE" % missions, Vector2(38, 148), 30, Color("d8e0d8"), 190)
	label(p, "%d\nSIEGE" % wins, Vector2(252, 148), 30, MINT, 170)
	label(p, "%d\nNIEDERLAGEN" % losses, Vector2(438, 148), 30, Color("d8e0d8"), 205)
	label(p, rate + "\nSIEGQUOTE", Vector2(662, 148), 30, GOLD, 170)
	label(p, PlayerProfileScript.format_duration(float(stats.total_active_seconds)) + "\nSPIELZEIT", Vector2(855, 148), 25, Color("d8e0d8"), 210)
	var summary := "EINZELSPIELER   %d EINSÄTZE  ·  %d SIEGE  ·  %d NIEDERLAGEN\n1:1-DUELL   %d EINSÄTZE  ·  %d SIEGE  ·  %d NIEDERLAGEN\nKOOP   %d EINSÄTZE  ·  %d SIEGE  ·  %d NIEDERLAGEN" % [stats.singleplayer.missions, stats.singleplayer.wins, stats.singleplayer.losses, stats.duel.missions, stats.duel.wins, stats.duel.losses, stats.coop.missions, stats.coop.wins, stats.coop.losses]
	label(p, summary, Vector2(38, 265), 17, Color("cbd5ce"), panel_size.x - 76)
	var best_score := int(stats.best_score)
	label(p, "PERSÖNLICHER BESTWERT", Vector2(38, 366), 14, MUTED)
	label(p, format_score(best_score) if best_score > 0 else "—", Vector2(38, 390), 36, GOLD)
	if best_score > 0: label(p, str(stats.best_score_mission) + "  ·  " + str(stats.best_score_date), Vector2(330, 404), 16, Color("cbd5ce"), 600)
	label(p, "LETZTE EINSÄTZE", Vector2(38, 464), 14, MINT)
	button(p,"ALLE PARTIEBERICHTE",Rect2(panel_size.x-280,448,240,36),show_match_archive)
	var history: Array = commander_profile.data.history
	var history_scroll := ScrollContainer.new()
	history_scroll.name = "CommanderHistory"
	history_scroll.position = Vector2(38, 492)
	history_scroll.size = Vector2(panel_size.x - 76, panel_size.y - 570)
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(history_scroll)
	var history_rows := VBoxContainer.new()
	history_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_rows.add_theme_constant_override("separation", 6)
	history_scroll.add_child(history_rows)
	if history.is_empty(): label(history_rows, "Noch keine Einsätze abgeschlossen.", Vector2.ZERO, 16, MUTED, panel_size.x - 100)
	for index in mini(history.size(), 30):
		var item: Dictionary = history[index]
		var outcome := "SIEG" if item.outcome == "victory" else "NIEDERLAGE"
		var mode_name: String = str({"singleplayer": "EINZELSPIELER", "duel": "1:1-DUELL", "coop": "KOOP"}.get(str(item.mode), "EINSATZ"))
		var score_text := format_score(int(item.score)) + " P" if int(item.score) >= 0 else "—"
		var report_button:=Button.new()
		report_button.text="%s   /   %s   /   %s   /   %s   /   %s   /   %s     ›" % [str(item.date), str(item.mission), mode_name, outcome, PlayerProfileScript.format_duration(float(item.active_seconds)), score_text]
		report_button.custom_minimum_size=Vector2(panel_size.x-100,38)
		report_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		report_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		report_button.add_theme_font_size_override("font_size",14)
		report_button.pressed.connect(func():show_match_report(str(item.get("match_report_id", item.get("result_id", "")))))
		history_rows.add_child(report_button)
	button(p, "ZURÜCK", Rect2(36, panel_size.y - 60, 230, 40), func(): back.call() if back.is_valid() else show_main_menu())

func show_match_report(match_id: String) -> void:
	var safe_id:=RegEx.new()
	safe_id.compile("[^A-Za-z0-9_-]")
	var path:=MatchRecorderScript.ARCHIVE_DIR+"/"+safe_id.sub(match_id,"_",true).left(96)+".json"
	if match_id.is_empty() or not FileAccess.file_exists(path):
		show_error("Für diese Partie ist kein gespeicherter Statistikbericht vorhanden.")
		return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("schema_version",0))>MatchRecorderScript.SCHEMA_VERSION:
		show_error("Der Statistikbericht ist beschädigt oder stammt aus einer neueren Berichtsversion.")
		return
	var report: Dictionary=parsed
	clear(overlay)
	var screen:=get_viewport_rect().size
	var panel_size:=Vector2(minf(1420.0,screen.x-40),minf(980.0,screen.y-40))
	var p:=panel(overlay,Rect2((screen-panel_size)*0.5,panel_size),Color("202a29"))
	p.name="MatchReport"
	var sides: Array=report.get("sides",[])
	var side_names: Array[String]=["Spieler 1","Spieler 2"]
	var side_colors: Array[Color]=[Color("79d9bd"),Color("f47878")]
	for owner in mini(2,sides.size()):
		side_names[owner]=str(sides[owner].get("nickname","Spieler %d"%(owner+1)))
		side_colors[owner]=Color(str(sides[owner].get("team_color", "79d9bd" if owner==0 else "f47878")))
	var outcome:="SIEG" if str(report.get("outcome",""))=="victory" else "NIEDERLAGE"
	label(p,"PARTIEBERICHT / VERSION %s"%str(report.get("game_version","unbekannt")),Vector2(30,18),16,MINT)
	label(p,"%s  ·  %s  ·  %s"%[str(report.get("mission_name","Einsatz")),outcome,PlayerProfileScript.format_duration(float(report.get("duration_seconds",0.0)))],Vector2(30,42),28,GOLD)
	label(p,"%s  /  %s  /  %s"%[str(report.get("date","")),str(report.get("mode","" )).to_upper(),str(report.get("difficulty","" )).to_upper()],Vector2(32,80),14,MUTED)
	var samples: Array=report.get("samples",[])
	var chart_metrics: Array=[ ["credits","Solarit im Lager"], ["units","Fahrzeuge im Feld"], ["buildings","Gebäude im Feld"], ["produced","Fahrzeuge produziert"], ["gathered","Solarit gesammelt"], ["kills","Gegner zerstört"] ]
	for index in chart_metrics.size():
		var column:=index%2
		var row:=index/2
		var chart=MatchChartScript.new()
		chart.position=Vector2(30+column*680,116+row*215)
		chart.size=Vector2(660,195)
		chart.configure(samples,str(chart_metrics[index][0]),str(chart_metrics[index][1]),side_names,side_colors)
		p.add_child(chart)
	label(p,"EREIGNISSE",Vector2(30,770),14,MINT)
	var events_scroll:=ScrollContainer.new()
	events_scroll.position=Vector2(30,792)
	events_scroll.size=Vector2(panel_size.x-60,106)
	events_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(events_scroll)
	var event_rows:=VBoxContainer.new()
	event_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	events_scroll.add_child(event_rows)
	var events: Array=report.get("events",[])
	if events.is_empty(): label(event_rows,"Keine Ereignisse gespeichert.",Vector2.ZERO,13,MUTED,900)
	for event_item in events.slice(maxi(0,events.size()-80)):
		var event_owner:=int(event_item.get("owner",-1))
		var actor:=side_names[event_owner] if event_owner>=0 and event_owner<2 else "System"
		label(event_rows,"%02d:%02d  ·  %s  ·  %s  ·  %s"%[int(float(event_item.get("time",0.0)))/60,int(float(event_item.get("time",0.0)))%60,actor,str(event_item.get("description","")),str(event_item.get("entity_kind",""))],Vector2.ZERO,13,Color("cbd5ce"),panel_size.x-100)
	button(p,"ZURÜCK ZUR KOMMANDANTENAKTE",Rect2(30,panel_size.y-52,330,38),func():show_commander_file())

func show_match_archive() -> void:
	var directory:=DirAccess.open(MatchRecorderScript.ARCHIVE_DIR)
	var reports: Array[Dictionary]=[]
	if directory!=null:
		directory.list_dir_begin()
		var filename:=directory.get_next()
		while not filename.is_empty():
			if not directory.current_is_dir() and filename.ends_with(".json"):
				var parsed=JSON.parse_string(FileAccess.get_file_as_string(MatchRecorderScript.ARCHIVE_DIR+"/"+filename))
				if parsed is Dictionary and int(parsed.get("schema_version",0))<=MatchRecorderScript.SCHEMA_VERSION:
					reports.append(parsed)
			filename=directory.get_next()
		directory.list_dir_end()
	reports.sort_custom(func(a,b):return str(a.get("finished_at", ""))>str(b.get("finished_at", "")))
	clear(overlay)
	var screen:=get_viewport_rect().size
	var panel_size:=Vector2(minf(1100.0,screen.x-48.0),minf(850.0,screen.y-48.0))
	var p:=panel(overlay,Rect2((screen-panel_size)*0.5,panel_size),Color("202a29"))
	label(p,"KOMMANDANTENAKTE / PARTIEARCHIV",Vector2(32,24),18,MINT)
	label(p,"GESPEICHERTE PARTIEN  ·  %d"%reports.size(),Vector2(32,54),32,GOLD)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(32,112)
	scroll.size=Vector2(panel_size.x-64,panel_size.y-184)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var rows:=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",6)
	scroll.add_child(rows)
	if reports.is_empty(): label(rows,"Noch keine beendeten Partien archiviert.",Vector2.ZERO,16,MUTED,panel_size.x-100)
	for item in reports:
		var outcome:="SIEG" if str(item.get("outcome",""))=="victory" else "NIEDERLAGE"
		var match_button:=Button.new()
		match_button.text="%s  ·  %s  ·  %s  ·  %s  ·  Version %s"%[str(item.get("date","")),str(item.get("mission_name","Partie")),outcome,PlayerProfileScript.format_duration(float(item.get("duration_seconds",0.0))),str(item.get("game_version","?"))]
		match_button.custom_minimum_size=Vector2(panel_size.x-120,40)
		match_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		match_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		match_button.pressed.connect(func():show_match_report(str(item.get("match_id",""))))
		rows.add_child(match_button)
	button(p,"ZURÜCK ZUR KOMMANDANTENAKTE",Rect2(32,panel_size.y-58,330,40),func():show_commander_file())

func create_run_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(),randi()]

func load_campaign_progress() -> void:
	if not FileAccess.file_exists(campaign_progress_path): return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(campaign_progress_path))
	if not parsed is Dictionary or int(parsed.get("format_version",0))!=1: return
	var completed_value=parsed.get("completed",[])
	if not completed_value is Array: return
	var medals_value: Variant=parsed.get("mission_medals",{})
	var valid_medals: Dictionary={}
	if medals_value is Dictionary:
		for mission_id in medals_value:
			var medal_value:=str(medals_value[mission_id]).to_upper()
			if medal_value in ["BRONZE","SILBER","GOLD"]: valid_medals[str(mission_id)]=medal_value
	campaign_progress={"format_version":1,"unlocked_mission":clampi(int(parsed.get("unlocked_mission",0)),0,MISSION_PATHS.size()-1),"tech_level":clampi(int(parsed.get("tech_level",0)),0,2),"completed":completed_value.duplicate(),"mission_medals":valid_medals}

func record_campaign_victory(medal: String = "BRONZE") -> void:
	var completed_value: Array=campaign_progress.completed
	var mission_id:=str(db.mission.get("id",""))
	if not completed_value.has(mission_id): completed_value.append(mission_id)
	campaign_progress.completed=completed_value
	var medals_value: Variant=campaign_progress.get("mission_medals",{})
	var medals: Dictionary=medals_value.duplicate() if medals_value is Dictionary else {}
	var previous_medal:=str(medals.get(mission_id,""))
	if medal_rank(medal)>medal_rank(previous_medal): medals[mission_id]=medal.to_upper()
	campaign_progress.mission_medals=medals
	campaign_progress.unlocked_mission=maxi(int(campaign_progress.unlocked_mission),mini(mission_index+1,MISSION_PATHS.size()-1))
	campaign_progress.tech_level=maxi(int(campaign_progress.tech_level),mini(mission_index+1,2))
	var temporary:=campaign_progress_path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify(campaign_progress,"  ")); file.close()
	var err:=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(campaign_progress_path))
	if err!=OK: push_warning("Campaign progress could not be saved: "+error_string(err))

func calculate_run_score() -> int:
	var s: Dictionary=sim.stats
	var time_bonus:=maxf(0.0,1800.0-sim.time)*2.0
	var total:=1000.0+float(s.kills)*250.0+float(s.gathered)*0.5+float(s.produced)*120.0+float(s.built)*100.0+time_bonus-float(s.lost)*200.0-float(s.buildings_lost)*500.0
	return maxi(0,roundi(total))+completed_optional_objective_count()*2500

func optional_objective_count() -> int:
	var count:=0
	for objective_data in db.mission.get("objectives",[]):
		if bool(objective_data.get("optional",false)): count+=1
	return count

func completed_optional_objective_count() -> int:
	if sim==null or online.active: return 0
	var count:=0
	for objective_data in db.mission.get("objectives",[]):
		if bool(objective_data.get("optional",false)) and sim.objective_latched(objective_data): count+=1
	return count

func mission_completion_medal(optional_total: int, optional_done: int) -> String:
	if optional_total>0 and optional_done==optional_total and int(sim.stats.buildings_lost)==0: return "GOLD"
	if optional_done>0: return "SILBER"
	return "BRONZE"

func medal_rank(medal: String) -> int:
	return {"BRONZE":1,"SILBER":2,"GOLD":3}.get(medal.to_upper(),0)

func medal_color(medal: String) -> Color:
	return {"BRONZE":Color("cd8b58"),"SILBER":Color("c7d2d0"),"GOLD":GOLD}.get(medal.to_upper(),MUTED)

func format_score(score: int) -> String:
	var digits:=str(score)
	var groups: Array[String]=[]
	while digits.length()>3:
		groups.push_front(digits.substr(digits.length()-3))
		digits=digits.substr(0,digits.length()-3)
	groups.push_front(digits)
	return ".".join(groups)

func load_highscores() -> Dictionary:
	var empty: Dictionary={"format_version":1,"entries":[],"completed_runs":[]}
	if not FileAccess.file_exists(highscore_path): return empty
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(highscore_path))
	if not parsed is Dictionary or int(parsed.get("format_version",0))!=1 or not parsed.get("entries",[]) is Array: return empty
	var valid_entries: Array=[]
	for entry in parsed.entries:
		if entry is Dictionary and entry.has("mission") and entry.has("score") and entry.has("time"): valid_entries.append(entry)
	parsed["entries"]=valid_entries
	if not parsed.get("completed_runs",[]) is Array: parsed["completed_runs"]=[]
	return parsed

func save_highscores(data: Dictionary) -> bool:
	var temporary:=highscore_path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: push_warning("Highscore could not be written: "+error_string(FileAccess.get_open_error())); return false
	file.store_string(JSON.stringify(data,"",true,true)); file.close()
	return DirAccess.rename_absolute(temporary,highscore_path)==OK

func record_highscore() -> Dictionary:
	var data:=load_highscores()
	var entries: Array=data.entries
	var completed: Array=data.completed_runs
	if run_id.is_empty(): run_id=create_run_id()
	if completed.has(run_id):
		for previous in entries:
			if str(previous.get("run_id",""))==run_id:
				var saved_rank:=1
				for ranked in entries:
					if ranked.get("mission","")==db.mission.id and (int(ranked.score)>int(previous.score) or (int(ranked.score)==int(previous.score) and float(ranked.time)<float(previous.time))): saved_rank+=1
				return {"score":int(previous.score),"rank":saved_rank if saved_rank<=10 else 0,"new_best":false}
		return {"score":calculate_run_score(),"rank":0,"new_best":false}
	for existing in entries:
		if str(existing.get("run_id",""))==run_id:
			var previous_rank:=1
			for ranked in entries:
				if int(ranked.score)>int(existing.score) or (int(ranked.score)==int(existing.score) and float(ranked.time)<float(existing.time)): previous_rank+=1
			return {"score":int(existing.score),"rank":previous_rank,"new_best":false}
	var old_best:=0
	for old_entry in entries:
		if old_entry.get("mission","")==db.mission.id: old_best=maxi(old_best,int(old_entry.get("score",0)))
	var score:=calculate_run_score()
	var entry: Dictionary={"run_id":run_id,"profile_id":str(commander_profile.data.profile_id),"nickname":str(commander_profile.data.nickname),"mission":db.mission.id,"mission_name":db.mission.name,"score":score,"time":sim.time,"difficulty":difficulty,"faction":db.factions[faction].name,"date":Time.get_date_string_from_system(false),"gathered":int(sim.stats.gathered),"kills":int(sim.stats.kills),"lost":int(sim.stats.lost)}
	entries.append(entry)
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a.score)==int(b.score): return float(a.time)<float(b.time)
		return int(a.score)>int(b.score))
	var mission_count:=0
	var retained: Array=[]
	for ranked in entries:
		if ranked.get("mission","")!=db.mission.id: retained.append(ranked)
		elif mission_count<10: retained.append(ranked); mission_count+=1
	var rank:=1
	for ranked in retained:
		if ranked.get("mission","")!=db.mission.id: continue
		if str(ranked.get("run_id",""))==run_id: break
		rank+=1
	if not run_id.is_empty() and not completed.has(run_id): completed.append(run_id)
	data["entries"]=retained
	data["completed_runs"]=completed
	save_highscores(data)
	return {"score":score,"rank":rank if rank<=10 else 0,"new_best":score>old_best}

func leaderboard_preview() -> String:
	var rows: Array[String]=[]
	for entry in load_highscores().entries:
		if entry.get("mission","")!=db.mission.id: continue
		rows.append("%d. %s · %s" % [rows.size()+1,("> "+str(entry.get("nickname","UNBEKANNT")).to_upper()) if str(entry.get("profile_id",""))==str(commander_profile.data.profile_id) else str(entry.get("nickname","UNBEKANNT")).to_upper(),format_score(int(entry.score))])
		if rows.size()>=3: break
	return "   /   ".join(rows) if not rows.is_empty() else "Noch keine Siege gespeichert"

func difficulty_label(value: String) -> String:
	return {"easy":"Ruhig","normal":"Ausgewogen","hard":"Entschlossen"}.get(value,value)

func highscore_default_mission_index() -> int:
	if highscore_mission_index>=0 and highscore_mission_index<MISSION_PATHS.size(): return highscore_mission_index
	var completed: Array=campaign_progress.get("completed",[])
	for index in range(MISSION_PATHS.size()-1,-1,-1):
		var probe:=Catalog.new(MISSION_PATHS[index])
		if completed.has(str(probe.mission.get("id",""))): return index
	# If campaign progress is old/missing, use the newest mission for which this profile has a score.
	for index in range(MISSION_PATHS.size()-1,-1,-1):
		var probe:=Catalog.new(MISSION_PATHS[index])
		var mission_id:=str(probe.mission.get("id",""))
		for entry in load_highscores().entries:
			if str(entry.get("mission",""))==mission_id and str(entry.get("profile_id",""))==str(commander_profile.data.profile_id): return index
	return clampi(mission_index,0,MISSION_PATHS.size()-1)

func show_highscores(return_action: Callable = Callable(), requested_index: int = -1) -> void:
	if not return_action.is_valid(): return_action=show_main_menu
	if requested_index<0: requested_index=highscore_default_mission_index()
	highscore_mission_index=clampi(requested_index,0,MISSION_PATHS.size()-1)
	var mission_db:=Catalog.new(MISSION_PATHS[highscore_mission_index])
	var mission_id:=str(mission_db.mission.get("id",""))
	var all_data:=load_highscores()
	var entries: Array=[]
	var own_entries: Array=[]
	var seen_runs: Dictionary = {}
	for entry in all_data.entries:
		if str(entry.get("mission",""))!=mission_id: continue
		entries.append(entry)
		seen_runs[str(entry.get("run_id", ""))] = true
		if str(entry.get("profile_id",""))==str(commander_profile.data.profile_id): own_entries.append(entry)
	for entry in online_highscore_cache.get(mission_id, []):
		if not entry is Dictionary or seen_runs.has(str(entry.get("run_id", ""))): continue
		entries.append(entry)
		seen_runs[str(entry.get("run_id", ""))] = true
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)): return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
		return int(a.get("score", 0)) > int(b.get("score", 0)))
	clear(overlay); suppress_world_hover()
	var p:=panel(overlay,Rect2(400,86,1120,900),Color("202a29"))
	p.name = "OnlineHighscoresPanel"
	label(p,"PILOTENARCHIV / PERSÖNLICHE BESTENLISTE",Vector2(38,26),17,MINT)
	label(p,"Einsatzrekorde",Vector2(38,57),42,GOLD)
	var completed_missions: Array=campaign_progress.get("completed",[])
	for i in range(MISSION_PATHS.size()):
		var preview:=Catalog.new(MISSION_PATHS[i])
		var unlocked:=i<=int(campaign_progress.get("unlocked_mission",0))
		var done:=completed_missions.has(str(preview.mission.get("id","")))
		var caption:="%02d  %s%s" % [i+1,str(preview.mission.get("short_name",preview.mission.get("display_name","Einsatz"))),"  ✓" if done else ""]
		var mission_tab_index:=i
		var tab:=button(p,caption,Rect2(38+i*347,122,330,48),func():show_highscores(return_action,mission_tab_index))
		tab.disabled=not unlocked
		var st:=StyleBoxFlat.new(); st.bg_color=Color("173732") if i==highscore_mission_index else Color("263331"); st.border_color=MINT if i==highscore_mission_index else Color("485b55"); st.set_border_width_all(1); st.set_corner_radius_all(3)
		tab.add_theme_stylebox_override("normal",st)
		tab.add_theme_color_override("font_color",MINT if i==highscore_mission_index else (Color("d5ded5") if unlocked else MUTED))
	label(p,"MISSION %02d / %s" % [highscore_mission_index+1,str(mission_db.mission.get("display_name",mission_db.mission.get("name","Einsatz")))],Vector2(40,187),15,MUTED,680)
	var stats: Dictionary=commander_profile.data.statistics
	label(p,"DEINE LÄUFE",Vector2(770,187),12,MUTED)
	label(p,str(own_entries.size()),Vector2(770,207),25,GOLD)
	var personal_best:=0
	for entry in own_entries: personal_best=maxi(personal_best,int(entry.get("score",0)))
	label(p,"BESTWERT",Vector2(900,187),12,MUTED)
	label(p,format_score(personal_best) if personal_best>0 else "—",Vector2(900,207),25,GOLD)
	if entries.is_empty():
		label(p,"Für diesen Einsatz gibt es noch keinen abgeschlossenen Lauf.",Vector2(42,286),23,Color("c8d8ce"),850)
		if not completed_missions.has(mission_id): label(p,"Schließe den Einsatz erfolgreich ab, um den ersten Rekord freizuschalten.",Vector2(42,326),16,MUTED,850)
	else:
		label(p,"RANG   KOMMANDANT       PUNKTE       ZEIT       WIDERSTAND       FRAKTION       DATUM",Vector2(42,265),15,MUTED)
		var y:=302
		for i in mini(entries.size(),10):
			var entry: Dictionary=entries[i]
			var style:=Color("e7bd78") if i==0 else Color("c8d8ce")
			var raw_name:=str(entry.get("nickname","UNBEKANNT")).to_upper()
			var commander_name:="LEGACY" if raw_name=="UNBEKANNT" else raw_name
			var own_entry:=str(entry.get("profile_id",""))==str(commander_profile.data.profile_id) and not str(commander_profile.data.profile_id).is_empty()
			label(p,"%02d   %s%s   %s   %02d:%02d   %s   %s   %s" % [i+1,"> " if own_entry else "",commander_name,format_score(int(entry.score)),int(float(entry.time))/60,int(float(entry.time))%60,difficulty_label(str(entry.difficulty)),str(entry.faction),str(entry.date)],Vector2(42,y),16,MINT if own_entry else style,1030)
			y+=48
	var formula:=button(p,"PUNKTEBERECHNUNG  ?",Rect2(42,804,250,40),func():show_score_formula(return_action,highscore_mission_index))
	ghost_button_style(formula)
	var online_button := button(p, "ONLINE TOP 10 LADEN" if not online_highscore_cache.has(mission_id) else "ONLINE TOP 10 AKTUALISIEREN", Rect2(310,804,230,40), func():
		if is_instance_valid(online_stats): online_stats.request_highscores(mission_id))
	online_button.disabled = not online_stats_enabled or not is_instance_valid(online_stats)
	ghost_button_style(online_button)
	label(p,"Gesamt: %d Einsätze · %d Siege · %d Niederlagen" % [int(stats.singleplayer.missions),int(stats.singleplayer.wins),int(stats.singleplayer.losses)],Vector2(550,817),14,MUTED,260)
	button(p,"ZURÜCK",Rect2(830,800,250,46),return_action)

func show_score_formula(return_action: Callable, mission_tab: int) -> void:
	clear(overlay); suppress_world_hover()
	var screen:=get_viewport_rect().size
	var shade:=ColorRect.new(); shade.color=Color(0.01,0.016,0.018,0.70); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter=Control.MOUSE_FILTER_STOP; overlay.add_child(shade)
	var p:=panel(overlay,Rect2((screen-Vector2(760,430))*0.5,Vector2(760,430)),Color("211b17"))
	label(p,"PILOTENARCHIV / WERTUNG",Vector2(34,26),15,MINT)
	label(p,"Punkteberechnung",Vector2(34,56),34,GOLD)
	label(p,"Basiswert                         1.000\nAbschuss                           +250\nGeliefertes Solarit                 ×0,5\nProduziertes Fahrzeug               +120\nErrichtetes Gebäude                 +100\nZeitbonus                 (1.800 s − Zeit) ×2\nEigenes Fahrzeug verloren           −200\nEigenes Gebäude verloren            −500",Vector2(40,124),18,Color("d5ded5"),670)
	button(p,"ZUR BESTENLISTE",Rect2(40,360,300,44),func():show_highscores(return_action,mission_tab))

func save_game(path: String = SAVE_PATH, feedback: bool = true) -> void:
	if online.active or (playing and sim!=null and sim.online_mode=="versus"):
		if feedback: notify("Online-Partien verwenden die Wiederverbindung statt lokaler Spielstände.")
		return
	if sim==null: return
	var data := sim.snapshot()
	data["run_id"]=run_id
	data["commander_profile_id"]=str(commander_profile.data.profile_id)
	data["commander_nickname"]=str(commander_profile.data.nickname)
	data["camera"]=[renderer.camera.x,renderer.camera.y]
	data["zoom"]=renderer.zoom
	data["groups"]=groups
	data["selected"]=selected
	data["placement"]=placement
	data["placement_rotation"]=placement_rotation
	data["visual_state"]=renderer.combat_fx.persistence_snapshot()
	data["saved_at"]=Time.get_datetime_string_from_system(false,true)
	data["game_version"]=str(update_history.get("current_version","unbekannt"))
	data["mission_name"]=str(db.mission.get("display_name",db.mission.get("name",db.mission.get("id","Einsatz"))))
	data["save_kind"]="AUTOSAVE" if path.ends_with("autosave.json") else "SCHNELLSPEICHERSTAND"
	data["category"]=category
	data["inspected"]=inspected
	data["production_target_factory_id"]=production_target_factory_id
	var bookmark_save: Dictionary={}
	for key in bookmarks:
		var point: Vector2=bookmarks[key]
		bookmark_save[str(key)]=[point.x,point.y]
	data["bookmarks"]=bookmark_save
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: notify("Speichern fehlgeschlagen: "+error_string(FileAccess.get_open_error())); return
	file.store_string(JSON.stringify(data,"",true,true)); file.close()
	var err := DirAccess.rename_absolute(temporary,path)
	if err!=OK: notify("Speichern fehlgeschlagen: "+error_string(err)); return
	if feedback: music.cue("save"); notify("Spielstand gespeichert.")

func save_slot_info(path: String) -> Dictionary:
	var info := {"path":path,"exists":false,"valid":false,"slot":"AUTOSAVE" if path.ends_with("autosave.json") else "SCHNELLSPEICHERSTAND","mission":"Unbekannter Einsatz","mission_id":"","time":0.0,"saved_at":"","commander":"","difficulty":"","faction":"","version":""}
	if not FileAccess.file_exists(path): return info
	info.exists=true
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary: return info
	var data: Dictionary=parser.data
	var saved_index:=mission_index_for_id(str(data.get("mission","")))
	if saved_index<0: return info
	var preview:=Catalog.new(MISSION_PATHS[saved_index])
	if not preview.errors.is_empty(): return info
	info.valid=true
	info.mission_id=str(data.get("mission",""))
	info.mission=str(data.get("mission_name",preview.mission.get("display_name",preview.mission.get("name",info.mission_id))))
	info.time=float(data.get("time",0.0)) if data.get("time",0.0) is int or data.get("time",0.0) is float else 0.0
	info.saved_at=str(data.get("saved_at",""))
	info.commander=str(data.get("commander_nickname",""))
	info.difficulty=difficulty_label(str(data.get("difficulty","normal")))
	var saved_factions: Variant=data.get("factions",[])
	if saved_factions is Array and not saved_factions.is_empty() and preview.factions.has(str(saved_factions[0])):
		info.faction=str(preview.factions[str(saved_factions[0])].name)
	info.version=str(data.get("game_version",""))
	return info

func format_save_clock(seconds: float) -> String:
	var total:=maxi(0,int(seconds))
	return "%02d:%02d" % [total/60,total%60]

func show_load_dialog(return_action: Callable = Callable()) -> void:
	if not return_action.is_valid(): return_action=show_main_menu if not playing else show_pause
	clear(overlay); suppress_world_hover()
	var screen:=get_viewport_rect().size
	var size:=Vector2(minf(900.0,screen.x-64.0),minf(640.0,screen.y-64.0))
	var shade:=ColorRect.new(); shade.color=Color(0.01,0.016,0.018,0.68); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter=Control.MOUSE_FILTER_STOP; overlay.add_child(shade)
	var p:=panel(overlay,Rect2((screen-size)*0.5,size),Color("202a29"))
	p.name="LoadGamePanel"
	label(p,"SYSTEM / SPIELSTAND",Vector2(34,25),15,MINT)
	label(p,"Spielstand laden",Vector2(34,52),36,GOLD)
	label(p,"Wähle bewusst zwischen deinem letzten Schnellspeicherstand und dem automatischen Sicherungspunkt.",Vector2(36,103),16,Color("d5ded5"),size.x-72)
	var slots: Array=[save_slot_info(SAVE_PATH),save_slot_info("user://autosave.json")]
	for i in range(slots.size()):
		var info: Dictionary=slots[i]
		var y:=158.0+i*174.0
		var card:=panel(p,Rect2(34,y,size.x-68,150),Color("182220") if bool(info.valid) else Color("1e1a17"))
		label(card,str(info.slot),Vector2(20,16),14,MINT if bool(info.valid) else MUTED)
		if bool(info.valid):
			label(card,str(info.mission),Vector2(20,42),24,GOLD,430)
			var facts: Array[String]=["ZEIT "+format_save_clock(float(info.time)),str(info.difficulty)]
			if not str(info.faction).is_empty(): facts.append(str(info.faction))
			label(card,"  ·  ".join(facts),Vector2(20,78),14,Color("c8d8ce"),520)
			var metadata: Array[String]=[]
			if not str(info.commander).is_empty(): metadata.append("Kommandant "+str(info.commander).to_upper())
			if not str(info.saved_at).is_empty(): metadata.append(str(info.saved_at).replace("T"," "))
			if not str(info.version).is_empty(): metadata.append("v"+str(info.version))
			label(card,"  ·  ".join(metadata),Vector2(20,106),12,MUTED,560)
			var slot_path:=str(info.path)
			var load_button:=button(card,"DIESEN STAND LADEN  →",Rect2(size.x-350,45,300,54),func():load_game(slot_path))
			load_button.add_theme_color_override("font_color",GOLD)
		else:
			label(card,"Kein gültiger Spielstand vorhanden.",Vector2(20,54),19,MUTED,520)
			if bool(info.exists): label(card,"Die Datei ist vorhanden, kann aber nicht als kompatibler SOLARIT-Spielstand gelesen werden.",Vector2(20,86),13,Color("c07d70"),560)
	label(p,"Hinweis: F9 lädt weiterhin direkt den Schnellspeicherstand; falls keiner existiert, wird der Autosave verwendet.",Vector2(36,size.y-84),13,MUTED,size.x-72)
	button(p,"ZURÜCK",Rect2(34,size.y-54,250,38),return_action)

func load_game(path: String = "") -> void:
	if online.active or (playing and sim!=null and sim.online_mode=="versus"): notify("Für lokale Spielstände zuerst die Online-Verbindung trennen."); return
	if path.is_empty(): path=SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else "user://autosave.json"
	if not FileAccess.file_exists(path): show_error("Noch kein Spielstand vorhanden."); return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: show_error("Spielstand enthält ungültiges JSON."); return
	var data = parser.data
	if not data is Dictionary: show_error("Ungültiger Spielstand."); return
	var saved_mission_index:=mission_index_for_id(str(data.get("mission","")))
	if saved_mission_index<0: show_error("Mission des Spielstands ist nicht verfügbar."); return
	mission_index=saved_mission_index
	db=Catalog.new(MISSION_PATHS[mission_index])
	if not db.errors.is_empty(): show_error("Spieldaten der gespeicherten Mission sind ungültig."); return
	var model := Simulation.new(db,"forge","normal",int(campaign_progress.tech_level))
	if model.restore(data)!=OK: show_error("Spielstandversion oder Spieldaten passen nicht."); return
	var local_visuals := CombatEffects.new()
	if data.has("visual_state") and local_visuals.restore_persistence(data.visual_state,Vector2(model.grid.width,model.grid.height)*model.grid.tile)!=OK:
		show_error("Ungültige visuelle Zerstörungsspuren im Spielstand."); return
	sim=model; run_id=str(data.get("run_id","")); if run_id.is_empty(): run_id=create_run_id()
	last_load_path=path
	match_report_saved=false
	connect_sim(); playing=true; paused=false; ended=false
	render_previous=capture_render_state(); render_current=render_previous.duplicate(true)
	renderer.set_interpolation(render_previous,render_current,1.0)
	renderer.combat_fx.ruins=local_visuals.ruins
	renderer.combat_fx.craters=local_visuals.craters
	renderer.preserve_loaded_visuals=true
	faction=sim.factions[0]; difficulty=sim.difficulty
	selected=[]
	if data.get("selected",[]) is Array:
		for id in data.get("selected",[]):
			if sim.number(id) and sim.entities.has(int(id)): selected.append(int(id))
	groups={}
	if data.get("groups",{}) is Dictionary:
		for k in data.get("groups",{}):
			if not data.groups[k] is Array: continue
			groups[int(k)]=[]
			for id in data.groups[k]:
				if sim.number(id) and sim.entities.has(int(id)): groups[int(k)].append(int(id))
	bookmarks={}
	var saved_bookmarks: Dictionary=data.get("bookmarks",{}) if data.get("bookmarks",{}) is Dictionary else {}
	for k in saved_bookmarks:
		var raw_point: Variant=saved_bookmarks[k]
		if sim.vector_valid(raw_point): bookmarks[int(k)]=Vector2(float(raw_point[0]),float(raw_point[1]))
	var camera_value = data.get("camera",[400,1450])
	if not sim.vector_valid(camera_value): camera_value=[400,1450]
	renderer.camera=Vector2(camera_value[0],camera_value[1])
	var zoom_value = data.get("zoom",1)
	renderer.zoom=clampf(float(zoom_value),0.75,2.5) if sim.number(zoom_value) else 1.25
	placement=data.get("placement","") if data.get("placement","") is String and db.buildings.has(data.get("placement","")) else ""
	placement_rotation=int(data.get("placement_rotation",0))%4
	renderer.placement_rotation=placement_rotation
	renderer.placement=placement
	category=str(data.get("category","buildings"))
	if category not in ["buildings","units","production"]: category="buildings"
	inspected=int(data.get("inspected",0)) if sim.number(data.get("inspected",0)) and sim.entities.has(int(data.get("inspected",0))) else 0
	production_target_factory_id=int(data.get("production_target_factory_id",0)) if sim.number(data.get("production_target_factory_id",0)) else 0
	if production_target_factory_id>0 and (not sim.entities.has(production_target_factory_id) or str(sim.entities[production_target_factory_id].kind)!="factory" or int(sim.entities[production_target_factory_id].owner)!=local_owner()): production_target_factory_id=0
	accumulator=0; autosave_timer=120.0; clear(overlay); view_container.visible=true
	build_hud()
	# A loaded run needs a fresh recorder context; otherwise the eventual debrief can
	# accidentally finish a recorder from a previous run or no recorder at all.
	var opponent_name:="Gegner-KI"
	match_recorder.begin(sim,{"match_id":run_id,"game_version":str(update_history.get("current_version","unbekannt")),"mode":"singleplayer","side_0_nickname":str(commander_profile.data.nickname),"side_1_nickname":opponent_name})
	music.start(sim); music.set_paused(false)
	var slot_name:="Autosave" if path.ends_with("autosave.json") else "Schnellspeicherstand"
	notify(slot_name+" geladen · "+str(db.mission.get("display_name",db.mission.get("name","Einsatz")))+" · "+format_save_clock(sim.time))
	if sim.result!="": ended=true; show_end()

func show_error(message: String) -> void:
	clear(overlay)
	var p := panel(overlay,Rect2(610,390,700,280))
	label(p,message,Vector2(30,30),22,GOLD,640)
	button(p,"SCHLIESSEN",Rect2(30,193,640,50),func():clear(overlay))

func show_options(back: Callable, requested_tab: String = "") -> void:
	clear(overlay)
	if requested_tab in ["BILD","AUDIO","STEUERUNG","GAMEPLAY","PROFIL"]: options_tab=requested_tab
	var screen := get_viewport_rect().size
	var panel_size := Vector2(minf(1120.0,screen.x-48.0),minf(770.0,screen.y-48.0))
	var panel_pos := (screen-panel_size)*0.5
	var shade := ColorRect.new()
	shade.color=Color(0.015,0.02,0.022,0.54)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var p := panel(overlay,Rect2(panel_pos,panel_size),Color("171714"))
	p.name="OptionsPanel"
	var shell := StyleBoxFlat.new()
	shell.bg_color=Color(0.075,0.067,0.056,0.94)
	shell.border_color=Color(0.48,0.39,0.28,0.78)
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(3)
	shell.shadow_color=Color(0,0,0,0.48); shell.shadow_size=24; shell.shadow_offset=Vector2(0,8)
	p.add_theme_stylebox_override("panel",shell)
	var w := panel_size.x
	var h := panel_size.y
	label(p,"SYSTEM  /  OPTIONEN",Vector2(36,24),15,MINT)
	label(p,"Bild, Klang & Kontrolle",Vector2(36,47),32,GOLD)
	label(p,"PERSÖNLICHE EINSATZKONFIGURATION",Vector2(w-360,58),13,MUTED,324)
	var tab_names := ["BILD","AUDIO","STEUERUNG","GAMEPLAY","PROFIL"]
	var tab_width := (w-72.0)/float(tab_names.size())
	var focus_tab: Button
	for i in tab_names.size():
		var tab_name: String = tab_names[i]
		var tab_button := button(p,tab_name,Rect2(36+i*tab_width,103,tab_width-8,42),func():show_options(back,tab_name))
		tab_button.add_theme_font_size_override("font_size",15)
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color=Color(0.13,0.17,0.15,0.70) if options_tab==tab_name else Color(0.025,0.032,0.032,0.30)
		tab_style.border_color=MINT if options_tab==tab_name else Color(0.35,0.31,0.26,0.42)
		tab_style.border_width_bottom=2 if options_tab==tab_name else 1
		tab_style.content_margin_left=8; tab_style.content_margin_right=8
		var tab_hover: StyleBoxFlat=tab_style.duplicate()
		tab_hover.bg_color=Color(0.10,0.15,0.14,0.75); tab_hover.border_color=MINT
		tab_button.add_theme_stylebox_override("normal",tab_style)
		tab_button.add_theme_stylebox_override("hover",tab_hover)
		tab_button.add_theme_stylebox_override("focus",tab_hover)
		tab_button.add_theme_color_override("font_color",MINT if options_tab==tab_name else MUTED)
		if options_tab==tab_name: focus_tab=tab_button
	if focus_tab: focus_tab.grab_focus()
	var content_height := h-262.0
	var content := Panel.new()
	content.position=Vector2(36,163); content.size=Vector2(w-72,content_height)
	var content_style := StyleBoxFlat.new()
	content_style.bg_color=Color(0.025,0.032,0.031,0.43)
	content_style.border_color=Color(0.31,0.34,0.29,0.48)
	content_style.border_width_bottom=1
	content.add_theme_stylebox_override("panel",content_style)
	p.add_child(content)
	var cw := content.size.x
	var compact_options := content_height<470.0
	var heading := func(text_value: String, y: float):
		label(content,text_value,Vector2(26,y),14,MINT)
	var row := func(y: float, title: String, hint: String, control: Control):
		var divider := ColorRect.new()
		divider.color=Color(0.70,0.61,0.45,0.12)
		divider.position=Vector2(24,y+(43 if compact_options else 52)); divider.size=Vector2(cw-48,1)
		divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(divider)
		label(content,title,Vector2(28,y+4),16,Color("d6dfd5"))
		if hint!="": label(content,hint,Vector2(28,y+26),12,MUTED)
		control.position=Vector2(cw-350,y+(3 if compact_options else 6)); control.size=Vector2(318,34 if compact_options else 38)
		control.add_theme_font_size_override("font_size",15)
		if control.get_parent()==null: content.add_child(control)
	if options_tab=="BILD":
		heading.call("ANZEIGE",18)
		var classic_button := button(content,"CLASSIC RETRO · 640×360" if classic else "MODERN RETRO · FULL HD",Rect2(),func():set_classic(not classic); show_options(back,"BILD"))
		row.call(30 if compact_options else 45,"Darstellungsstil","Pixelgenaue Retro-Skalierung oder modernes Full HD.",classic_button)
		var resolutions: Array = WINDOW_RESOLUTIONS
		var resolution := OptionButton.new()
		resolution.name="ResolutionSelect"
		var matched := false
		for i in resolutions.size():
			resolution.add_item("%d × %d" % [resolutions[i].x,resolutions[i].y])
			if get_window().size==resolutions[i]: resolution.select(i); matched=true
		if not matched:
			var active_size: Vector2i = get_window().size
			if active_size.x < MINIMUM_WINDOW_RESOLUTION.x or active_size.y < MINIMUM_WINDOW_RESOLUTION.y:
				active_size = MINIMUM_WINDOW_RESOLUTION
				get_window().size = active_size
				persist_settings()
			resolution.add_item("Aktuell: %d × %d" % [active_size.x,active_size.y]); resolution.select(resolutions.size())
		resolution.item_selected.connect(func(i):
			if i<resolutions.size(): get_window().size=resolutions[i]; persist_settings())
		row.call(77 if compact_options else 103,"Auflösung","Fenstergröße für die aktuelle Anzeige.",resolution)
		var mode := OptionButton.new()
		mode.name="WindowModeSelect"
		for mode_name in ["Fenster","Randlos","Vollbild"]: mode.add_item(mode_name)
		mode.select(2 if get_window().mode==Window.MODE_FULLSCREEN else (1 if get_window().borderless else 0))
		mode.item_selected.connect(func(i):
			get_window().mode=Window.MODE_FULLSCREEN if i==2 else Window.MODE_WINDOWED
			get_window().borderless=i==1
			if i==1: get_window().size=DisplayServer.screen_get_size(); get_window().position=Vector2i.ZERO
			persist_settings())
		row.call(124 if compact_options else 161,"Fenstermodus","Fenster, randloses Fenster oder exklusives Vollbild.",mode)
		var crt_button := button(content,["AUS","LEICHT","STARK"][crt],Rect2(),func():crt=(crt+1)%3; renderer.crt=crt; persist_settings(); show_options(back,"BILD"))
		crt_button.disabled=not classic
		row.call(171 if compact_options else 219,"CRT-Filter","Nur im Classic-Retro-Modus verfügbar.",crt_button)
		heading.call("GEFECHTSEFFEKTE",224 if compact_options else 286)
		var fx_button := button(content,["NIEDRIG","MITTEL","HOCH"][renderer.combat_fx.quality],Rect2(),func():renderer.combat_fx.quality=(renderer.combat_fx.quality+1)%3; persist_settings(); show_options(back,"BILD"))
		fx_button.name="EffectQuality"
		row.call(248 if compact_options else 313,"Effektqualität","Dichte von Funken, Rauch und Trefferpartikeln.",fx_button)
		var shake_button := button(content,["AUS","LEICHT","NORMAL"][renderer.combat_fx.shake_mode],Rect2(),func():renderer.combat_fx.shake_mode=(renderer.combat_fx.shake_mode+1)%3; persist_settings(); show_options(back,"BILD"))
		shake_button.name="CameraShake"
		row.call(295 if compact_options else 371,"Kamerastoß","Intensität der kurzen Treffer- und Explosionsreaktion.",shake_button)
		var health_button := button(content,["BEI SCHADEN","IMMER","AUSGEWÄHLT","AUS"][ ["damaged","always","selected","off"].find(health_mode) if health_mode in ["damaged","always","selected","off"] else 0 ],Rect2(),func():
			var modes := ["damaged","always","selected","off"]
			health_mode=modes[(modes.find(health_mode)+1)%4]; renderer.health_mode=health_mode; persist_settings(); show_options(back,"BILD"))
		row.call(342 if compact_options else 429,"Lebensbalken","Anzeige beschädigter oder ausgewählter Einheiten.",health_button)
	elif options_tab=="AUDIO":
		heading.call("AUDIO-MISCHPULT",22)
		label(content,"Die Mischpegel gelten sofort und werden lokal gespeichert.",Vector2(26,51),14,MUTED)
		for i in 2:
			var y := 116.0+i*122.0
			var title := "MUSIK" if i==0 else "SOUND-EFFEKTE"
			label(content,title,Vector2(28,y),16,Color("d6dfd5"))
			var slider := HSlider.new()
			slider.name="MusicVolumeSlider" if i==0 else "SfxVolumeSlider"
			slider.position=Vector2(28,y+37); slider.size=Vector2(cw-150,32)
			slider.min_value=0; slider.max_value=1; slider.step=0.01
			slider.value=music.music_volume if i==0 else music.sfx_volume
			var track := StyleBoxFlat.new()
			track.bg_color=Color("292b25"); track.set_corner_radius_all(3); track.content_margin_top=3; track.content_margin_bottom=3
			var active_track := StyleBoxFlat.new()
			active_track.bg_color=MINT; active_track.set_corner_radius_all(3); active_track.content_margin_top=3; active_track.content_margin_bottom=3
			slider.add_theme_stylebox_override("slider",track)
			slider.add_theme_stylebox_override("grabber_area",active_track)
			var active_hover: StyleBoxFlat=active_track.duplicate(); active_hover.bg_color=GOLD
			slider.add_theme_stylebox_override("grabber_area_highlight",active_hover)
			var percentage := Label.new()
			percentage.position=Vector2(cw-105,y+36); percentage.size=Vector2(76,30)
			percentage.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			percentage.add_theme_color_override("font_color",GOLD)
			percentage.add_theme_font_size_override("font_size",16)
			percentage.text="%d %%" % roundi(slider.value*100.0)
			slider.value_changed.connect(func(value: float):
				percentage.text="%d %%" % roundi(value*100.0)
				if i==0: music.music_volume=value
				else: music.sfx_volume=value; music.cue("select")
				persist_settings())
			content.add_child(slider); content.add_child(percentage)
			var line := ColorRect.new()
			line.position=Vector2(28,y+88); line.size=Vector2(cw-56,1); line.color=Color(0.70,0.61,0.45,0.14); line.mouse_filter=Control.MOUSE_FILTER_IGNORE
			content.add_child(line)
		label(content,"MUSIK UND EFFEKTE SIND GETRENNT GEREGELT",Vector2(28,381),13,MUTED)
		label(content,"Tipp: Effekte lassen sich unabhängig von der Musik leiser stellen.",Vector2(28,408),14,Color("c8d3cc"))
	elif options_tab=="STEUERUNG":
		heading.call("TASTENBELEGUNG",16)
		label(content,"BEFEHL",Vector2(28,43),12,MUTED)
		label(content,"TASTE  /  KLICK ZUM ÄNDERN",Vector2(cw-360,43),12,MUTED,330)
		var actions := [["attack","Angreifen"],["stop","Stoppen"],["hold","Position halten"],["guard","Bewachen"],["repair","Reparieren"],["home","Kamera zur Basis"],["event","Ereignis"],["save","Schnellspeichern"],["load","Schnellladen"]]
		var key_style := StyleBoxFlat.new()
		key_style.bg_color=Color(0.09,0.13,0.12,0.54); key_style.border_color=Color(0.42,0.70,0.61,0.55); key_style.set_border_width_all(1); key_style.set_corner_radius_all(2)
		var key_hover: StyleBoxFlat=key_style.duplicate(); key_hover.bg_color=Color(0.13,0.21,0.18,0.8); key_hover.border_color=MINT
		var key_row_height := 36.0 if compact_options else 41.0
		var key_start_y := 58.0 if compact_options else 65.0
		for i in actions.size():
			var action: String=actions[i][0]
			var y := key_start_y+i*key_row_height
			var separator := ColorRect.new()
			separator.position=Vector2(24,y+(33 if compact_options else 37)); separator.size=Vector2(cw-48,1); separator.color=Color(0.70,0.61,0.45,0.10); separator.mouse_filter=Control.MOUSE_FILTER_IGNORE
			content.add_child(separator)
			label(content,actions[i][1],Vector2(30,y+5),15,Color("d6dfd5"))
			var key_name := "WARTE AUF EINGABE …" if remap_action==action else OS.get_keycode_string(hotkeys[action])
			var key_button := button(content,key_name,Rect2(cw-280,y+1,244,30 if compact_options else 34),func():remap_action=action; notify("WARTE AUF EINGABE …  ·  ESC ABBRECHEN"); show_options(back,"STEUERUNG"))
			key_button.name=action
			key_button.add_theme_font_size_override("font_size",14)
			key_button.add_theme_stylebox_override("normal",key_style); key_button.add_theme_stylebox_override("hover",key_hover); key_button.add_theme_stylebox_override("focus",key_hover)
			key_button.add_theme_color_override("font_color",MINT if remap_action==action else Color("d6dfd5"))
		var reset := button(content,"STANDARD WIEDERHERSTELLEN",Rect2(24,content.size.y-42,270,32),func():
			hotkeys={"attack":KEY_A,"stop":KEY_S,"hold":KEY_H,"guard":KEY_G,"repair":KEY_R,"home":KEY_HOME,"event":KEY_SPACE,"save":KEY_F5,"load":KEY_F9}
			remap_action=""; persist_settings(); show_options(back,"STEUERUNG"))
		reset.add_theme_font_size_override("font_size",12)
	elif options_tab=="PROFIL":
		heading.call("KOMMANDANTENAKTE",22)
		label(content, str(commander_profile.data.nickname).to_upper(), Vector2(28, 56), 28, GOLD)
		label(content, "Profil-ID  " + str(commander_profile.data.profile_id), Vector2(30, 98), 13, MUTED, cw - 60)
		var profile_button := button(content, "SPIELERNAME ÄNDERN", Rect2(28, 142, 300, 42), func(): show_profile_dialog(false, func(): show_options(back, "PROFIL")))
		profile_button.add_theme_font_size_override("font_size", 14)
		label(content, "Neue Bestenlisteneinträge werden unter dem neuen Namen gespeichert.\nBestehende Einträge behalten den Namen, unter dem sie erreicht wurden.", Vector2(30, 198), 15, Color("c8d3cc"), cw - 60)
		label(content, "Online-Dienst: Nickname, aktive Spielsitzung und Siege werden an api.dl-home.de übertragen. Die Profil-ID ist zufällig.", Vector2(30, 242), 14, Color("c8d3cc"), cw - 60)
		var stats_button := button(content, "ONLINE-SPIELSTATISTIK  ·  " + ("AN" if online_stats_enabled else "AUS"), Rect2(28, 300, cw - 56, 44), func():
			online_stats_enabled = not online_stats_enabled
			save_config.set_value("online", "enabled", online_stats_enabled)
			persist_settings()
			if is_instance_valid(online_stats): online_stats.set_enabled(online_stats_enabled); _configure_online_stats()
			show_options(back, "PROFIL"))
		stats_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats_button.add_theme_font_size_override("font_size", 15)
		var record_button := button(content, "KOMMANDANTENAKTE ÖFFNEN  →", Rect2(28, 366, 360, 46), func(): show_commander_file(func(): show_options(back, "PROFIL")))
		record_button.add_theme_font_size_override("font_size", 15)
	elif options_tab=="GAMEPLAY":
		heading.call("SPIELVERHALTEN",22)
		label(content,"KAMERA",Vector2(28,72),12,MUTED)
		var scroll := button(content,"RANDSCROLLEN  ·  "+("AN" if edge_scroll else "AUS"),Rect2(28,104,cw-56,58),func():edge_scroll=not edge_scroll; persist_settings(); show_options(back,"GAMEPLAY"))
		scroll.alignment=HORIZONTAL_ALIGNMENT_LEFT
		scroll.add_theme_font_size_override("font_size",16)
		var scroll_style := StyleBoxFlat.new()
		scroll_style.bg_color=Color(0.08,0.10,0.09,0.48); scroll_style.border_color=Color(0.40,0.36,0.30,0.38); scroll_style.border_width_bottom=1; scroll_style.content_margin_left=16
		var scroll_hover: StyleBoxFlat=scroll_style.duplicate(); scroll_hover.bg_color=Color(0.10,0.16,0.14,0.72); scroll_hover.border_color=MINT
		scroll.add_theme_stylebox_override("normal",scroll_style); scroll.add_theme_stylebox_override("hover",scroll_hover); scroll.add_theme_stylebox_override("focus",scroll_hover)
		label(content,"Bewegt den Kameraausschnitt, wenn der Mauszeiger den Rand des Spielfelds erreicht.",Vector2(30,174),14,MUTED,cw-60)
		label(content,"Die Änderung wird sofort übernommen und für den nächsten Start gespeichert.",Vector2(30,207),14,Color("c8d3cc"),cw-60)
	label(p,"SOLARIT: RANDSEKTOR 07 SYSTEM  ·  ÄNDERUNGEN WERDEN SOFORT GESPEICHERT",Vector2(40,h-91),12,MUTED,w-80)
	var back_button := button(p,"ZURÜCK",Rect2(36,h-61,250,40),func():persist_settings(); back.call())
	back_button.add_theme_font_size_override("font_size",14)
	var done_button := button(p,"ÜBERNEHMEN  →",Rect2(w-286,h-61,250,40),func():persist_settings(); back.call())
	done_button.add_theme_font_size_override("font_size",14)
	p.modulate.a=0.0
	var open_tween := p.create_tween()
	open_tween.tween_property(p,"modulate:a",1.0,0.18)

func set_classic(value: bool) -> void:
	classic=value; renderer.classic=value; renderer.crt=crt
	var window := get_window()
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT if value else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size=Vector2i(640,360) if value else Vector2i(1920,1080)
	window.content_scale_stretch=Window.CONTENT_SCALE_STRETCH_INTEGER if value else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	scale=Vector2.ONE/3.0 if value else Vector2.ONE
	view_container.stretch_shrink=3 if value else 1
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if value else CanvasItem.TEXTURE_FILTER_LINEAR
	view_container.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if value else CanvasItem.TEXTURE_FILTER_LINEAR
	if playing: build_hud()
	persist_settings()

func load_settings() -> void:
	if save_config.load("user://settings.cfg")==OK:
		music.music_volume=save_config.get_value("audio","music",0.65)
		music.sfx_volume=save_config.get_value("audio","sfx",0.75)
		edge_scroll=save_config.get_value("gameplay","edge",true)
		health_mode=save_config.get_value("gameplay","health","damaged")
		online_stats_enabled=bool(save_config.get_value("online", "enabled", true))
		crt=save_config.get_value("video","crt",0)
		renderer.combat_fx.shake_mode=clampi(int(save_config.get_value("video","shake",1)),0,2)
		renderer.combat_fx.quality=clampi(int(save_config.get_value("video","effects",2)),0,2)
		for action in hotkeys: hotkeys[action]=int(save_config.get_value("keys",action,hotkeys[action]))
		var window := get_window()
		var saved_resolution: Vector2i = save_config.get_value("video","resolution",MINIMUM_WINDOW_RESOLUTION)
		window.size = _normalize_window_resolution(saved_resolution)
		if window.size != saved_resolution:
			save_config.set_value("video","resolution",window.size)
			save_config.save("user://settings.cfg")
		window.mode=save_config.get_value("video","mode",Window.MODE_WINDOWED)
		window.borderless=save_config.get_value("video","borderless",false)
		set_classic(save_config.get_value("video","classic",false))
	renderer.health_mode=health_mode

static func _normalize_window_resolution(size: Vector2i) -> Vector2i:
	if size.x < MINIMUM_WINDOW_RESOLUTION.x or size.y < MINIMUM_WINDOW_RESOLUTION.y:
		return MINIMUM_WINDOW_RESOLUTION
	return size

func persist_settings() -> void:
	save_config.set_value("audio","music",music.music_volume)
	save_config.set_value("audio","sfx",music.sfx_volume)
	save_config.set_value("gameplay","edge",edge_scroll)
	save_config.set_value("gameplay","health",health_mode)
	save_config.set_value("online", "enabled", online_stats_enabled)
	save_config.set_value("video","classic",classic)
	save_config.set_value("video","crt",crt)
	save_config.set_value("video","shake",renderer.combat_fx.shake_mode)
	save_config.set_value("video","effects",renderer.combat_fx.quality)
	save_config.set_value("video","resolution",get_window().size)
	save_config.set_value("video","mode",get_window().mode)
	save_config.set_value("video","borderless",get_window().borderless)
	for action in hotkeys: save_config.set_value("keys",action,hotkeys[action])
	save_config.save("user://settings.cfg")

func show_updates(back: Callable) -> void:
	clear(overlay)
	var p := panel(overlay,Rect2(390,120,1140,840),Color("2b221b"))
	label(p,"SOLARIT: RANDSEKTOR 07 / VERSION "+str(update_history.current_version),Vector2(32,26),18,MINT)
	label(p,"Updateinfo",Vector2(32,65),42,GOLD)
	label(p,"Was wann hinzugekommen ist und verändert wurde",Vector2(32,121),21,MUTED)
	var versions := ItemList.new()
	versions.name="Versions"
	versions.position=Vector2(32,174); versions.size=Vector2(275,566)
	versions.add_theme_font_size_override("font_size",22)
	versions.add_theme_constant_override("v_separation",14)
	p.add_child(versions)
	var details := RichTextLabel.new()
	details.name="UpdateDetails"
	details.position=Vector2(337,174); details.size=Vector2(771,566)
	details.bbcode_enabled=true; details.scroll_active=true
	details.add_theme_font_size_override("normal_font_size",23)
	details.add_theme_font_size_override("bold_font_size",25)
	details.add_theme_constant_override("line_separation",8)
	p.add_child(details)
	var entries: Array = update_history.entries
	for entry in entries:
		versions.add_item(str(entry.version)+"  ·  "+str(entry.date))
		versions.set_item_tooltip(versions.item_count-1,str(entry.title))
	var display_entry := func(index: int):
		var entry: Dictionary = entries[index]
		var text := "[color=#ebbe72][b]"+str(entry.version)+" · "+str(entry.title)+"[/b][/color]\n[color=#bda98b]"+str(entry.date)+"[/color]\n\n"
		for change in entry.changes: text+="• "+str(change)+"\n\n"
		details.text=text
		details.scroll_to_line(0)
	versions.item_selected.connect(display_entry)
	versions.select(0); display_entry.call(0); versions.grab_focus()
	button(p,"ZURÜCK",Rect2(32,772,1076,48),back)

func show_credits() -> void:
	clear(overlay)
	var p := panel(overlay,Rect2(580,170,980,740),Color("2b221b"))
	label(p,"SOLARIT: RANDSEKTOR 07 / ORIGINALAUDIO",Vector2(40,34),18,MINT)
	label(p,"Frequenzen von Veyra",Vector2(40,80),42,GOLD)
	label(p,"Komposition, Synthese und Grafik wurden für dieses Projekt erstellt.\nAlle Musikspuren laufen bei 120 BPM auf derselben Taktachse.\nAus dem ruhigen Bassmotiv wächst das Gefechtsarrangement.\n\nEngine: Godot, MIT-Lizenz. Keine externen Plugins oder Spielassets.\nProgrammierung, Gestaltung & Komposition: Codex für Dirk.",Vector2(40,168),22,Color("c8d8ce"),900)
	music.start(Simulation.new(db,faction))
	music.set_paused(false)
	for i in 4:
		button(p,["RUHE","KONTAKT","GEFECHT","BASISALARM"][i],Rect2(40+i*225,467,210,54),func():
			for j in music.layers.size(): music.layers[j].volume_db=-6 if j<=i else -55
			music.state=["BASE_CALM","ENEMY_CONTACT","BATTLE","BASE_UNDER_ATTACK"][i]
			music.age=-100)
	button(p,"SIEG-JINGLE",Rect2(40,548,430,50),func():music.cue("victory"))
	button(p,"NIEDERLAGE-JINGLE",Rect2(490,548,430,50),func():music.cue("defeat"))
	button(p,"ZURÜCK",Rect2(40,648,880,50),show_main_menu)

func capture_smoke() -> void:
	var directory := "res://test-output" if OS.has_feature("editor") else "user://test-output"
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory+"/modern.png")
	set_classic(true)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(directory+"/classic.png")
	set_classic(false)
	music.shutdown()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func capture_frontend_smoke() -> void:
	var directory := "res://test-output" if OS.has_feature("editor") else "user://test-output"
	DirAccess.make_dir_recursive_absolute(directory)
	intro_art.elapsed=13.0
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(directory+"/release_intro.png")
	skip_intro()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(directory+"/release_menu.png")
	set_classic(true)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(directory+"/release_menu_classic.png")
	set_classic(false)
	music.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()



func show_online_end() -> void:
	if is_instance_valid(online_stats): online_stats.stop_playing()
	paused=true
	clear(overlay)
	var p:=panel(overlay,Rect2(585,230,750,620),Color("2b221b"))
	label(p,"EINSATZ ABGESCHLOSSEN  /  "+("1:1-DUELL" if sim.online_mode=="versus" else "KOOPERATION"),Vector2(42,28),18,MINT)
	label(p,"Sieg!" if sim.result=="victory" else "Niederlage",Vector2(42,76),48,GOLD)
	if sim.online_mode == "versus": label(p,"Gegner: "+str(online.mission_config.get("client_nickname" if online.is_host() else "host_nickname", "Kommandant")),Vector2(44,130),15,MUTED)
	var s: Dictionary=sim.stats
	var result_mode:="duel" if sim.online_mode=="versus" else "coop"
	var result_record:=record_commander_result(result_mode,0)
	label(p,"KOMMANDANT / "+str(commander_profile.data.nickname).to_upper(),Vector2(44,137),15,MUTED)
	label(p,"Zeit %02d:%02d\nSolarit geliefert: %d\nFahrzeuge gebaut: %d\nEigene Verluste: %d\nGegner zerstört: %d\nGebäude errichtet: %d"%[int(sim.time)/60,int(sim.time)%60,int(s.gathered),int(s.produced),int(s.lost),int(s.kills),int(s.built)],Vector2(44,172),23,Color("c8d8ce"))
	button(p,"REVANCHE / ZUR LOBBY",Rect2(42,467,310,58),func():online.request_rematch())
	button(p,"HAUPTMENÜ / TRENNEN",Rect2(392,467,310,58),show_main_menu)
