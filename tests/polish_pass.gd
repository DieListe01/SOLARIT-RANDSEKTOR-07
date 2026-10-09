extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures+=1; push_error("POLISH FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")

func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	game.renderer.combat_fx.quality=2; game.renderer.combat_fx.shake_mode=1
	await process_frame
	for e in game.sim.entities.values():
		if e.building: game.sim.grid.reserve(e.cell,game.sim.definition(e).footprint,0,false)
	game.sim.entities.clear(); game.sim.known=[{},{}]
	game.sim.spawn("core",0,Vector2(288,1248),true)
	game.sim.spawn("power",0,Vector2(416,1248),true)
	game.sim.spawn("radar",0,Vector2(288,1376),true)
	game.sim.spawn("refinery",0,Vector2(416,1312),true)
	var site: int = game.sim.spawn("factory",0,Vector2(448,1568),true,false)
	game.sim.entities[site].build_progress=8
	var enemy: int = game.sim.spawn("core",1,Vector2(832,1248),true)
	game.sim.spawn("power",1,Vector2(960,1248),true)
	var tank: int = game.sim.spawn("tank",0,Vector2(585,1495),false)
	var siege: int = game.sim.spawn("siege",0,Vector2(455,1460),false)
	game.sim.spawn("harvester",0,Vector2(470,1530),false)
	var opponent: int = game.sim.spawn("tank",1,Vector2(735,1495),false)
	game.sim.entities[tank].target=opponent
	game.sim.entities[siege].target=opponent
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=Vector2(650,1440); game.renderer.zoom=1.65; game.renderer.fog_timer=0
	game.selected=[tank]; game.build_hud(); game.update_hud()
	game.sim.combat(game.sim.entities[tank],1.0/30.0)
	game.sim.combat(game.sim.entities[siege],1.0/30.0)
	check(game.renderer.combat_fx.particles.size()==2,"Actual shots create local visual events")
	check(game.music.samples.has("siege_shot") and game.music.samples.has("impact"),"Differentiated original sound cues loaded")
	game.sim.process_projectiles(0.55)
	check(game.renderer.combat_fx.flashes.has(opponent),"Actual damage creates a target hit flash")
	game.sim.destroy(enemy)
	check(game.renderer.combat_fx.ruins.size()==1,"Destruction leaves local debris")
	game.renderer.combat_fx.update(0.22)
	game.renderer.combat_fx.emit_effect("shot",{"pos":game.sim.entities[tank].pos,"angle":0.0,"weapon":"cannon"})
	game.renderer.combat_fx.emit_effect("impact",{"pos":Vector2(735,1450),"weapon":"mortar"})
	game.minimap.ping(Vector2(850,1290),Color("f34c32"))
	var state := JSON.stringify(game.sim.snapshot())
	var camera: Vector2 = game.renderer.camera
	game.renderer.combat_fx.update(0.02)
	check(game.renderer.combat_fx.offset.length()>0,"Heavy visible events create a local camera impulse")
	check(game.renderer.camera==camera and JSON.stringify(game.sim.snapshot())==state,"Particles and camera impulse preserve simulation and authoritative camera")
	await capture("polish_battle_modern")
	game.set_classic(true)
	await capture("polish_battle_classic")
	check(JSON.stringify(game.sim.snapshot())==state,"Classic retains the same visual-event-driven game state")
	game.set_classic(false)
	game.renderer.combat_fx.update(0.7)
	await capture("polish_smoke_and_ruins")
	game.renderer.combat_fx.shake_mode=0
	game.renderer.combat_fx.update(0.01)
	check(game.renderer.combat_fx.offset==Vector2.ZERO,"Camera impact OFF works")
	for quality in 3:
		game.renderer.combat_fx.quality=quality
		await process_frame
	check(game.renderer.combat_fx.ruins.size()==1,"All quality levels preserve destruction feedback")
	for i in 260: game.renderer.combat_fx.emit_effect("impact",{"pos":Vector2(650,1400),"weapon":"pulse"})
	check(game.renderer.combat_fx.particles.size()<=220,"Burst storage is bounded")
	game.renderer.combat_fx.update(150)
	check(game.renderer.combat_fx.particles.is_empty() and game.renderer.combat_fx.ruins.size()==1,"Transient particles expire while structural remains persist")
	game.show_options(game.show_pause)
	await create_timer(0.24).timeout
	await capture("polish_options")
	var options: Control = game.overlay.find_child("OptionsPanel",true,false)
	for child in options.get_children():
		if child is Button and child.text=="BILD":
			check(true,"Tabbed options expose an image tab")
		if child is Button and child.text=="AUDIO":
			child.pressed.emit()
			check(game.options_tab=="AUDIO","Audio tab switches the visible options group")
			break
	await create_timer(0.2).timeout
	await capture("polish_options_audio")
	var old_music_volume: float=game.music.music_volume
	var music_slider := game.overlay.find_child("MusicVolumeSlider",true,false) as HSlider
	check(music_slider!=null,"Audio tab contains the music slider")
	if music_slider:
		music_slider.value=0.42
		check(is_equal_approx(game.music.music_volume,0.42),"Audio slider updates the live music volume")
		music_slider.value=old_music_volume
	game.show_options(game.show_pause,"BILD")
	options=game.overlay.find_child("OptionsPanel",true,false)
	var visible_size := game.get_viewport_rect().size
	check(options.position.x>=0 and options.position.y>=0 and options.position.x+options.size.x<=visible_size.x and options.position.y+options.size.y<=visible_size.y,"Options panel stays centered within the active viewport")
	var resolution_option := options.find_child("ResolutionSelect",true,false) as OptionButton
	var mode_option := options.find_child("WindowModeSelect",true,false) as OptionButton
	check(resolution_option!=null and mode_option!=null,"Resolution and window mode remain available in the image tab")
	check(resolution_option!=null and resolution_option.item_count==3 and resolution_option.get_item_text(0)=="1920 × 1080","Resolution options exclude sizes below Full HD")
	check(game._normalize_window_resolution(Vector2i(1600,900))==Vector2i(1920,1080),"Previously saved sub-Full-HD window sizes migrate to Full HD")
	var original_size: Vector2i=game.get_window().size
	var original_mode: int=game.get_window().mode
	var original_borderless: bool=game.get_window().borderless
	# GitHub-hosted Windows runners have no interactive desktop; their virtual
	# display can report exclusive fullscreen even after requesting windowed mode.
	# Exercise the real OS transitions on local desktops where they are observable.
	if OS.get_environment("GITHUB_ACTIONS")!="true":
		resolution_option.select(0); resolution_option.item_selected.emit(0)
		check(game.get_window().size==Vector2i(1920,1080),"Resolution dropdown applies Full HD")
		var original_resolution_index := 0
		for i in resolution_option.item_count:
			if resolution_option.get_item_text(i)=="%d × %d" % [original_size.x,original_size.y]: original_resolution_index=i
		resolution_option.select(original_resolution_index); resolution_option.item_selected.emit(original_resolution_index)
		mode_option.select(1); mode_option.item_selected.emit(1)
		check(game.get_window().mode==Window.MODE_WINDOWED and game.get_window().borderless,"Borderless window mode applies")
		mode_option.select(2); mode_option.item_selected.emit(2)
		check(game.get_window().mode==Window.MODE_FULLSCREEN,"Fullscreen mode applies from the options dropdown")
		var restore_mode_index := 2 if original_mode==Window.MODE_FULLSCREEN else (1 if original_borderless else 0)
		mode_option.select(restore_mode_index); mode_option.item_selected.emit(restore_mode_index)
		await create_timer(0.25).timeout
		if original_mode not in [Window.MODE_WINDOWED,Window.MODE_FULLSCREEN] or original_borderless:
			game.get_window().mode=original_mode; game.get_window().borderless=original_borderless; game.persist_settings()
		check(game.get_window().mode==original_mode and game.get_window().borderless==original_borderless,"Window mode restores after test ("+str(original_mode)+" → "+str(game.get_window().mode)+")")
	else:
		check(true,"Display controls are present; native mode switching is covered on local desktops")
	var original_classic:bool=game.classic
	var previous_launcher_override:String=OS.get_environment("SOLARIT_LAUNCH_FULL_HD")
	OS.set_environment("SOLARIT_LAUNCH_FULL_HD","1")
	game._apply_launcher_display_override()
	check(game.get_window().size==Vector2i(1920,1080) and game.get_window().mode==Window.MODE_FULLSCREEN and not game.classic,"Launcher forces Full HD Modern fullscreen over saved display preferences")
	if previous_launcher_override.is_empty(): OS.unset_environment("SOLARIT_LAUNCH_FULL_HD")
	else: OS.set_environment("SOLARIT_LAUNCH_FULL_HD",previous_launcher_override)
	game.set_classic(original_classic)
	game.get_window().size=original_size
	game.get_window().mode=original_mode
	game.get_window().borderless=original_borderless
	game.persist_settings()
	var shake_option := options.find_child("CameraShake",true,false) as Button
	if shake_option:
		shake_option.pressed.emit()
		check(game.renderer.combat_fx.shake_mode==1,"Camera impact setting changes through its button")
	options=game.overlay.find_child("OptionsPanel",true,false)
	var quality_option := options.find_child("EffectQuality",true,false) as Button
	if quality_option:
		quality_option.pressed.emit()
		check(game.renderer.combat_fx.quality==0,"Effect quality changes through its button")
	game.show_options(game.show_pause,"STEUERUNG")
	await create_timer(0.2).timeout
	await capture("polish_options_controls")
	check(game.overlay.find_child("OptionsPanel",true,false).find_child("repair",true,false)!=null,"Keybinding tab exposes the repair action")
	var repair_key := game.overlay.find_child("repair",true,false) as Button
	var prior_repair_key: int=game.hotkeys.repair
	repair_key.pressed.emit()
	var key_event := InputEventKey.new(); key_event.keycode=KEY_T; key_event.pressed=true
	game._unhandled_input(key_event)
	check(game.hotkeys.repair==KEY_T and game.options_tab=="STEUERUNG","A clicked key binding captures a new key and stays on its tab")
	game.hotkeys.repair=prior_repair_key; game.persist_settings()
	game.show_options(game.show_pause,"GAMEPLAY")
	check(game.options_tab=="GAMEPLAY","Gameplay tab opens without losing the options panel")
	await create_timer(0.2).timeout
	await capture("polish_options_gameplay")
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	check(settings.get_value("video","shake")==1 and settings.get_value("video","effects")==0,"Presentation preferences persist")
	game.music.shutdown(); game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("POLISH PASS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
