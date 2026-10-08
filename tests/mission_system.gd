extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		push_error("MISSION FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var basin:=Catalog.new("res://data/veyra.json")
	var dry:=Catalog.new("res://data/dry_vein.json")
	var khepri:=Catalog.new("res://data/khepri_pass.json")
	check(basin.errors.is_empty(),"Mission 01 validates")
	check(dry.errors.is_empty(),"Mission 02 validates")
	check(khepri.errors.is_empty(),"Mission 03 validates")
	check(dry.mission.id=="dry_vein" and khepri.mission.id=="khepri_pass","Mission files load independently")
	for mission_data in [basin.mission,dry.mission,khepri.mission]:
		var optional_count: int=mission_data.get("objectives",[]).filter(func(item):return bool(item.get("optional",false))).size()
		check(optional_count==2,"Each campaign mission has two optional side objectives")
	var tutorial:=Simulation.new(Catalog.new("res://data/veyra.json"),"forge","normal")
	check(tutorial.credits[0]==4200 and tutorial.credits[1]==900,"Mission 01 gives the player a forgiving economy and slows the enemy opening")
	check(int(tutorial.db.rules.attack_grace.normal)==210 and int(tutorial.db.rules.ai_production_interval.normal)==24,"Mission 01 delays the first coordinated assault and enemy production")
	tutorial.spawn("power",0,Vector2(14,43)*32,true)
	tutorial.spawn("refinery",0,Vector2(14,47)*32,true)
	tutorial.spawn("factory",0,Vector2(18,43)*32,true)
	check(tutorial.prerequisites("tower",0) and not tutorial.prerequisites("radar",0) and not tutorial.prerequisites("repair",0),"Mission 01 teaches with basic defense while advanced facilities unlock later")
	check(tutorial.missing_requirements("radar",0).any(func(reason):return reason.contains("Kampagnenfreigabe")),"Radar explains its later campaign unlock")

	var economy:=Simulation.new(dry,"forge","normal")
	check(economy.result=="","Economy mission starts unresolved")
	economy.stats.gathered=8000.0
	economy.spawn("refinery",0,Vector2(8,55)*32,true)
	economy.spawn("refinery",0,Vector2(15,55)*32,true)
	for target in economy.buildings(1,"refinery",false).duplicate(): economy.destroy(target.id)
	economy.check_objectives()
	check(economy.result=="victory","Economy mission requires combined primary objectives")

	var defense:=Simulation.new(khepri,"forge","normal")
	var before:=defense.entities.values().filter(func(e):return e.owner==1 and not e.building).size()
	defense.time=55.0
	defense.process_mission_waves()
	var after:=defense.entities.values().filter(func(e):return e.owner==1 and not e.building).size()
	check(after>before,"Scripted defense wave spawns real enemy vehicles")
	check(defense.triggered_waves.has("0"),"Wave trigger is recorded")
	defense.process_mission_waves()
	var repeated:=defense.entities.values().filter(func(e):return e.owner==1 and not e.building).size()
	check(repeated==after,"Triggered wave cannot spawn twice")
	defense.time=900.0
	defense.check_objectives()
	check(defense.result=="victory","Survival objective wins with protected core")
	check(defense.stats.gathered<5000.0,"Optional Solarit target does not gate victory")
	check(defense.optional_objective_progress_text().contains("NEBENZIELE 0/2"),"HUD lists incomplete optional objectives after the mission ends")
	var bonus_run:=Simulation.new(khepri,"forge","normal")
	bonus_run.stats.gathered=5000.0
	bonus_run.check_objectives()
	check(bonus_run.objective_announced.has("harvest_bonus") and bonus_run.optional_objective_progress_text().contains("NEBENZIELE 1/2"),"Optional objective progress updates and records completion")
	bonus_run.time=900.0
	bonus_run.check_objectives()
	check(bonus_run.result=="victory","Completed optional goals coexist with the primary victory condition")

	var lost:=Simulation.new(khepri,"forge","easy")
	lost.destroy(lost.buildings(0,"core",false)[0].id)
	lost.check_objectives()
	check(lost.result=="defeat","Protected core loss still causes defeat")

	var saved:=Simulation.new(khepri,"forge","hard")
	saved.time=55.0
	saved.process_mission_waves()
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(saved.snapshot(),"",true,true))
	var restored:=Simulation.new(khepri)
	check(restored.restore(snapshot)==OK,"Wave mission save restores")
	check(restored.triggered_waves.has("0"),"Wave history survives save/load")

	print("MISSION SYSTEM: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
