extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("STYLE FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")
func commands(db: Catalog) -> void:
	var model := Simulation.new(db)
	var scout: int = model.spawn("scout",0,Vector2(450,1460),false)
	var foe: int = model.spawn("tank",1,Vector2(515,1460),false)
	var factory: int = model.spawn("factory",0,Vector2(384,1568),true)
	model.spawn("power",0,Vector2(192,1440),true)
	model.spawn("refinery",0,Vector2(288,1568),true)
	var collector: int = model.spawn("harvester",0,Vector2(570,1430),false)
	var core: int = model.buildings(0,"core")[0].id
	model.update_fog(); model.explored[0].fill(1)
	for entity in model.entities.values():
		check(entity.owner_id==entity.owner and entity.team_id==entity.owner and entity.faction_id==model.factions[entity.owner],"Explicit entity identity")
	var packet := {"type":"move","owner_id":0,"ids":[scout],"point":[480,1500]}
	check(model.submit_command(JSON.parse_string(JSON.stringify(packet)),0),"JSON movement command accepted")
	check(model.entities[scout].destination==Vector2(480,1500),"Movement applied")
	var before := JSON.stringify(model.snapshot())
	check(not model.submit_command(packet,1) and JSON.stringify(model.snapshot())==before,"Issuer spoof rejected atomically")
	for bad_ids in [[foe],[scout,foe],[scout,scout],[99999],[1.5]]:
		var invalid := packet.duplicate(true); invalid.ids=bad_ids
		check(not model.submit_command(invalid,0) and JSON.stringify(model.snapshot())==before,"Invalid actor set rejected atomically")
	check(not model.submit_command({"type":"move","owner_id":0,"ids":[scout],"point":[NAN,2]},0),"Nonfinite point rejected")
	check(model.submit_command({"type":"attack","owner_id":0,"ids":[scout],"point":[515,1460],"target_id":foe},0),"Visible hostile attack accepted")
	model.fog[0].fill(0)
	before=JSON.stringify(model.snapshot())
	check(not model.submit_command({"type":"attack","owner_id":0,"ids":[scout],"point":[515,1460],"target_id":foe},0) and JSON.stringify(model.snapshot())==before,"Hidden target attack rejected")
	model.update_fog()
	for order in ["stop","hold","guard"]:
		check(model.submit_command({"type":order,"owner_id":0,"ids":[scout]},0) and model.entities[scout].order==order,"Order "+order)
	check(model.submit_command({"type":"rally","owner_id":0,"ids":[factory],"point":[500,1700]},0) and model.entities[factory].rally==Vector2(500,1700),"Rally owner command")
	check(model.submit_command({"type":"repair","owner_id":0,"ids":[core],"enabled":true},0) and model.entities[core].repair,"Repair owner command")
	check(model.submit_command({"type":"produce","owner_id":0,"kind":"tank"},0),"Paid production command")
	check(model.submit_command({"type":"cancel_produce","owner_id":0,"kind":"tank"},0),"Production cancellation command")
	check(model.submit_command({"type":"harvest","owner_id":0,"ids":[collector],"point":[608,1408]},0),"Harvest owner command")
	check(model.submit_command({"type":"return","owner_id":0,"ids":[collector]},0),"Unload return command")
	var built := false
	for y in range(38,49):
		for x in range(5,16):
			if model.build_reason("power",0,Vector2i(x,y))=="":
				built=model.submit_command({"type":"build","owner_id":0,"kind":"power","cell":[x,y]},0); break
		if built: break
	check(built,"Build command uses authoritative placement checks")
	var save := model.snapshot()
	for entity in save.entities:
		entity.erase("owner_id"); entity.erase("team_id"); entity.erase("faction_id")
	check(model.restore(save)==OK and model.entities[scout].owner_id==0,"Legacy saves gain identity fields")
	var invalid_save := model.snapshot(); invalid_save.entities[0].owner_id=1-int(invalid_save.entities[0].owner)
	before=JSON.stringify(model.snapshot())
	check(model.restore(invalid_save)==ERR_INVALID_DATA and JSON.stringify(model.snapshot())==before,"Inconsistent saved ownership rejected before mutation")
func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	await process_frame
	commands(game.db)
	for entity in game.sim.entities.values():
		if entity.building: game.sim.grid.reserve(entity.cell,game.sim.definition(entity).footprint,0,false)
	game.sim.entities.clear(); game.sim.known=[{},{}]
	for item in [["core",320,1260],["power",190,1300],["refinery",310,1430],["factory",300,1610],["radar",180,1470],["repair",450,1660]]:
		game.sim.spawn(item[0],0,Vector2(item[1],item[2]),true)
	for item in [["core",1090,1240],["factory",790,1320],["power",1090,1430],["tower",800,1520]]:
		game.sim.spawn(item[0],1,Vector2(item[1],item[2]),true)
	var site: int = game.sim.spawn("power",0,Vector2(540,1660),true,false)
	game.sim.entities[site].build_progress=game.db.buildings.power.time*0.66
	var tank: int = game.sim.spawn("tank",0,Vector2(580,1520),false)
	var enemy: int = game.sim.spawn("tank",1,Vector2(730,1520),false)
	var siege: int = game.sim.spawn("siege",0,Vector2(520,1620),false)
	var harvester: int = game.sim.spawn("harvester",0,Vector2(620,1430),false)
	game.sim.spawn("scout",0,Vector2(500,1460),false)
	game.sim.spawn("scout",1,Vector2(850,1470),false)
	game.sim.entities[harvester].cargo=150; game.sim.entities[harvester].harvest_state="HARVEST"
	game.sim.entities[tank].target=enemy; game.sim.entities[siege].target=enemy
	game.sim.entities[enemy].angle=PI; game.sim.entities[enemy].turret=PI
	game.sim.entities[enemy].hp=game.sim.entities[enemy].max_hp*0.30
	game.sim.buildings(1,"power")[0].hp*=0.2
	game.sim.buildings(0,"factory")[0].queue=[{"kind":"tank","paid":440}]
	game.sim.buildings(0,"factory")[0].progress=8
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=Vector2(665,1470); game.renderer.zoom=1.4; game.renderer.fog_timer=0; game.renderer.elapsed=3.4
	game.selected=[tank]; game.category="units"; game.build_hud(); game.update_hud()
	check(game.selection_icons.get_child_count()==1,"Selected vehicle has portrait")
	check(game.information.text.contains("PANZERKANONE"),"Selection exposes weapon role")
	check(game.buttons.tank.text.contains(" s"),"Production cards expose build time")
	await process_frame
	var fx: CombatEffects = game.renderer.combat_fx
	fx.reset(); fx.quality=2
	game.sim.combat(game.sim.entities[tank],1.0/30)
	game.sim.combat(game.sim.entities[siege],1.0/30)
	game.sim.process_projectiles(0.6)
	var doomed_building: int = game.sim.spawn("refinery",1,Vector2(810,1640),true)
	var doomed_unit: int = game.sim.spawn("siege",1,Vector2(750,1650),false)
	game.sim.entities[doomed_unit].angle=2.5
	game.sim.destroy(doomed_building); game.sim.destroy(doomed_unit)
	fx.update(0.18)
	check(fx.ruins.size()==2 and fx.ruins[0].object_kind=="refinery" and fx.ruins[1].object_kind=="siege","Real deaths retain type-specific structural remains")
	await capture("style_battle_modern")
	check(game.information.get_visible_line_count()==game.information.get_line_count(),"Selected unit text is fully visible")
	check(game.production_bar.size.y<=10,"Production progress fits its thin reserved row")
	var snapshot := JSON.stringify(game.sim.snapshot())
	game.set_classic(true)
	await capture("style_battle_classic")
	check(root.get_texture().get_image().get_width()==640,"Classic remains a true low resolution render")
	check(JSON.stringify(game.sim.snapshot())==snapshot,"Style switch preserves complete simulation")
	game.set_classic(false); fx.update(5.0)
	await capture("style_aftermath_modern")
	game.selected=[tank,siege,harvester]; game.update_hud()
	check(game.selection_icons.get_child_count()==3,"Group selection shows vehicle grid")
	await capture("style_group_selection")
	game.sim.fog[0].fill(0)
	var count := fx.particles.size()
	game.on_presentation("destroy",{"pos":Vector2(750,1650),"owner":1,"building":true,"kind":"core","angle":0.0})
	check(fx.particles.size()==count,"Unseen combat never generates visible events")
	game.renderer.combat_fx.update(150)
	check(fx.ruins.size()==2,"Structural wrecks persist without gameplay blockers")
	game.music.shutdown(); game.queue_free()
	await process_frame
	print("STYLE CONSOLIDATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
