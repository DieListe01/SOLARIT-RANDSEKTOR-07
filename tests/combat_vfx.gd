extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
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
	var fx: CombatEffects = game.renderer.combat_fx
	fx.reset(); fx.quality=2; fx.shake_mode=1
	game.sim.fog[0].fill(1); game.sim.explored[0].fill(1)
	game.renderer.camera=Vector2(540,1460); game.renderer.zoom=1.35; game.renderer.fog_timer=0
	var snapshot := JSON.stringify(game.sim.snapshot())
	var random_state: int = game.sim.rng.state
	check(fx.FAMILIES.size()==8,"Eight independent weapon presentation profiles")
	var index := 0
	for name_value in fx.FAMILIES:
		var pos := Vector2(220+(index%4)*180,1310+(index/4)*200)
		fx.emit_effect("shot",{"pos":pos-Vector2(35,35),"angle":0.3,"weapon":name_value})
		fx.emit_effect("impact",{"pos":pos,"weapon":name_value})
		check(game.music.samples.has(name_value.to_lower()+"_shot") and game.music.samples.has(name_value.to_lower()+"_impact"),"Family audio: "+name_value)
		index+=1
	check(fx.craters.size()==3,"Artillery, missile and siege leave cosmetic craters")
	fx.update(0.10)
	check(JSON.stringify(game.sim.snapshot())==snapshot and game.sim.rng.state==random_state,"Presentation preserves complete state and simulation RNG")
	await capture("combat_families_modern")
	game.set_classic(true)
	await capture("combat_families_classic")
	game.set_classic(false); fx.reset()
	for ratio in [1.0,0.7,0.69,0.4,0.39,0.15,0.14]:
		check(fx.damage_stage(ratio)==(3 if ratio<0.15 else (2 if ratio<0.4 else (1 if ratio<0.7 else 0))),"Exact damage boundary "+str(ratio))
	for e in game.sim.entities.values():
		if e.owner==0: e.hp=e.max_hp*0.12
	game.renderer.elapsed=3.4
	await capture("combat_critical_damage")
	fx.emit_effect("destroy",{"pos":Vector2(520,1460),"building":true,"kind":"core","angle":0.0})
	check(fx.particles[0].core and fx.particles[0].radius>140,"Core receives distinct overload and larger blast")
	fx.update(0.62)
	await capture("combat_core_destruction")
	fx.update(1.5)
	await capture("combat_core_smoke")
	check(fx.ruins.size()==1,"Core ruin persists beyond primary blast")
	for i in 300: fx.emit_effect("impact",{"pos":Vector2(520,1460),"weapon":"mortar"})
	check(fx.particles.size()<=220 and fx.craters.size()<=80,"Particle and crater budgets bounded")
	fx.shake_mode=0; fx.update(0.01)
	check(fx.offset==Vector2.ZERO,"Camera OFF suppresses all impulses")
	fx.update(150)
	check(fx.particles.is_empty() and fx.craters.size()==80 and fx.ruins.size()==1,"Transient particles expire; bounded battlefield memory persists")
	game.music.shutdown(); game.queue_free()
	await process_frame
	print("COMBAT VFX: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
