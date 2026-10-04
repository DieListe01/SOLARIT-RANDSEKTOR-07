extends SceneTree

const FRAMES := 240
var game: Control
var output_rows: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int) -> void:
	for _i in frames: await process_frame

func clear_scene() -> void:
	game.paused=true
	game.renderer.visual_paused=true
	game.sim.ai_timer=999999.0
	var remove_ids: Array[int]=[]
	for id in game.sim.entities:
		if not game.sim.entities[id].building: remove_ids.append(id)
	for id in remove_ids: game.sim.entities.erase(id)
	game.sim.projectiles.clear(); game.sim.effects.clear()
	game.renderer.combat_fx.reset()
	game.renderer.tracks.clear(); game.renderer.visual_bursts.clear()
	game.renderer.previous_positions.clear(); game.renderer.previous_speeds.clear()
	game.renderer.track_timer=1.0
	game.renderer.camera=Vector2(33*32,42*32)
	game.renderer.queue_redraw()

func spawn_vehicles(count: int, owner: int=0) -> Array[int]:
	var ids: Array[int]=[]
	for i in count:
		var side_offset:=(-260.0 if owner==0 else 260.0) if owner in [0,1] else 0.0
		var pos: Vector2=game.renderer.camera+Vector2(side_offset-240+(i%8)*68,-125+floori(float(i)/8.0)*62)
		ids.append(game.sim.spawn("tank",owner,pos,false))
	# Reveal the controlled test arena without changing the simulation's unit AI.
	var center: Vector2i=game.sim.grid.cell(game.renderer.camera)
	for y in range(maxi(0,center.y-18),mini(game.sim.grid.height,center.y+19)):
		for x in range(maxi(0,center.x-24),mini(game.sim.grid.width,center.x+25)):
			game.sim.fog[0][y*game.sim.grid.width+x]=1
	game.renderer.queue_redraw()
	return ids

func add_projectiles(count: int) -> void:
	for i in count:
		var p: Vector2=game.renderer.camera+Vector2(-400+(i%10)*78,-90+floori(float(i)/10.0)*54)
		game.sim.projectiles.append({"pos":p,"last":p+Vector2(260,80),"target":i,"owner":0,"weapon":"cannon","life":5.0})

func add_impacts(count: int) -> void:
	for i in count:
		var p: Vector2=game.renderer.camera+Vector2(-390+(i%8)*100,-110+floori(float(i)/8.0)*88)
		game.sim.effects.append({"pos":p,"life":0.2,"max_life":0.35,"radius":18.0,"event_backed":false})

func add_wrecks_and_tracks(track_count: int=900) -> void:
	for i in 36:
		var p: Vector2=game.renderer.camera+Vector2(-420+(i%9)*96,-180+floori(float(i)/9.0)*92)
		game.renderer.combat_fx.emit_effect("destroy",{"pos":p,"angle":float(i)*0.3,"building":false,"kind":"tank"})
	for i in track_count:
		var p: Vector2=game.renderer.camera+Vector2(-430+(i%90)*10,-220+floori(float(i)/90.0)*35)
		game.renderer.tracks.append({"a":p,"b":p+Vector2(7,2),"angle":0.0,"life":40.0})

func record(label: String, running: bool, setup: Callable) -> void:
	await clear_scene()
	game.renderer.movement_vfx_enabled=label!="B_moving_no_vfx"
	var ids: Array[int]=setup.call()
	await settle(75)
	if running:
		game.paused=false
		game.renderer.visual_paused=false
	var start:=Time.get_ticks_usec()
	var draws:=0.0; var primitives:=0.0
	var visible_sum:=0.0; var sim_sum:=0.0
	var terrain:=0.0; var ground:=0.0; var buildings:=0.0; var vehicles:=0.0; var ui:=0.0; var total_render:=0.0
	var tracks:=0.0; var projectiles:=0.0; var impacts:=0.0; var explosions:=0.0; var smoke:=0.0; var fog:=0.0
	var peak_projectiles:=0; var peak_impacts:=0; var peak_explosions:=0; var peak_smoke:=0; var peak_wrecks:=0; var peak_tracks:=0
	var cache_hits:=0.0; var cache_misses:=0.0; var solarit_fields:=0.0; var terrain_chunks:=0.0
	var peak_combat_particles:=0; var peak_active_smoke:=0; var peak_active_explosions:=0; var peak_active_impacts:=0
	for _i in FRAMES:
		await process_frame
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		visible_sum+=game.renderer.visible_mobile_count
		sim_sum+=game.renderer.profile_sim_ms
		terrain+=game.renderer.profile_terrain_ms; ground+=game.renderer.profile_wrecks_ms
		buildings+=game.renderer.profile_buildings_ms; vehicles+=game.renderer.profile_vehicles_ms
		ui+=game.renderer.profile_ui_ms; total_render+=game.renderer.profile_total_ms
		tracks+=game.renderer.profile_tracks_ms; projectiles+=game.renderer.profile_projectiles_ms
		impacts+=game.renderer.profile_impacts_ms; explosions+=game.renderer.profile_explosions_ms
		smoke+=game.renderer.profile_smoke_ms; fog+=game.renderer.profile_fog_ms
		peak_projectiles=maxi(peak_projectiles,game.sim.projectiles.size())
		peak_impacts=maxi(peak_impacts,game.sim.effects.size())
		var current_smoke:=0; var current_explosions:=0; var current_impacts: int=game.sim.effects.size()
		for particle in game.renderer.combat_fx.particles:
			if particle.kind=="destroy": current_explosions+=1
			elif particle.kind=="dust": current_smoke+=1
			elif particle.kind in ["hit","impact"]: current_impacts+=1
		peak_combat_particles=maxi(peak_combat_particles,game.renderer.combat_fx.particles.size())
		peak_active_smoke=maxi(peak_active_smoke,current_smoke)
		peak_active_explosions=maxi(peak_active_explosions,current_explosions)
		peak_active_impacts=maxi(peak_active_impacts,current_impacts)
		peak_wrecks=maxi(peak_wrecks,game.renderer.combat_fx.ruins.size())
		peak_tracks=maxi(peak_tracks,game.renderer.tracks.size())
		cache_hits+=game.renderer.vehicle_cache_hits; cache_misses+=game.renderer.vehicle_cache_misses
		solarit_fields+=game.renderer.profile_solarit_count; terrain_chunks+=game.renderer.visible_terrain_chunk_count
	game.paused=true; game.renderer.visual_paused=true
	game.renderer.movement_vfx_enabled=true
	var seconds:=float(Time.get_ticks_usec()-start)/1000000.0
	var fps:=float(FRAMES)/maxf(0.001,seconds)
	peak_explosions=peak_active_explosions; peak_smoke=peak_active_smoke; peak_impacts=maxi(peak_impacts,peak_active_impacts)
	var row: Array=[label,str(ids.size()),"%.2f"%fps,"%.2f"%(1000.0/fps),"%d"%roundi(draws/FRAMES),"%d"%roundi(primitives/FRAMES),"%d"%roundi(visible_sum/FRAMES),str(peak_projectiles),str(peak_impacts),str(peak_explosions),str(peak_smoke),str(peak_wrecks),str(peak_tracks),"%d"%peak_combat_particles,"%d"%roundi(solarit_fields/FRAMES),"%d"%roundi(terrain_chunks/FRAMES),"%.3f"%(terrain/FRAMES),"%.3f"%(ground/FRAMES),"%.3f"%(buildings/FRAMES),"%.3f"%(vehicles/FRAMES),"%.3f"%(tracks/FRAMES),"%.3f"%(projectiles/FRAMES),"%.3f"%(impacts/FRAMES),"%.3f"%(explosions/FRAMES),"%.3f"%(smoke/FRAMES),"%.3f"%(fog/FRAMES),"%.3f"%(ui/FRAMES),"%.3f"%(total_render/FRAMES),"%.3f"%(sim_sum/FRAMES),"%d"%roundi(cache_hits/FRAMES),"%d"%roundi(cache_misses/FRAMES)]
	output_rows.append(",".join(row))
	print("COMBAT MATRIX %s | %.1f FPS %.2f ms | draws %d primitives %d | units %d peaks: shots %d impacts %d explosions %d smoke %d particles %d wrecks %d tracks %d | renderer %.2f ms | sim %.2f ms" % [label,fps,1000.0/fps,roundi(draws/FRAMES),roundi(primitives/FRAMES),ids.size(),peak_projectiles,peak_impacts,peak_explosions,peak_smoke,peak_combat_particles,peak_wrecks,peak_tracks,(terrain+ground+buildings+vehicles+tracks+projectiles+impacts+explosions+fog)/FRAMES,sim_sum/FRAMES])

func stationary_setup() -> Array[int]:
	return spawn_vehicles(40)

func moving_setup() -> Array[int]:
	var ids:=spawn_vehicles(40)
	game.sim.command(ids,game.renderer.camera+Vector2(520,180),"move")
	return ids

func projectile_setup() -> Array[int]:
	var ids:=spawn_vehicles(40); add_projectiles(40); return ids

func impact_setup() -> Array[int]:
	var ids:=spawn_vehicles(40); add_impacts(32); return ids

func explosion_setup() -> Array[int]:
	var ids:=spawn_vehicles(40); add_wrecks_and_tracks(0); return ids

func battle_setup(include_debris: bool) -> Array[int]:
	var ids:=spawn_vehicles(20,0)
	var enemies:=spawn_vehicles(20,1)
	ids.append_array(enemies)
	game.sim.update_fog(false)
	# Keep the staged opposing force visible to the player so the test remains repeatable.
	for y in game.sim.grid.height:
		for x in game.sim.grid.width:
			var p: Vector2=game.sim.grid.center(Vector2i(x,y))
			if absf(p.x-game.renderer.camera.x)<900 and absf(p.y-game.renderer.camera.y)<700:
				game.sim.fog[0][y*game.sim.grid.width+x]=1
	var left: Array[int]=ids.slice(0,20); var right: Array[int]=ids.slice(20,40)
	game.sim.command(left,game.renderer.camera,"attack_move")
	game.sim.command(right,game.renderer.camera,"attack_move")
	if include_debris: add_wrecks_and_tracks()
	return ids

func run() -> void:
	output_rows.append("scenario,vehicles,average_fps,frame_ms,draw_calls,primitives,visible_vehicles,peak_projectiles,peak_impacts,peak_explosions,active_smoke,peak_wrecks,peak_tracks,peak_combat_particles,visible_solarit_fields,visible_terrain_chunks,terrain_ms,wreck_ms,buildings_ms,vehicles_ms,tracks_ms,projectiles_ms,impacts_ms,explosions_ms,smoke_ms,fog_ms,ui_update_ms,total_render_ms,sim_ms,avg_vehicle_cache_hits,avg_vehicle_cache_misses")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(4)
	game.skip_intro(); game.start_game(); game.paused=true; game.renderer.visual_paused=true
	game.renderer.profile_enabled=true; game.sim.ai_timer=999999.0
	await record("A_stationary",false,Callable(self,"stationary_setup"))
	await record("B_moving_no_vfx",true,Callable(self,"moving_setup"))
	await record("C_projectiles",false,Callable(self,"projectile_setup"))
	await record("D_impacts",false,Callable(self,"impact_setup"))
	await record("E_explosions_wrecks",false,Callable(self,"explosion_setup"))
	await record("F_moving_battle",true,Callable(self,"battle_setup").bind(false))
	await record("G_battle_wrecks_tracks",true,Callable(self,"battle_setup").bind(true))
	var file:=FileAccess.open("res://test-output/combat_perf_matrix.csv",FileAccess.WRITE)
	file.store_string("\n".join(output_rows)+"\n"); file.close()
	game.music.shutdown(); game.queue_free(); await process_frame
	quit(0)
