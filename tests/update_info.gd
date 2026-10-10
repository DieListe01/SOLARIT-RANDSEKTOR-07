extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("UPDATE INFO: "+message)
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")
func index_for_version(versions: ItemList, version: String) -> int:
	for index in versions.item_count:
		if versions.get_item_text(index).begins_with(version+"  ·  "): return index
	return -1
func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false)
	check(game.menu_buttons.has("start") and game.update_button.disabled and game.update_button.text=="UPDATES AB RELEASE","unpublished local build explains that the release feed is not configured")
	check(game.update_history.current_version=="0.38.2","Central current version")
	check(game.update_history.entries.size()==74,"Every archived version plus new release")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("0.38.2.0"),"Export version matches displayed history")
	game.show_available_update({"version":"0.38.2","notes":"Test release notes."})
	await process_frame
	var offer_panel: Control = game.overlay.get_child(0)
	check(offer_panel.get_node("InstalledVersion").text=="v0.38.2","Update offer clearly shows installed version")
	check(offer_panel.get_node("NewVersion").text=="v0.38.2","Update offer clearly shows the new version")
	await capture("update_available_versions")
	for child in offer_panel.get_children():
		if child is Button and child.text=="SPÄTER": child.pressed.emit(); break
	game.update_check_manual = true
	game._on_update_check_finished({"ok":true,"available":false,"version":"0.38.2"})
	await process_frame
	var current_dialog: Control = game.overlay.get_node("UpdateCurrentDialog")
	check(current_dialog.get_node("CurrentVersion").text=="Installierte Version: v0.38.2" and current_dialog.find_children("*", "Button", true, false).size()==1,"Manual check opens a current-version popup with an OK button")
	for child in current_dialog.get_children():
		if child is Button: child.pressed.emit(); break
	var seen := {}
	for entry in game.update_history.entries:
		check(not seen.has(entry.version) and not entry.changes.is_empty() and entry.date.length()==10,"Dated, unique, nonempty entry "+entry.version)
		seen[entry.version]=true
	game.menu_buttons.updates.pressed.emit()
	await process_frame
	var panel: Control = game.overlay.get_child(0)
	var versions: ItemList = panel.get_node("Versions")
	var details: RichTextLabel = panel.get_node("UpdateDetails")
	var latest_details_lower := details.text.to_lower()
	check(versions.item_count==74 and details.text.contains("0.38.2") and details.text.contains("10.10.2026") and latest_details_lower.contains("subviewport") and latest_details_lower.contains("cache") and latest_details_lower.contains("fahrzeug"),"Latest release notes describe GPU-resident vehicle poses and deferred cache misses")
	check(details.scroll_active,"Latest release details open in the scrollable history")
	var private_lobby_index:=index_for_version(versions,"0.36.13")
	versions.select(private_lobby_index); versions.item_selected.emit(private_lobby_index)
	check(details.text.contains("Passwort"),"Previous private-lobby release remains in the history")
	var updater_index:=index_for_version(versions,"0.36.1")
	versions.select(updater_index); versions.item_selected.emit(updater_index)
	check(details.text.contains("Prüfsumme") and details.text.contains("GitHub"),"Previous release retains verified updater details")
	await capture("updateinfo_modern")
	versions.select(0); versions.item_selected.emit(0)
	versions.grab_focus()
	for i in 26:
		var event := InputEventKey.new()
		event.keycode=KEY_DOWN; event.pressed=true; Input.parse_input_event(event)
		await process_frame
		event=InputEventKey.new(); event.keycode=KEY_DOWN; event.pressed=false; Input.parse_input_event(event)
		await process_frame
	check(versions.get_selected_items().size()==1 and versions.get_selected_items()[0]>0 and details.text.to_lower()!=latest_details_lower,"Real keyboard navigation changes release details")
	versions.select(versions.item_count - 1); versions.item_selected.emit(versions.item_count - 1)
	check(details.text.contains("Erste eigenständige Version"),"Oldest release accessible")
	game.set_classic(true)
	await capture("updateinfo_classic")
	check(root.get_texture().get_image().get_width()==640,"History available in real Classic render")
	game.set_classic(false); game.show_main_menu(); game.start_game(); game.show_pause()
	var before := JSON.stringify(game.sim.snapshot())
	var pause_panel: Control = game.overlay.get_child(0)
	var found := false
	for child in pause_panel.get_children():
		if child is Button and child.text=="UPDATEINFO": child.pressed.emit(); found=true; break
	check(found and game.paused,"Update info reachable during paused mission")
	await process_frame
	var history_panel: Control = game.overlay.get_child(0)
	for child in history_panel.get_children():
		if child is Button and child.text=="ZURÜCK": child.pressed.emit(); break
	check(game.paused and JSON.stringify(game.sim.snapshot())==before,"Returning preserves pause and entire mission")
	game.resume_game()
	check(not game.paused,"Mission resumes normally after browsing history")
	game.music.shutdown(); game.queue_free()
	await process_frame
	print("UPDATE INFO: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

