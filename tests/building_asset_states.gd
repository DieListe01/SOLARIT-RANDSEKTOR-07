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
	var factory_pose_keys: Array[String] = []
	for frame in 8:
		game.renderer.elapsed = float(frame) / 2.0
		factory_pose_keys.append(game.renderer.building_cache_key(factory))
	var unique_factory_pose_keys: Dictionary = {}
	for key in factory_pose_keys: unique_factory_pose_keys[key] = true
	assert(unique_factory_pose_keys.size()==4,"Vehicle production cycles through four reusable, distinct mechanism poses")
	var duration:=float(sim.db.units.tank.time)
	var expected_stages: Array[int] = [1,2,3]
	for index in expected_stages.size():
		var progress_ratio: float=[0.25,0.65,0.90][index]
		factory.progress=duration*progress_ratio
		assert(game.renderer._factory_visual_stage(factory)==expected_stages[index],"Factory display distinguishes visual production progress stage %d" % index)
	factory.production_exit_unit=999
	assert(game.renderer._factory_visual_stage(factory)==4,"Factory display distinguishes the release sequence from in-progress assembly")
	factory.erase("production_exit_unit")
	factory.progress=0.0
	factory.complete=false
	var construction_time:=maxf(0.01,float(sim.definition(factory).time))
	factory.build_progress=construction_time*0.20
	var foundation_stage:String=game.renderer.building_cache_key(factory)
	factory.build_progress=construction_time*0.50
	var frame_stage:String=game.renderer.building_cache_key(factory)
	factory.build_progress=construction_time*0.80
	var assembly_stage:String=game.renderer.building_cache_key(factory)
	factory.build_progress=construction_time*0.95
	var commissioning_stage:String=game.renderer.building_cache_key(factory)
	assert(foundation_stage!=frame_stage and frame_stage!=assembly_stage and assembly_stage!=commissioning_stage,"The four authored 3D construction phases must use distinct cached configurations")
	factory.complete=true
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
	print("Building cache-state audit: 3D construction phases, refinery unloading, vehicle production, rotating radar, turret aim and repair activity select authored poses")
	game.music.shutdown(); game.queue_free(); await process_frame
	quit()
