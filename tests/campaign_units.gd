extends SceneTree

var checks:=0
var failures: Array[String]=[]

func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error("CAMPAIGN FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog:=Catalog.new("res://data/dry_vein.json")
	check(catalog.errors.is_empty(),"new unit and upgrade catalog validates")
	check(catalog.units.raider.weapon=="shard" and catalog.units.lancer.weapon=="lance","new vehicles use different weapon profiles")
	check(catalog.weapons.shard.reload<catalog.weapons.lance.reload and catalog.units.raider.speed>catalog.units.lancer.speed,"skirmisher and precision roles have different tempo")
	check(catalog.units.scorcher.weapon=="flame" and catalog.weapons.flame.splash>0,"scorcher uses an area flame weapon")
	check(catalog.units.bulwark.armor=="heavy" and catalog.weapons.breaker.type=="siege","bulwark is a heavily armored structure breaker")
	var locked:=Simulation.new(catalog,"forge","normal",0)
	locked.credits[0]=50000
	var factory_id:=locked.spawn("factory",0,Vector2(12,46)*32,true)
	var armory_id:=locked.spawn("armory",0,Vector2(17,46)*32,true)
	check(not locked.prerequisites("armory",0),"armory stays campaign-locked before first mission completion")
	check(not locked.upgrade_building(armory_id,0),"upgrade cannot exceed campaign unlock")
	var first_unlock:=Simulation.new(catalog,"forge","normal",1)
	first_unlock.credits[0]=50000
	factory_id=first_unlock.spawn("factory",0,Vector2(12,46)*32,true)
	armory_id=first_unlock.spawn("armory",0,Vector2(17,46)*32,true)
	check(first_unlock.prerequisites("armory",0),"first campaign reward unlocks armory construction")
	check(not first_unlock.prerequisites("raider",0),"raider requires a level-one armory")
	check(first_unlock.submit_command({"type":"upgrade","owner_id":0,"id":armory_id},0),"player can order first armory upgrade")
	check(not first_unlock.submit_command({"type":"upgrade","owner_id":1,"id":armory_id},1),"enemy cannot upgrade player facility")
	check(not first_unlock.prerequisites("scorcher",0),"factory upgrade is required for scorcher")
	check(first_unlock.upgrade_building(factory_id,0),"factory upgrade is available after first campaign reward")
	var factory: Dictionary=first_unlock.entities[factory_id]
	for i in 100: first_unlock.process_building(factory,0.5)
	check(factory.upgrade_level==1 and first_unlock.prerequisites("scorcher",0),"factory upgrade unlocks the scorcher")
	check(first_unlock.enqueue("scorcher",0),"unlocked scorcher can be queued")
	var refinery_id:=first_unlock.spawn("refinery",0,Vector2(22,46)*32,true)
	check(first_unlock.upgrade_building(refinery_id,0),"refinery upgrade is available after first campaign reward")
	var refinery: Dictionary=first_unlock.entities[refinery_id]
	for i in 100: first_unlock.process_building(refinery,0.5)
	check(refinery.upgrade_level==1,"refinery reaches its improved yield tier")
	var harvester_id:=first_unlock.spawn("harvester",0,Vector2(27,49)*32,false)
	var harvester: Dictionary=first_unlock.entities[harvester_id]
	var dock:=first_unlock.grid.center(first_unlock.grid.nearest_free(first_unlock.grid.cell(refinery.pos)+Vector2i(0,2)))
	harvester.pos=dock; harvester.cargo=100.0; harvester.harvest_state="UNLOAD"
	var credits_before: float=first_unlock.credits[0]
	first_unlock.harvest(harvester,0.5)
	check(is_equal_approx(first_unlock.credits[0]-credits_before,96.0),"upgraded refinery pays 20% more for delivered solarite")
	var armory: Dictionary=first_unlock.entities[armory_id]
	for i in 100: first_unlock.process_building(armory,0.5)
	check(armory.upgrade_level==1 and not armory.upgrading,"first workshop tier completes over time")
	check(first_unlock.prerequisites("raider",0),"tier one unlocks the raider")
	check(first_unlock.enqueue("raider",0),"unlocked raider can be queued at the factory")
	var second_unlock:=Simulation.new(catalog,"forge","normal",2)
	second_unlock.credits[0]=50000
	second_unlock.spawn("factory",0,Vector2(12,46)*32,true)
	var advanced_id:=second_unlock.spawn("armory",0,Vector2(17,46)*32,true)
	var advanced: Dictionary=second_unlock.entities[advanced_id]
	advanced.upgrade_level=1
	check(second_unlock.prerequisites("raider",0),"later campaign keeps earlier vehicle unlock")
	check(not second_unlock.prerequisites("lancer",0),"precision vehicle waits for tier two")
	check(second_unlock.upgrade_building(advanced_id,0),"second campaign reward permits tier-two upgrade")
	for i in 140: second_unlock.process_building(advanced,0.5)
	check(advanced.upgrade_level==2,"tier two armory upgrade completes")
	check(not second_unlock.prerequisites("lancer",0) and second_unlock.missing_requirements("lancer",0).any(func(reason):return reason.contains("Freie Energie")),"late precision vehicle clearly requires spare power")
	check(not second_unlock.enqueue("bulwark",0),"heavy breakthrough tank cannot start without free power")
	second_unlock.spawn("power",0,Vector2(30,46)*32,true)
	check(not second_unlock.prerequisites("lancer",0),"one generator leaves too little spare power for late vehicles")
	second_unlock.spawn("power",0,Vector2(35,46)*32,true)
	check(second_unlock.prerequisites("lancer",0) and second_unlock.prerequisites("bulwark",0),"additional generators unlock late vehicle assembly")
	var power_before: Vector2=second_unlock.power(0)
	check(second_unlock.enqueue("bulwark",0),"heavy vehicle can begin when its power reserve is available")
	check(second_unlock.power(0).x-power_before.x==55,"active heavy vehicle assembly uses its power reserve")
	check(second_unlock.enqueue("lancer",0),"factory queue reserves power for the following advanced vehicle")
	var radar_id:=second_unlock.spawn("radar",0,Vector2(22,46)*32,true)
	check(second_unlock.upgrade_building(radar_id,0),"radar network can be expanded at campaign tier two")
	var radar: Dictionary=second_unlock.entities[radar_id]
	for i in 100: second_unlock.process_building(radar,0.5)
	check(radar.upgrade_level==1,"radar upgrade completes")
	var vision_sim:=Simulation.new(catalog,"forge","normal",2)
	vision_sim.entities.clear()
	var vision_id:=vision_sim.spawn("radar",0,Vector2(30,30)*32,true)
	vision_sim.fog[0].fill(0); vision_sim.explored[0].fill(0); vision_sim.update_fog(false)
	var initial_sight:=0
	for cell_value in vision_sim.fog[0]: initial_sight+=int(cell_value)
	check(vision_sim.upgrade_building(vision_id,0),"isolated radar can begin its tier-two expansion")
	var vision_building: Dictionary=vision_sim.entities[vision_id]
	for i in 100: vision_sim.process_building(vision_building,0.5)
	vision_sim.fog[0].fill(0); vision_sim.explored[0].fill(0); vision_sim.update_fog(false)
	var upgraded_sight:=0
	for cell_value in vision_sim.fog[0]: upgraded_sight+=int(cell_value)
	check(upgraded_sight>initial_sight,"radar upgrade increases revealed map area")
	var restored:=Simulation.new(catalog)
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(second_unlock.snapshot()))
	check(restored.restore(snapshot)==OK,"upgraded armory remains compatible with save/load")
	var save_armories:=restored.buildings(0,"armory")
	check(not save_armories.is_empty() and save_armories[0].upgrade_level==2,"armory tier survives save/load")
	print("CAMPAIGN UNITS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
