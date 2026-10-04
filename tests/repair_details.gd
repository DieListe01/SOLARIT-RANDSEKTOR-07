extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error("REPAIR: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game: Control = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.skip_intro(); game.start_game(); game.set_process(false)
 game.sim.ai_timer=99999; game.sim.ai_production_timer=99999
 var sim: Simulation = game.sim
 var core: Dictionary = sim.buildings(0,"core")[0]
 var initial_hp: float = core.hp
 core.hp-=100
 game.selected=[core.id]; game.update_hud()
 check(not game.repair_button.disabled and not game.details_button.disabled,"Actions available after selecting building")
 game.repair_button.pressed.emit()
 check(core.repair,"Visible button enables building repair")
 var money: float = sim.credits[0]
 sim.process_building(core,1.0)
 check(is_equal_approx(core.hp,initial_hp-74),"Building gains 26 HP per second")
 check(is_equal_approx(sim.credits[0],money-7.8),"Only repaired HP charged")
 game.repair_selection()
 check(not core.repair,"Building repair can be stopped")
 sim.credits[0]=0; core.repair=true
 var hp: float = core.hp
 sim.process_building(core,1)
 check(core.hp==hp,"No credits means no free healing")
 sim.credits[0]=1000; core.hp=core.max_hp-1
 sim.process_building(core,1)
 check(core.hp==core.max_hp and is_equal_approx(sim.credits[0],999.7),"Repair caps exactly at full health")
 var hangar_id := sim.spawn("repair",0,Vector2(14,43)*32,true)
 sim.spawn("power",0,Vector2(18,43)*32,true)
 var hangar: Dictionary = sim.entities[hangar_id]
 var tank_id := sim.spawn("tank",0,hangar.pos+Vector2(-70,0),false)
 var tank: Dictionary = sim.entities[tank_id]
 tank.hp-=100
 money=sim.credits[0]; hp=tank.hp
 sim.process_building(hangar,1)
 check(tank.hp==hp+26 and is_equal_approx(sim.credits[0],money-7.8),"Hangar automatically repairs nearby friendly vehicle")
 var enemy_id := sim.spawn("tank",1,hangar.pos+Vector2(-65,10),false)
 sim.entities[enemy_id].hp-=100
 var enemy_hp: float = sim.entities[enemy_id].hp
 sim.process_building(hangar,1)
 check(sim.entities[enemy_id].hp==enemy_hp,"Hangar does not repair enemies")
 tank.pos=sim.grid.center(sim.grid.nearest_free(sim.grid.cell(hangar.pos+Vector2(-180,-140)))); tank.hp-=50
 check(sim.submit_command({"type":"repair","owner_id":0,"ids":[tank_id]},0),"Vehicle accepts service destination")
 check(tank.destination.distance_to(hangar.pos)<100 and tank.order=="service","Vehicle ordered into repair range")
 tank.path=sim.grid.path(tank.pos,tank.destination)
 for step in 600: sim.move_unit(tank,1.0/30.0)
 check(tank.pos.distance_to(hangar.pos)<100,"Vehicle actually reaches repair range")
 hp=tank.hp; sim.process_building(hangar,1)
 check(tank.hp>hp,"Arriving vehicle receives automatic healing")
 var collector_id := sim.spawn("harvester",0,hangar.pos+Vector2(0,-70),false)
 var collector: Dictionary = sim.entities[collector_id]
 collector.hp-=100
 check(sim.submit_command({"type":"repair","owner_id":0,"ids":[collector_id]},0),"Collector can request service")
 collector.path=[]; collector.path_pending=false
 sim.harvest(collector,1)
 check(collector.harvest_state=="IDLE","Damaged collector waits for complete repair")
 collector.hp=collector.max_hp
 sim.harvest(collector,1)
 check(collector.harvest_state!="IDLE","Fully repaired collector resumes autonomous work")
 var restored := Simulation.new(sim.db)
 check(restored.restore(sim.snapshot())==OK and restored.entities[core.id].repair and restored.entities[tank_id].order=="service","Repair toggle and vehicle service order survive save/load")
 check(not sim.submit_command({"type":"repair","owner_id":0,"ids":[enemy_id]},0),"Foreign repair command rejected")
 hangar.complete=false
 check(not sim.submit_command({"type":"repair","owner_id":0,"ids":[tank_id]},0),"Unfinished hangar unavailable")
 check(not sim.submit_command({"type":"repair","owner_id":0,"ids":[hangar_id]},0),"Cannot repair incomplete construction")
 hangar.complete=true
 tank.pos=sim.grid.center(sim.grid.nearest_free(sim.grid.cell(hangar.pos+Vector2(-180,-140))))
 for power in sim.buildings(0,"power"): power.complete=false
 check(not sim.submit_command({"type":"repair","owner_id":0,"ids":[tank_id]},0),"No powered hangar: repair route rejected")
 hp=tank.hp; sim.process_building(hangar,1)
 check(tank.hp==hp,"Energy outage suspends vehicle repairs")
 for power in sim.buildings(0,"power",false): power.complete=true
 game.selected=[tank_id]; game.inspected=0; game.update_hud()
 game.details_button.pressed.emit()
 await process_frame
 var details: RichTextLabel = game.overlay.get_child(0).get_node("EntityDetails")
 check(details.text.contains("Panzerung") and details.text.contains("Nachladezeit") and details.text.contains("Solarit"),"Vehicle details explain weapons and repair")
 check(game.paused,"Details pause mission")
 await process_frame
 root.get_texture().get_image().save_png("res://test-output/objectinfo_modern.png")
 game.resume_game(); sim.update_fog(); game.selected=[hangar_id]; game.show_entity_details()
 details=game.overlay.get_child(0).get_node("EntityDetails")
 check(details.text.contains("Energie") and details.text.contains("udereparatur"),"Building details explain energy and repairs")
 game.set_classic(true)
 await process_frame; await process_frame
 root.get_texture().get_image().save_png("res://test-output/objectinfo_classic.png")
 game.resume_game(); game.set_classic(false)
 game.selected=[core.id]; game.update_hud(); game.inspected=enemy_id; game.selected=[]; game.update_hud()
 check(game.repair_button.disabled,"Enemy inspection disables repair")
 game.music.shutdown(); game.queue_free()
 await process_frame
 print("REPAIR: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
