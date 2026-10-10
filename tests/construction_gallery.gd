extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	for e in game.sim.entities.values():
		if e.building: game.sim.grid.reserve(e.cell,game.sim.definition(e).footprint,0,false)
	game.sim.entities.clear(); game.sim.known=[{},{}]
	var center:=Vector2(920,1460)
	var stages: Array[float]=[0.18,0.42,0.68,0.91,1.0]
	for index in stages.size():
		var kind:=str(["power","refinery","factory","radar","repair"][index])
		var position:=center+Vector2((index-2)*310,0)
		var id: int=game.sim.spawn(kind,0,position,true)
		var entity: Dictionary=game.sim.entities[id]
		entity.complete=index==4
		entity.build_progress=float(game.sim.definition(entity).time)*stages[index]
		entity.hp=entity.max_hp
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=center
	game.renderer.zoom=1.9
	game.category="buildings"; game.build_hud()
	await create_timer(3.0).timeout
	game.renderer.queue_redraw(); await process_frame
	root.get_texture().get_image().save_png("res://test-output/construction_phases_v0.38.4.png")
	game.music.shutdown(); game.queue_free(); await process_frame; await create_timer(0.2).timeout
	print("CONSTRUCTION GALLERY: five authored 3D build phases captured at the same camera and zoom")
	quit()
