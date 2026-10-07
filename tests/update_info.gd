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
func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false)
	check(game.menu_buttons.has("start") and game.update_button.disabled and game.update_button.text=="UPDATES AB RELEASE","unpublished local build explains that the release feed is not configured")
	check(game.update_history.current_version=="0.36.11","Central current version")
	check(game.update_history.entries.size()==47,"Every archived version plus new release")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("0.36.11.0"),"Export version matches displayed history")
	game.show_available_update({"version":"0.36.12","notes":"Test release notes."})
	await process_frame
	var offer_panel: Control = game.overlay.get_child(0)
	check(offer_panel.get_node("InstalledVersion").text=="v0.36.11","Update offer clearly shows installed version")
	check(offer_panel.get_node("NewVersion").text=="v0.36.12","Update offer clearly shows the new version")
	await capture("update_available_versions")
	for child in offer_panel.get_children():
		if child is Button and child.text=="SPÄTER": child.pressed.emit(); break
	var seen := {}
	for entry in game.update_history.entries:
		check(not seen.has(entry.version) and not entry.changes.is_empty() and entry.date.length()==10,"Dated, unique, nonempty entry "+entry.version)
		seen[entry.version]=true
	game.menu_buttons.updates.pressed.emit()
	await process_frame
	var panel: Control = game.overlay.get_child(0)
	var versions: ItemList = panel.get_node("Versions")
	var details: RichTextLabel = panel.get_node("UpdateDetails")
	check(versions.item_count==47 and details.text.contains("0.36.11") and details.text.contains("07.10.2026"),"Latest release opens from menu")
	check(details.text.contains("installierte Version") and details.scroll_active,"Latest release details open in the scrollable history")
	versions.select(3); versions.item_selected.emit(3)
	check(details.text.contains("Prüfsumme") and details.text.contains("GitHub"),"Previous release retains verified updater details")
	await capture("updateinfo_modern")
	versions.select(0); versions.item_selected.emit(0)
	versions.grab_focus()
	for i in 21:
		var event := InputEventKey.new()
		event.keycode=KEY_DOWN; event.pressed=true; Input.parse_input_event(event)
		await process_frame
		event=InputEventKey.new(); event.keycode=KEY_DOWN; event.pressed=false; Input.parse_input_event(event)
		await process_frame
	check(details.text.contains("0.26") and not details.text.contains("0.36.11"),"Real keyboard navigation changes release details")
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
