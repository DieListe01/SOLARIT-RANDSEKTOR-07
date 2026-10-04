extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error("IDENTITY FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func capture(game: Control, name_value: String) -> void:
	await process_frame
	await process_frame
	var image_value := root.get_texture().get_image()
	image_value.save_png("res://test-output/"+name_value+".png")
	var cyan := 0
	var red := 0
	# Check the actual rendered world rather than only palette constants.
	for y in range(int(image_value.get_height()*0.08),int(image_value.get_height()*0.94),2):
		for x in range(10,int(image_value.get_width()*0.81),2):
			var c := image_value.get_pixel(x,y)
			if c.r<0.3 and c.g>0.5 and c.b>0.5: cyan+=1
			if c.r>0.5 and c.g<0.45 and c.b<0.35: red+=1
	check(cyan>10 and red>10,"Both team colors are visible in "+name_value)
	check(image_value.get_width()==(640 if game.classic else 1920),"Actual mode resolution")

func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	check(game.sim.player_colors.size()==8,"Eight distinct configurable player slots")
	check(game.sim.team_color(0)!=game.sim.team_color(1),"Friendly and hostile colors differ")
	var snapshot: Dictionary = game.sim.snapshot()
	game.sim.player_colors[0]="408bf4"
	check(game.sim.restore(snapshot)==OK and game.sim.team_color(0)==Color("19ddd4"),"Player palette survives saves")
	var broken := snapshot.duplicate(true)
	broken.player_colors=["invalid","ff0000"]
	var before := JSON.stringify(game.sim.snapshot())
	check(game.sim.restore(broken)==ERR_INVALID_DATA and JSON.stringify(game.sim.snapshot())==before,"Invalid palette rejected before mutation")
	for e in game.sim.entities.values():
		if e.building: game.sim.grid.reserve(e.cell,game.sim.definition(e).footprint,0,false)
	game.sim.entities.clear(); game.sim.known=[{},{}]
	game.sim.spawn("core",0,Vector2(288,1248),true)
	game.sim.spawn("power",0,Vector2(416,1248),true)
	game.sim.spawn("radar",0,Vector2(288,1376),true)
	game.sim.spawn("core",1,Vector2(832,1248),true)
	var construction: int = game.sim.spawn("power",1,Vector2(960,1248),true,false)
	game.sim.entities[construction].build_progress=float(game.sim.db.buildings.power.time)*0.6
	var friendly := 0
	var hostile := 0
	for owner in 2:
		var index := 0
		for kind in ["scout","tank","siege","harvester"]:
			var id: int = game.sim.spawn(kind,owner,Vector2(300+owner*450+index*70,1540),false)
			var e: Dictionary = game.sim.entities[id]
			e.angle=-0.3 if owner==0 else PI+0.3; e.turret=e.angle
			e.cargo=130; e.harvest_state="HARVEST" if kind=="harvester" else "IDLE"
			if kind=="tank":
				if owner==0: friendly=id
				else: hostile=id; e.hp=e.max_hp*0.5
			index+=1
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=Vector2(650,1440); game.renderer.zoom=1.65; game.renderer.fog_timer=0
	game.selected=[friendly]; game.inspected=hostile; game.build_hud(); game.update_hud()
	check(game.information.text.contains("FEIND"),"Enemy inspection identifies allegiance")
	var goal: Vector2 = game.sim.entities[hostile].destination
	game.sim.command(game.selected,Vector2(510,1570),"move")
	check(game.sim.entities[hostile].destination==goal,"Inspection cannot command hostile entities")
	await create_timer(0.3).timeout
	await capture(game,"friend_foe_modern")
	var same_state := JSON.stringify(game.sim.snapshot())
	game.set_classic(true)
	await capture(game,"friend_foe_classic")
	check(JSON.stringify(game.sim.snapshot())==same_state,"Classic preserves game state and identity")
	game.set_classic(false)
	await process_frame
	for e in game.sim.entities.values():
		if e.kind=="harvester": e.harvest_state="IDLE"; e.order="stop"
	# Once the fixture resumes, genuine local vision must keep the enemy inspectable.
	game.sim.spawn("scout",0,game.sim.entities[hostile].pos-Vector2(60,0),false)
	game.sim.update_fog()
	game.edge_scroll=false; game.paused=false
	var mouse_point: Vector2 = game.WORLD_RECT.position+game.WORLD_RECT.size*0.5+(game.sim.entities[hostile].pos-game.renderer.camera)*game.renderer.zoom
	mouse_point=root.get_final_transform()*game.get_global_transform_with_canvas()*mouse_point
	var motion := InputEventMouseMotion.new()
	motion.position=mouse_point; motion.global_position=mouse_point
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position=mouse_point; click.global_position=mouse_point; click.button_index=MOUSE_BUTTON_LEFT; click.pressed=pressed
		Input.parse_input_event(click)
		await process_frame
	game.paused=true
	check(game.inspected==hostile and game.selected.is_empty(),"Real enemy click uses inspection, not command selection")
	var enemy_order: String = game.sim.entities[hostile].order
	game.issue_context_order(Vector2(520,1600))
	check(game.sim.entities[hostile].order==enemy_order,"Context order cannot control inspected enemies")
	game.music.shutdown(); game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("COLOR IDENTITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
