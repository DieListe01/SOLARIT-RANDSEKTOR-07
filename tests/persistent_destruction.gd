extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("PERSISTENCE: "+message)
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")
func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	await process_frame
	game.sim.ai_timer=999999
	var fx: CombatEffects = game.renderer.combat_fx
	fx.reset(); fx.quality=2
	var tank: int = game.sim.spawn("tank",0,Vector2(500,1460),false)
	var foe: int = game.sim.spawn("tank",1,Vector2(630,1460),false)
	game.sim.entities[foe].hp=game.sim.entities[foe].max_hp*0.12
	game.sim.entities[foe].order="hold"
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.selected=[foe]; game.renderer.selected=[foe]
	game.sim.entities[tank].target=foe
	for i in 180:
		if game.sim.entities.has(foe):
			game.sim.combat(game.sim.entities[tank],1.0/30)
			game.sim.process_projectiles(1.0/30)
		fx.update(1.0/30)
	check(not game.sim.entities.has(foe) and fx.ruins.size()==1,"Actual tank shot leaves confirmed wreck")
	check(not game.selected.has(foe) and not game.renderer.selected.has(foe),"Dead selection cleared in death event")
	check(fx.smoke_strength(fx.ruins[0])>0,"Warm vehicle wreck still smokes")
	fx.update(60)
	check(fx.ruins.size()==1 and fx.smoke_strength(fx.ruins[0])==0,"Cold vehicle wreck survives sixty seconds")
	var factory: int = game.sim.spawn("factory",1,Vector2(800,1390),true)
	game.sim.entities[factory].hp=game.sim.entities[factory].max_hp*0.12
	check(fx.damage_stage(game.sim.entities[factory].hp/game.sim.entities[factory].max_hp)==3,"Factory severe state")
	game.sim.destroy(factory)
	var core: int = game.sim.spawn("core",1,Vector2(1050,1420),true)
	game.sim.destroy(core)
	check(fx.ruins[-1].core and fx.ruins[-1].radius>fx.ruins[-2].radius,"Core destruction exceeds factory scale")
	fx.emit_effect("impact",{"pos":Vector2(740,1550),"weapon":"mortar"})
	game.renderer.camera=Vector2(750,1460); game.renderer.zoom=1.5; game.renderer.fog_timer=0
	game.selected=[tank]; game.update_hud()
	fx.update(0.42)
	await capture("persistence_destruction_modern")
	fx.update(900)
	check(fx.ruins.size()==3 and fx.craters.size()==1 and fx.particles.is_empty(),"Fifteen minute battlefield keeps wrecks, ruins and crater")
	await capture("persistence_cold_modern")
	var original := fx.persistence_snapshot()
	var candidate := CombatEffects.new()
	check(candidate.restore_persistence(JSON.parse_string(JSON.stringify(original)),Vector2(2048,2048))==OK,"Cosmetic JSON round trip")
	check(JSON.parse_string(JSON.stringify(candidate.persistence_snapshot()))==JSON.parse_string(JSON.stringify(original)),"All persistent geometry and age survive round trip")
	var before := JSON.stringify(candidate.persistence_snapshot())
	for mutation in ["age","pos","footprint","kind","count"]:
		var bad: Dictionary = original.duplicate(true)
		match mutation:
			"age": bad.ruins[0].age=-1
			"pos": bad.ruins[0].pos=[INF,2]
			"footprint": bad.ruins[0].footprint=[999,1]
			"kind": bad.ruins[0].object_kind="unknown"
			"count":
				for i in 129: bad.ruins.append(original.ruins[0].duplicate(true))
		check(candidate.restore_persistence(bad,Vector2(2048,2048))==ERR_INVALID_DATA and JSON.stringify(candidate.persistence_snapshot())==before,"Invalid "+mutation+" rejects atomically")
	game.sim.update_fog()
	var reference := Simulation.new(game.db)
	reference.restore(JSON.parse_string(JSON.stringify(game.sim.snapshot())))
	var simulation_before := JSON.stringify(reference.snapshot())
	var rng_before: int = game.sim.rng.state
	game.save_game(game.SAVE_PATH,false)
	game.load_game(); game.paused=true
	await process_frame
	fx=game.renderer.combat_fx
	check(fx.ruins.size()==3 and fx.craters.size()==1,"Actual save/load survives renderer grid reset")
	check(JSON.stringify(game.sim.snapshot())==simulation_before and game.sim.rng.state==rng_before,"Cosmetic save/load preserves simulation and RNG")
	var saved_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	var corrupt := saved_data.duplicate(true)
	corrupt.visual_state.ruins[0].age=-1
	var rejected_file := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	rejected_file.store_string(JSON.stringify(corrupt)); rejected_file.close()
	var original_model: Simulation = game.sim
	game.load_game()
	check(game.sim==original_model and fx.ruins.size()==3,"Malformed visual save leaves active mission unchanged")
	game.clear(game.overlay)
	var unaffected := JSON.stringify(game.sim.snapshot())
	var unaffected_rng: int = game.sim.rng.state
	fx.update(900)
	check(JSON.stringify(game.sim.snapshot())==unaffected and game.sim.rng.state==unaffected_rng,"Long cosmetic lifecycle never mutates authority or its RNG")
	game.set_classic(true)
	await capture("persistence_cold_classic")
	check(root.get_texture().get_image().get_width()==640 and fx.ruins.size()==3,"Classic retains same destruction at true pixel resolution")
	game.set_classic(false)
	# Real 20-versus-20 combat uses normal damage, target acquisition and tick rules.
	game.sim=Simulation.new(game.db); game.connect_sim(); game.sim.ai_timer=999999
	await process_frame
	fx=game.renderer.combat_fx
	for owner in 2:
		for i in 20:
			game.sim.spawn("tank",owner,Vector2(620+owner*160+(i%4)*18,1270+floori(i/4.0)*38),false)
	game.renderer.camera=Vector2(735,1370); game.renderer.zoom=1.65
	var started := Time.get_ticks_usec()
	var peak := 0
	var death_count := 0
	for i in 900:
		var tick_start := Time.get_ticks_usec()
		game.sim.tick(1.0/30)
		fx.update(1.0/30)
		peak=maxi(peak,Time.get_ticks_usec()-tick_start)
		if i==75:
			game.sim.fog[0].fill(1); game.sim.explored[0].fill(1); game.renderer.fog_timer=0
			await capture("persistence_20v20_modern")
			game.set_classic(true)
			await capture("persistence_20v20_classic")
			game.set_classic(false)
	death_count=fx.ruins.size()
	check(death_count>0 and death_count<=40,"20 versus 20 produces real combat wrecks")
	check(fx.particles.size()<=220 and fx.ruins.size()<=128 and fx.craters.size()<=80,"Combat presentation remains within budgets")
	print("20v20: %d remains; worst tick + FX %.2f ms; elapsed %.2f s" % [death_count,peak/1000.0,(Time.get_ticks_usec()-started)/1000000.0])
	fx.update(900)
	await capture("persistence_20v20_aftermath")
	check(fx.ruins.size()==death_count and fx.particles.is_empty(),"Mass battle aftermath remains cold and static")
	for i in 170:
		fx.emit_effect("destroy",{"pos":Vector2(500,1460),"angle":0.0,"kind":"tank","building":false})
	check(fx.ruins.size()==128,"Persistent memory recycles at fixed capacity")
	fx.reset()
	check(fx.ruins.is_empty() and fx.craters.is_empty(),"New mission/reset clears persistent memory")
	for i in 128:
		fx.emit_effect("destroy",{"pos":Vector2(500+i,1460),"angle":0.0,"kind":"core","building":true})
	fx.emit_effect("destroy",{"pos":Vector2(500,1500),"angle":0.0,"kind":"tank","building":false})
	check(fx.ruins.size()==128 and fx.ruins[-1].object_kind=="tank","Newest death always leaves remains even when pool was full of cores")
	fx.emit_effect("destroy",{"pos":Vector2(500,1600),"angle":0.0,"kind":"factory","building":true})
	check(fx.ruins.filter(func(r):return r.object_kind=="tank").is_empty() and fx.ruins[-1].object_kind=="factory","Recycling prefers old vehicles over cores")
	fx.reset()
	# Format-1 saves without cosmetics remain loadable.
	var legacy: Dictionary = game.sim.snapshot()
	var file := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	game.load_game(); game.paused=true
	await process_frame
	check(game.renderer.combat_fx.ruins.is_empty(),"Legacy saves load without cosmetic extension")
	game.music.shutdown(); game.queue_free()
	await process_frame
	print("PERSISTENT DESTRUCTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
