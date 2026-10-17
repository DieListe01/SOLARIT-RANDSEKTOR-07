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
	var animation_family_zero: String=game.renderer.building_cache_family_key(factory_pose_keys[0])
	var animation_family_one: String=game.renderer.building_cache_family_key(factory_pose_keys[1])
	assert(animation_family_zero==animation_family_one,"Factory animation frames share only their semantically compatible fallback family")
	var animation_key_parts := factory_pose_keys[1].split("|",false)
	var wrong_faction_parts := animation_key_parts.duplicate()
	wrong_faction_parts[2]="drift"
	var wrong_orientation_parts := animation_key_parts.duplicate()
	wrong_orientation_parts[3]="1"
	var other_activity_parts := animation_key_parts.duplicate()
	other_activity_parts[5]="0"
	var wrong_construction_parts := animation_key_parts.duplicate()
	wrong_construction_parts[9]="2"
	assert(game.renderer.building_cache_family_key("|".join(wrong_faction_parts))!=animation_family_zero,"Building animation fallback must never cross factions")
	assert(game.renderer.building_cache_family_key("|".join(wrong_orientation_parts))!=animation_family_zero,"Building animation fallback must never cross orientation")
	assert(game.renderer.building_cache_family_key("|".join(other_activity_parts))==animation_family_zero,"An idle factory pose is a safe base-structure fallback while production animation warms")
	assert(game.renderer.building_cache_family_key("|".join(wrong_construction_parts))!=animation_family_zero,"Building animation fallback must never cross construction phase")
	var marker_image:=Image.create(1,1,false,Image.FORMAT_RGBA8)
	marker_image.fill(Color.WHITE)
	var previous_factory_pose:=ImageTexture.create_from_image(marker_image)
	game.renderer.building_texture_cache[factory_pose_keys[0]]=previous_factory_pose
	game.renderer.building_texture_metadata[factory_pose_keys[0]]={"cache_key":factory_pose_keys[0],"kind":"factory","owner":0,"faction":"forge","actual_model_source":"procedural:forge:factory","texture_instance_id":previous_factory_pose.get_instance_id()}
	game.renderer.building_cache_fallback_keys[animation_family_zero]=factory_pose_keys[0]
	assert(game.renderer.building_cache_fallback_texture(factory_pose_keys[1])==previous_factory_pose,"An animated factory cache miss must retain the last valid 3D pose")
	assert(game.renderer.building_cache_fallback_texture("|".join(wrong_faction_parts))==null,"A cache miss without a semantically valid prior pose may use first-render fallback only")
	assert(game.renderer._building_cache_entry_valid(factory_pose_keys[0],previous_factory_pose,"factory",0,"forge"),"Cached building textures retain the identity they were actually rendered from")
	game.renderer.building_texture_metadata[factory_pose_keys[0]]["cache_key"]=factory_pose_keys[1]
	assert(not game.renderer._building_cache_entry_valid(factory_pose_keys[0],previous_factory_pose,"factory",0,"forge"),"A texture stored under a mismatched cache identity is rejected")
	game.renderer.building_texture_metadata[factory_pose_keys[0]]["cache_key"]=factory_pose_keys[0]
	game.renderer.building_texture_metadata[factory_pose_keys[0]]["actual_model_source"]="res://assets/models/buildings/harvester.glb"
	assert(not game.renderer._building_cache_entry_valid(factory_pose_keys[0],previous_factory_pose,"factory",0,"forge"),"A texture recorded from an unrelated model source is rejected")
	game.renderer.building_texture_metadata[factory_pose_keys[0]]["actual_model_source"]="procedural:forge:factory"
	var snapshot: Dictionary=factory.duplicate(true)
	snapshot.unloading=false
	snapshot.building_animation_frame=1
	snapshot.construction_stage=5
	assert(game.renderer._building_snapshot_cache_key(snapshot,"forge")==factory_pose_keys[1],"Queued building snapshots reconstruct the exact requested cache identity")
	assert(game.renderer._building_snapshot_cache_key(snapshot,"drift")!=factory_pose_keys[1],"Queued building snapshots cannot be rendered under another faction's cache key")
	for frame in 600:
		game.renderer.elapsed=float(frame)/60.0
		var phase: int=mini(frame/120,3)
		if phase==3:
			factory.queue.clear()
			factory.production_exit_unit=999
		else:
			factory.erase("production_exit_unit")
			factory.queue=[{"kind":"tank","paid":0}]
			factory.progress=float(sim.db.units.tank.time)*[0.10,0.55,0.86,0.10][phase]
		var requested_pose: String=game.renderer.building_cache_key(factory)
		var retained_pose: Texture2D=game.renderer.building_cache_fallback_texture(requested_pose)
		assert(retained_pose==previous_factory_pose and game.renderer.building_cache_family_key(requested_pose)==animation_family_zero,"600 consecutive factory render samples retain a same-building 3D pose through production, release and next-queue transitions")
	var spare_image:=Image.create(1,1,false,Image.FORMAT_RGBA8)
	spare_image.fill(Color("45d8c5"))
	var spare_factory_pose:=ImageTexture.create_from_image(spare_image)
	game.renderer.building_texture_cache[factory_pose_keys[2]]=spare_factory_pose
	game.renderer.building_texture_times[factory_pose_keys[2]]=game.renderer.elapsed+1.0
	game.renderer.building_texture_metadata[factory_pose_keys[2]]={"cache_key":factory_pose_keys[2],"kind":"factory","owner":0,"faction":"forge","actual_model_source":"procedural:forge:factory","texture_instance_id":spare_factory_pose.get_instance_id()}
	game.renderer.building_cache_fallback_keys[animation_family_zero]=factory_pose_keys[0]
	game.renderer._evict_building_cache_entry(factory_pose_keys[0])
	assert(game.renderer.building_cache_fallback_texture(factory_pose_keys[1])==spare_factory_pose,"Evicting the preferred factory pose preserves a compatible cached animation pose instead of falling back to the procedural renderer")
	factory.queue=[{"kind":"tank","paid":0}]
	factory.erase("production_exit_unit")
	game.renderer.elapsed=3.5
	game.renderer.building_visual_diagnostics_enabled=true
	game.renderer.record_building_visual_event(factory,factory_pose_keys[1],factory_pose_keys[0],"same_family_cached_fallback")
	var visual_event: Dictionary=game.renderer.building_visual_event_log.back()
	assert(visual_event.get("frame",-1)>=0 and visual_event.get("entity_id",0)==factory_id and visual_event.get("faction","")=="forge" and visual_event.get("cache_key","")==factory_pose_keys[1] and visual_event.get("chosen_cache_key","")==factory_pose_keys[0] and visual_event.get("fallback_reason","")=="same_family_cached_fallback","Building visual diagnostics record frame, identity, state key, selected pose and fallback reason")
	game.renderer.building_visual_diagnostics_enabled=false
	game.renderer.building_visual_event_log.clear()
	game.renderer.building_texture_cache.clear()
	game.renderer.building_texture_times.clear()
	game.renderer.building_texture_metadata.clear()
	game.renderer.building_cache_fallback_keys.clear()
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
	var foundation_image:=Image.create(1,1,false,Image.FORMAT_RGBA8)
	foundation_image.fill(Color("45d8c5"))
	var foundation_texture:=ImageTexture.create_from_image(foundation_image)
	game.renderer.building_texture_cache[foundation_stage]=foundation_texture
	game.renderer.building_texture_metadata[foundation_stage]={"cache_key":foundation_stage,"kind":"factory","owner":0,"faction":"forge","actual_model_source":"procedural:forge:factory","texture_instance_id":foundation_texture.get_instance_id()}
	game.renderer.building_entity_last_pose_keys[factory_id]=foundation_stage
	assert(game.renderer.building_entity_fallback_texture(factory,frame_stage)==foundation_texture,"A construction-phase cache miss retains this exact building's last valid pose until the new phase is ready")
	var wrong_owner_factory: Dictionary=factory.duplicate(true)
	wrong_owner_factory.owner=1
	assert(game.renderer.building_entity_fallback_texture(wrong_owner_factory,frame_stage)==null,"A previous-entity fallback cannot cross owner or faction identity")
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
