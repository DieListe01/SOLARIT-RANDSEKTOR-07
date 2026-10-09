extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.start_game(); game.paused=true
	game.sim.ai_timer=99999.0; game.sim.ai_production_timer=99999.0
	var sim: Simulation=game.sim
	var origin:=Vector2(32,38)*32.0
	var refinery_id:=sim.spawn("refinery",0,origin,true)
	var harvester_id:=sim.spawn("harvester",0,origin+Vector2(24,18),false)
	var refinery: Dictionary=sim.entities[refinery_id]
	var harvester: Dictionary=sim.entities[harvester_id]
	harvester.harvest_state="RETURN_TO_BASE"
	var idle_key:String=game.renderer.building_cache_key(refinery)
	harvester.harvest_state="UNLOAD"
	assert(game.renderer.building_cache_key(refinery)!=idle_key,"The refinery's cache pose must change when a collector docks to unload")
	var factory_id:=sim.spawn("factory",0,origin+Vector2(180,0),true)
	var factory: Dictionary=sim.entities[factory_id]
	var inactive_factory:String=game.renderer.building_cache_key(factory)
	factory.queue.append({"kind":"tank"})
	assert(game.renderer.building_cache_key(factory)!=inactive_factory,"An active vehicle-production queue must select its animated assembly pose")
	var radar_id:=sim.spawn("radar",0,origin+Vector2(360,0),true)
	var radar: Dictionary=sim.entities[radar_id]
	game.renderer.elapsed=0.0
	var radar_frame_zero:String=game.renderer.building_cache_key(radar)
	game.renderer.elapsed=1.0
	assert(game.renderer.building_cache_key(radar)!=radar_frame_zero,"The sensor dish must rotate through reusable cache frames")
	var tower_id:=sim.spawn("tower",0,origin+Vector2(540,0),true)
	var tower: Dictionary=sim.entities[tower_id]
	var tower_north:String=game.renderer.building_cache_key(tower)
	tower.turret=PI*.5
	assert(game.renderer.building_cache_key(tower)!=tower_north,"The turret's independent aim must select the correct cached pose")
	var repair_id:=sim.spawn("repair",0,origin+Vector2(720,0),true)
	var repair: Dictionary=sim.entities[repair_id]
	var repair_idle:String=game.renderer.building_cache_key(repair)
	repair.repair=true
	assert(game.renderer.building_cache_key(repair)!=repair_idle,"An operating repair hangar must select an active service pose")
	print("Building cache-state audit: refinery unloading, vehicle production, rotating radar, turret aim and repair activity select authored poses")
	game.music.shutdown(); game.queue_free(); await process_frame
	quit()
