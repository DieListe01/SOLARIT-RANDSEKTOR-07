extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		push_error("FAIL: "+message)

func advance(sim: Simulation, seconds: float) -> void:
	for i in ceili(seconds*30): sim.tick(1.0/30.0)

func place(sim: Simulation, kind: String, c: Vector2i) -> int:
	var reason := sim.build_reason(kind,0,c)
	check(reason=="","Placement %s at %s: %s" % [kind,c,reason])
	return sim.build(kind,0,c) if reason=="" else 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := Catalog.new()
	check(db.errors.is_empty(),"Catalog validation")
	var sim := Simulation.new(db,"forge","easy")
	sim.ai_timer=99999 # Isolate economy checks; enemy economy is exercised below.
	check(not sim.prerequisites("factory",0),"Factory locked before refinery")
	check(sim.build_reason("power",0,Vector2i(31,15))!="","Cliffs reject placement")
	check(sim.build_reason("power",0,Vector2i(59,59))!="","Build radius rejects remote placement")
	var initial := float(sim.credits[0])
	var power := place(sim,"power",Vector2i(14,43))
	check(sim.credits[0]==initial-sim.cost("power",0),"Construction charged once")
	advance(sim,19)
	check(sim.entities.has(power) and sim.entities[power].complete,"Construction completes under low power")
	check(sim.powered(0),"Power generation")
	var refinery := place(sim,"refinery",Vector2i(14,47))
	advance(sim,13)
	check(sim.entities.has(refinery) and sim.entities[refinery].complete,"Refinery completes")
	var harvesters := sim.entities.values().filter(func(e):return e.owner==0 and e.kind=="harvester")
	check(harvesters.size()==1,"Refinery supplies one included harvester")
	advance(sim,70)
	check(float(sim.stats.gathered)>200,"Autonomous harvesting delivers credits")
	check(sim.grid.resources.values().any(func(a):return a<2200),"Harvest depletes actual fields")
	var factory := place(sim,"factory",Vector2i(9,49))
	advance(sim,16)
	check(sim.entities.has(factory) and sim.entities[factory].complete,"Factory completes")
	check(sim.enqueue("tank",0),"Paid production")
	var before_cancel := float(sim.credits[0])
	check(sim.cancel_queue("tank",0),"Queue cancellation")
	check(is_equal_approx(float(sim.credits[0])-before_cancel,sim.cost("tank",0)*0.75),"Cancellation partial refund")
	check(sim.enqueue("tank",0),"Queue after cancellation")
	advance(sim,10)
	var tanks := sim.entities.values().filter(func(e):return e.owner==0 and e.kind=="tank")
	check(tanks.size()==1,"Factory creates vehicle")
	if not tanks.is_empty():
		check(tanks[0].destination==sim.entities[factory].rally,"Vehicle receives rally point")
		var scout: Dictionary = sim.entities.values().filter(func(e):return e.owner==0 and e.kind=="scout")[0]
		var goal := sim.grid.center(Vector2i(45,36))
		var path := sim.grid.path(scout.pos,goal)
		check(not path.is_empty(),"A-star crosses the pass")
		for p in path: check(sim.grid.is_free(sim.grid.cell(p)),"Path avoids buildings and cliffs")
		sim.command([scout.id],goal)
		advance(sim,24)
		check(scout.pos.distance_to(goal)<65,"Scout traverses pass without sticking")
	# Save round-trip includes paths, bullets, known intel, construction and queues.
	sim.enqueue("tank",0)
	advance(sim,2)
	var save: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot(),"",true,true))
	var restored := Simulation.new(db)
	check(restored.restore(save)==OK,"Save reload")
	check(restored.entities.size()==sim.entities.size(),"Entity count preserved")
	check(restored.credits==sim.credits,"Credits preserved")
	var resources_preserved: bool = restored.grid.resources.size()==sim.grid.resources.size()
	for resource_key in sim.grid.resources:
		if not restored.grid.resources.has(resource_key) or absf(float(restored.grid.resources.get(resource_key,-1))-float(sim.grid.resources[resource_key]))>1e-9: resources_preserved=false
	check(resources_preserved,"Resource depletion preserved within JSON floating-point round-trip precision")
	check(restored.known==sim.known,"AI intel preserved")
	check(restored.entities[factory].queue==sim.entities[factory].queue,"Production queue preserved")
	check(restored.restore({"format_version":99})==ERR_INVALID_DATA,"Unknown save version rejected")
	var damaged_save: Dictionary = save.duplicate(true)
	damaged_save.entities[0].erase("pos")
	check(restored.restore(damaged_save)==ERR_INVALID_DATA,"Corrupt entity rejected without partial mutation")
	advance(restored,10)
	check(restored.stats.produced>=2,"Production continues after load")
	# Visibility and memory are separate, and the AI starts without hidden base knowledge.
	var fresh := Simulation.new(db)
	check(fresh.known[1].is_empty(),"Enemy has no omniscient knowledge")
	var enemy_core: Dictionary = fresh.buildings(1,"core")[0]
	check(not fresh.is_visible(enemy_core,0),"Enemy base hidden initially")
	advance(fresh,40)
	check(fresh.credits[1]<float(db.mission.credits[1])+400,"AI spends real credits")
	check(fresh.entities.values().filter(func(e):return e.owner==1 and not e.building).size()>3,"AI produces vehicles")
	# Regression: dead projectile targets and destroyed factories must be harmless.
	var collision := Simulation.new(db)
	var core: Dictionary = collision.buildings(1,"core")[0]
	collision.projectiles.append({"pos":core.pos-Vector2(5,0),"last":core.pos,"target":core.id,"owner":0,"weapon":"cannon","life":2.0})
	collision.destroy(core.id)
	collision.process_projectiles(1)
	check(collision.projectiles.is_empty(),"Projectile handles dead target")
	collision.check_objectives()
	check(collision.result=="victory","Data-driven victory objective")
	var defeat := Simulation.new(db)
	defeat.destroy(defeat.buildings(0,"core")[0].id)
	defeat.check_objectives()
	check(defeat.result=="defeat","Protected core defeat objective")
	# Damaged structures can be repaired for a non-zero credit cost.
	var repair := Simulation.new(db)
	var home: Dictionary = repair.buildings(0,"core")[0]
	home.hp-=100
	var cash := float(repair.credits[0])
	repair.repair_entity(home,0,1)
	check(home.hp>home.max_hp-100 and repair.credits[0]<cash,"Repairs consume credits")
	# Factories must never teleport produced units through a blocked perimeter.
	var blocked := Simulation.new(db)
	var building_id := blocked.spawn("factory",0,Vector2(10,38)*32,true)
	var producer: Dictionary = blocked.entities[building_id]
	for y in range(37,42):
		for x in range(9,14):
			var cell := Vector2i(x,y)
			if x in [9,13] or y in [37,41]: blocked.grid.reserve(cell,[1,1],9000+x+y*64,true)
	producer.queue.append({"kind":"tank","paid":440})
	producer.progress=99.0
	blocked.process_building(producer,1)
	check(producer.queue.size()==1,"Surrounded factory retains completed production")
	blocked.grid.reserve(Vector2i(10,41),[1,1],0,false)
	blocked.process_building(producer,1)
	check(producer.queue.is_empty(),"Factory resumes when a perimeter exit opens")
	var pending := Simulation.new(db)
	var pending_scout: Dictionary = pending.entities.values().filter(func(e):return e.owner==0 and e.kind=="scout")[0]
	pending.command([pending_scout.id],pending_scout.pos+Vector2(100,0))
	pending.command([pending_scout.id],Vector2.ZERO,"stop")
	pending.tick(1.0/30)
	check(pending_scout.path.is_empty() and not pending_scout.path_pending,"Stop cancels unprocessed movement requests")
	var manual_id := pending.spawn("harvester",0,pending.grid.center(Vector2i(17,43)),false)
	var manual: Dictionary = pending.entities[manual_id]
	pending.update_fog()
	pending.command([manual_id],pending.grid.center(Vector2i(19,43)),"harvest")
	var assigned: String = manual.resource
	manual.harvest_state="SEARCH_RESOURCE"
	pending.harvest(manual,1.0/30)
	check(manual.resource==assigned,"Assigned Solarit field remains preferred after unloading")
	pending.command([manual_id],Vector2(500,1200))
	pending.command([manual_id],Vector2.ZERO,"return")
	check(not manual.path_pending and manual.harvest_state=="RETURN_TO_BASE","Unload cancels an old pending travel destination")
	var automatic := Simulation.new(db)
	automatic.ai_timer=99999
	automatic.spawn("refinery",0,Vector2(14,47)*32,true)
	var collector_id := automatic.spawn("harvester",0,automatic.grid.center(Vector2i(17,43)),false)
	advance(automatic,80)
	check(automatic.stats.gathered>=480,"Collector starts without orders and automatically completes multiple collect/unload cycles")
	var collector: Dictionary = automatic.entities[collector_id]
	automatic.command([collector_id],automatic.grid.center(Vector2i(17,44)))
	advance(automatic,12)
	check(collector.harvest_state!="IDLE","Collector automatically resumes work after a relocation")
	automatic.command([collector_id],Vector2.ZERO,"stop")
	advance(automatic,1)
	check(collector.harvest_state=="IDLE","Explicit Stop still suspends autonomous harvesting")
	var defense := Simulation.new(db)
	defense.ai_timer=99999
	var defender_id := defense.spawn("tank",0,defense.grid.center(Vector2i(15,39)),false)
	var foe_id := defense.spawn("tank",1,defense.grid.center(Vector2i(18,39)),false)
	defense.update_fog()
	var defender: Dictionary = defense.entities[defender_id]
	var destination := defense.grid.center(Vector2i(15,45))
	defense.command([defender_id],destination)
	defense.combat(defender,1.0/30)
	check(defender.target==foe_id and not defense.projectiles.is_empty(),"Moving combat vehicle automatically fires on a visible armed threat")
	check(defender.order=="move" and defender.destination==destination and defender.path_pending,"Automatic defense preserves the current travel order")
	var economy_target := defense.spawn("harvester",1,defense.grid.center(Vector2i(16,39)),false)
	defense.update_fog(); defender.target=economy_target; defender.reload=0
	defense.combat(defender,1.0/30)
	check(defender.target==foe_id,"Automatic defense switches from an economy target to an armed threat")
	defense.fog[0].fill(0); defender.target=0; defender.reload=0; defense.projectiles.clear()
	defense.combat(defender,1.0/30)
	check(defender.target==0 and defense.projectiles.is_empty(),"Automatic defense does not target threats hidden by fog")
	print("REGRESSION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
