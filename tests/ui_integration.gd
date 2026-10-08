extends SceneTree

var errors: Array[String] = []
var checks := 0
var game: Control

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: errors.append(message); push_error("UI FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")

func mouse(local: Vector2, button_value: int = 1, pressed: bool = true) -> void:
	var raw: Vector2 = root.get_final_transform()*game.get_global_transform_with_canvas()*local
	var motion := InputEventMouseMotion.new()
	motion.position=raw; motion.global_position=raw
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position=raw; event.global_position=raw; event.button_index=button_value; event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame

func click_world(point: Vector2, button_value: int = 1) -> void:
	var local: Vector2 = game.WORLD_RECT.position+game.WORLD_RECT.size*0.5+(point-game.renderer.camera)*game.renderer.zoom
	await mouse(local,button_value,true)
	await mouse(local,button_value,false)

func drag_map() -> void:
	var start: Vector2 = game.WORLD_RECT.get_center()
	var camera_before: Vector2 = game.renderer.camera
	var orders: Dictionary = {}
	for e in game.sim.entities.values(): orders[e.id]=[e.order,e.destination]
	await mouse(start,2,true)
	var delta := Vector2(-80,70)
	var transform: Transform2D = root.get_final_transform()*game.get_global_transform_with_canvas()
	var motion := InputEventMouseMotion.new()
	motion.position=transform*(start+delta); motion.global_position=motion.position
	motion.relative=transform.basis_xform(delta)
	Input.parse_input_event(motion)
	await process_frame
	await mouse(start+delta,2,false)
	check(game.renderer.camera.distance_to(camera_before)>40,"Holding RMB and dragging pans the camera")
	var unchanged := true
	for e in game.sim.entities.values():
		if orders[e.id]!=[e.order,e.destination]: unchanged=false
	check(unchanged,"RMB drag does not issue movement or harvesting orders")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.commander_profile.path = "user://ui_commander_profile.json"
	game.commander_profile.load_profile()
	game.commander_profile.set_nickname("DIRK")
	game.skip_intro()
	await create_timer(0.8).timeout
	check(not game.playing,"Main menu opens")
	check(game.ui.get_children().filter(func(child):return child is TacticalMap).is_empty(),"Minimap is hidden outside an active mission")
	await capture("menu")
	game.show_briefing()
	await capture("briefing")
	game.start_game()
	game.sim.ai_timer=99999
	check(game.playing and not game.paused,"Start mission")
	check(game.minimap.get_parent()==game.ui and game.minimap.position.x>=1400 and game.minimap.position.y>=800 and game.minimap.size.x<=180,"Small minimap sits at the lower-right of the battlefield")
	await process_frame
	check(game.minimap.terrain_texture!=null and game.minimap.terrain_texture.get_width()==game.sim.grid.width and game.minimap.terrain_texture.get_height()==game.sim.grid.height,"Minimap terrain is rasterized to one map-sized texture")
	var starting_solarit: float=game.sim.credits[0]
	game.sim.credits[0]=50000
	game.update_hud()
	check(game.buttons.refinery.text.contains("BENÖTIGT: Impulswerk"),"Catalog clearly distinguishes missing prerequisites")
	check(game.buttons.refinery.modulate==Color.WHITE and game.requirement_marks.refinery.color==Color("9e524c"),"Blocked catalog row keeps its original artwork and uses a restrained red marker")
	game.sim.credits[0]=0
	game.update_hud()
	check(game.buttons.power.text.contains("FEHLEN"),"Catalog clearly marks insufficient Solarit")
	check(game.buttons.power.modulate==Color.WHITE and game.requirement_marks.power.color==Color("d6b56f"),"Solarit warning stays amber without tinting the row")
	check(game.buttons.refinery.text.contains("BENÖTIGT:") and game.buttons.refinery.tooltip_text.contains("SOLARIT REICHT NICHT"),"Catalog displays both blockers when both apply")
	game.sim.credits[0]=starting_solarit
	game.update_hud()
	await click_world(game.sim.buildings(0,"core")[0].pos)
	check(game.selected.size()==1 and game.selected[0]==game.sim.buildings(0,"core")[0].id,"Engine mouse events select core")
	var first_scout: Dictionary = game.sim.entities.values().filter(func(e):return e.owner==0 and e.kind=="scout")[0]
	await click_world(first_scout.pos)
	await process_frame
	check(game.selected.size()==1 and game.selected[0]==first_scout.id,"Engine mouse events select unit")
	check(game.hovered_entity_id==first_scout.id and game.hover_panel.visible and game.hover_label.text.contains("Späher"),"Unit hover reveals a selectable highlight and identity card")
	var move_point: Vector2 = first_scout.pos+Vector2(0,120)
	await click_world(move_point,2)
	check(first_scout.order=="move" and first_scout.destination.distance_to(move_point)<3,"Engine right-click issues move")
	await drag_map()
	await mouse(game.WORLD_RECT.get_center(),2,true)
	await mouse(Vector2(1630,520),2,false)
	check(not game.right_held,"RMB drag releases cleanly over the HUD")
	game.catalog_click("power",false)
	check(game.placement=="power","Build button enters placement")
	check(game.sim.build("power",0,Vector2i(14,43))>0,"Placement starts construction")
	game.placement=""; game.renderer.placement=""
	for i in 20*30: game.sim.tick(1.0/30)
	game.sim.build("refinery",0,Vector2i(14,47))
	for i in 14*30: game.sim.tick(1.0/30)
	var harvester: Dictionary = game.sim.entities.values().filter(func(e):return e.owner==0 and e.kind=="harvester")[0]
	game.sim.command([harvester.id],Vector2.ZERO,"stop")
	await click_world(harvester.pos)
	check(game.selected==[harvester.id],"A real mouse click selects the harvester")
	game.update_hud()
	check(not game.harvest_button.disabled and not game.unload_button.disabled,"Selected harvester exposes usable task buttons")
	var resource_point: Vector2 = game.sim.grid.center(Vector2i(19,43))
	await click_world(resource_point,2)
	check(harvester.harvest_state in ["MOVE_TO_RESOURCE","HARVEST"] and harvester.resource==game.sim.grid.key(Vector2i(19,43)),"RMB on Solarit assigns an explicit harvest field")
	for i in 20*30: game.sim.tick(1.0/30)
	check(harvester.cargo>0 or game.sim.stats.gathered>0,"Assigned harvester actually collects Solarit")
	game.sim.command([harvester.id],Vector2.ZERO,"stop")
	game.harvest_button.pressed.emit()
	await click_world(resource_point)
	check(not game.harvest_mode and harvester.harvest_state in ["MOVE_TO_RESOURCE","HARVEST"],"Collect button and LMB assign a harvesting task")
	harvester.cargo=100.0
	game.unload_button.pressed.emit()
	check(harvester.harvest_state=="RETURN_TO_BASE","Unload button assigns a refinery return")
	var gathered_before: float = game.sim.stats.gathered
	for i in 20*30: game.sim.tick(1.0/30)
	check(game.sim.stats.gathered>gathered_before,"Manual return unloads cargo into credits")
	game.sim.build("factory",0,Vector2i(9,49))
	for i in 16*30: game.sim.tick(1.0/30)
	game.category="units"; game.build_hud()
	var vehicle_card: Button=game.buttons.tank
	check(vehicle_card.size.x>=270 and vehicle_card.size.y>=80,"Vehicle cards give unit details and production controls separate space")
	check(vehicle_card.get_node("PriorityUp").tooltip_text.is_empty() and vehicle_card.get_node("PriorityDown").tooltip_text.is_empty(),"Queue arrow hover text does not cover adjacent vehicle cards")
	var button_point: Vector2 = game.get_global_transform_with_canvas().affine_inverse()*game.buttons.tank.get_global_rect().get_center()
	await mouse(button_point,1,true)
	await mouse(button_point,1,false)
	check(not game.sim.buildings(0,"factory")[0].queue.is_empty(),"Real production button queues vehicle")
	game.sim.credits[0]=5000
	game.sim.enqueue("scout",0)
	game.sim.enqueue("scout",0)
	game.sim.enqueue("tank",0)
	game.category="production"; game.build_hud()
	await process_frame
	check(game.production_rows.size()==1,"Production overview lists each owned vehicle yard")
	var production_text: String=game.production_rows.values()[0].text
	check(production_text.contains("JETZT:") and production_text.contains("NÄCHST:") and production_text.contains("Amboss"),"Production overview shows running unit and next queued vehicle")
	var first_job_progress: ProgressBar=game.production_content.find_child("JobProgress%d"%int(game.production_rows.keys()[0]),true,false) as ProgressBar
	check(first_job_progress!=null and first_job_progress.get_parent() is Panel and first_job_progress.position.y<first_job_progress.get_parent().size.y,"Production progress stays inside its own queue card")
	var priority_buttons: Array=game.production_content.find_children("*","Button",true,false).filter(func(item):return item.text=="↑")
	check(priority_buttons.size()==4 and not priority_buttons[3].disabled,"Each queued vehicle has an enabled promote-to-next action")
	priority_buttons[3].pressed.emit()
	await process_frame
	var factory_queue: Array=game.sim.buildings(0,"factory")[0].queue
	check(factory_queue[1].kind=="tank","Priority moves the chosen vehicle directly behind current production")
	var credits_before_cancel: float=game.sim.credits[0]
	var cancel_buttons: Array=game.production_content.find_children("*","Button",true,false).filter(func(item):return item.text=="×")
	cancel_buttons[2].pressed.emit()
	check(game.sim.buildings(0,"factory")[0].queue.size()==3 and game.sim.credits[0]>credits_before_cancel,"Cancel removes the individually chosen queue item and refunds Solarit")
	await capture("production_overview")
	var second_factory_id: int=game.sim.spawn("factory",0,Vector2(5900,5900),true,true)
	game.sim.credits[0]=5000
	game.category="production"; game.build_hud()
	await process_frame
	check(game.production_rows.size()==2,"Production overview supports selecting among multiple vehicle yards")
	game.production_rows[second_factory_id].pressed.emit()
	check(game.production_target_factory_id==second_factory_id,"A chosen yard becomes the target for new production orders")
	game.category="units"; game.build_hud()
	var target_labels: Array=game.ui.find_children("*","Label",true,false).filter(func(item):return item.text.contains("ZIELWERFT 02"))
	check(not target_labels.is_empty(),"Vehicle catalog identifies the selected target yard")
	var target_packet: Dictionary={"type":"produce","owner_id":0,"kind":"scout","producer_id":second_factory_id}
	check(game.sim.submit_command(target_packet,0) and game.sim.entities[second_factory_id].queue.size()==1,"New vehicle order enters only the selected yard")
	target_packet.producer_id=999999
	check(not game.sim.submit_command(target_packet,0),"Production command rejects a missing target yard")
	target_packet.producer_id=-1
	check(not game.sim.submit_command(target_packet,0),"Production command rejects a negative target yard ID")
	game.category="units"; game.build_hud()
	for i in 10*30: game.sim.tick(1.0/30)
	var units: Array = game.sim.entities.values().filter(func(e):return e.owner==0 and not e.building)
	game.selected=[]
	for e in units: game.selected.append(e.id)
	game.groups[1]=game.selected.duplicate()
	game.selected.append(game.sim.buildings(0,"factory")[0].id)
	game.sim.command(game.selected,Vector2(610,1370))
	game.renderer.camera=game.sim.buildings(0,"core")[0].pos; game.clamp_camera()
	game.update_hud()
	await capture("base")
	var before: Dictionary = game.sim.snapshot()
	game.set_classic(true)
	game.paused=true
	game.music.set_paused(true)
	await capture("classic_base")
	check(root.content_scale_size==Vector2i(640,360),"True 640x360 internal viewport")
	check(root.content_scale_stretch==Window.CONTENT_SCALE_STRETCH_INTEGER,"Integer scaling")
	check(game.sim.snapshot()==before,"Render switch leaves simulation unchanged")
	game.paused=false; game.music.set_paused(false)
	# Panning coordinates must remain correct at true 640×360 resolution.
	await drag_map()
	await click_world(game.sim.buildings(0,"core")[0].pos)
	check(game.selected.size()==1 and game.selected[0]==game.sim.buildings(0,"core")[0].id,"Classic input uses the same world coordinates")
	game.paused=true; game.music.set_paused(true)
	game.set_classic(false)
	game.save_game("user://ui_test_save.json",false)
	var save = JSON.parse_string(FileAccess.get_file_as_string("user://ui_test_save.json"))
	check(save.groups.has("1") and save.selected.size()==game.selected.size(),"Groups and selection saved")
	game.category="units"
	game.bookmarks[KEY_F1]=Vector2(512,768)
	game.save_game()
	var saved_json: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://quick_save.json"))
	check(saved_json.has("saved_at") and saved_json.has("mission_name") and str(saved_json.get("category",""))=="units","Save contains preview metadata and UI state")
	var saved_credits: float = game.sim.credits[0]
	var saved_selection: Array = game.selected.duplicate()
	game.sim.credits[0]+=12345
	game.category="buildings"
	game.bookmarks.clear()
	game.load_game()
	check(is_equal_approx(game.sim.credits[0],saved_credits),"Main-menu load restores saved credits")
	check(game.selected==saved_selection and game.groups.has(1),"Load restores usable integer selection and control groups")
	check(game.renderer.selected.has(game.selected[0]),"Loaded selection is highlighted")
	check(game.category=="units" and game.bookmarks.has(KEY_F1),"Load restores catalog tab and camera bookmarks")
	check(not game.match_recorder.report.is_empty() and str(game.match_recorder.report.get("match_id",""))==game.run_id,"Load starts a recorder context for the restored run")
	game.show_load_dialog(game.show_pause)
	check(game.overlay.get_node_or_null("LoadGamePanel")!=null,"Load command opens an explicit save-slot chooser")
	game.load_game()
	game.show_pause()
	var t: float = game.sim.time
	game._process(0.5)
	check(game.sim.time==t,"Pause freezes simulation")
	check(game.music.paused,"Pause freezes music transport")
	await capture("pause")
	game.show_options(game.show_pause)
	await capture("options")
	game.resume_game()
	check(not game.paused and not game.music.paused,"Resume")
	game.sim.destroy(game.sim.buildings(1,"core")[0].id)
	game.sim.check_objectives()
	game._process(0.05)
	await capture("victory")
	check(game.ended and game.paused,"Victory debrief freezes play")
	var debrief_labels: Array=game.overlay.find_children("*","Label",true,false)
	var lost_buildings_label: Label=debrief_labels.filter(func(item):return item.text=="GEBÄUDE VERLOREN")[0]
	var rating_label: Label=debrief_labels.filter(func(item):return item.text.begins_with("BEWERTUNG"))[0]
	check(not lost_buildings_label.get_global_rect().intersects(rating_label.get_global_rect()),"Debrief rating does not overlap the last match statistic")
	game.start_game()
	game.sim.destroy(game.sim.buildings(0,"core")[0].id)
	game.sim.check_objectives()
	game._process(0.05)
	check(game.ended and game.sim.result=="defeat","Defeat debrief")
	# Verify all declared display sizes through the actual renderer.
	game.show_main_menu()
	await create_timer(0.8).timeout
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]:
		root.size=resolution
		await process_frame
		await process_frame
		check(root.size==resolution,"Window resolution %s" % resolution)
		await capture("display_%d" % resolution.x)
	root.size=Vector2i(1920,1080)
	game.persist_settings()
	print("UI INTEGRATION: %d checks, %d failures" % [checks,errors.size()])
	game.music.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if errors.is_empty() else 1)
