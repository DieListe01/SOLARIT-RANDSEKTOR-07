extends SceneTree

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
	# Isolated art fixture: uses the shipped renderer and all shipped entity definitions.
	for e in game.sim.entities.values():
		if e.building: game.sim.grid.reserve(e.cell,game.sim.definition(e).footprint,0,false)
	game.sim.entities.clear(); game.sim.known=[{},{}]
	var building_ids: Dictionary={}
	var index := 0
	for kind in ["core","power","factory","refinery","repair","radar","tower","armory"]:
		var cell := Vector2i(10+(index%4)*5,37+floori(index/4.0)*6)
		var building_id: int=game.sim.spawn(kind,0,Vector2(cell)*32,true)
		building_ids[kind]=building_id
		if kind in ["factory","refinery","radar"]: game.sim.entities[building_id].upgrade_level=1
		if kind=="armory": game.sim.entities[building_id].upgrade_level=2
		if kind=="factory": game.sim.entities[building_id].queue.append({"kind":"tank"})
		if kind=="repair":
			game.sim.entities[building_id].repair=true
			game.sim.entities[building_id].hp-=120
		if kind=="tower": game.sim.entities[building_id].turret=1.1
		index+=1
	index=0
	for kind in ["scout","tank","siege","harvester","raider","lancer","scorcher","bulwark"]:
		var id: int = game.sim.spawn(kind,0,Vector2(330+(index%4)*150,1460+floori(index/4.0)*70),false)
		game.sim.entities[id].angle=-0.35; game.sim.entities[id].turret=-0.65
		game.sim.entities[id].cargo=160.0
		if kind=="harvester":
			game.sim.entities[id].harvest_state="UNLOAD"
			game.selected=[id]
			game.renderer.selected=[id]
			game.sim.entities[id].pos=game.sim.entities[building_ids["refinery"]].pos+Vector2(25,18)
		index+=1
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=Vector2(636,1394); game.renderer.zoom=2.15
	game.renderer.fog_timer=0
	game.category="buildings"; game.build_hud()
	# Let the real in-game cache render each authored model and settle its active
	# phase before saving visual QA, instead of capturing temporary 2D fallbacks.
	await create_timer(3.0).timeout
	game.renderer.queue_redraw()
	await process_frame
	await capture("industrial_showcase_v0.38.0")
	var standard_zoom:float=game.renderer.zoom
	for zoom_factor in [1.25,1.5]:
		game.renderer.zoom=standard_zoom*zoom_factor
		game.renderer.queue_redraw()
		await create_timer(0.9).timeout
		await capture("industrial_detail_zoom_%d_v0.38.0"%roundi(zoom_factor*100.0))
	game.renderer.zoom=standard_zoom
	game.renderer.queue_redraw()
	game.sim.effects.append({"pos":Vector2(820,1480),"life":0.65,"max_life":0.8,"radius":55.0})
	game.sim.effects.append({"pos":Vector2(720,1510),"life":0.22,"max_life":0.35,"radius":24.0})
	var tank: Dictionary = game.sim.entities.values().filter(func(e):return e.kind=="tank")[0]
	game.renderer.visual_event("shot",tank.pos)
	game.sim.projectiles.append({"pos":tank.pos+Vector2(70,-40),"last":Vector2(820,1480),"owner":0,"weapon":"cannon","target":0,"life":1.0})
	# Weapon identifiers come from the catalog, not an assumed hard-coded name.
	game.sim.projectiles[0].weapon=game.sim.definition(tank).weapon
	await capture("modern_effects_v0.38.0")
	game.set_classic(true)
	await capture("industrial_classic_v0.38.0")
	game.music.shutdown(); game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("VISUAL SHOWCASE: all 8 buildings and 8 vehicles rendered in Modern and Classic")
	quit()
