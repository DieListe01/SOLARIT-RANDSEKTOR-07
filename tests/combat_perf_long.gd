extends SceneTree

var duration_seconds:=300.0
var checkpoints: Array[float]=[30.0,120.0,300.0]
var game: Control
var rows: Array[String]=[]

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--quick"):
		duration_seconds=35.0
		checkpoints=[30.0]
	call_deferred("run")

func spawn_force(owner: int) -> Array[int]:
	var ids: Array[int]=[]
	for i in 20:
		var side:= -1.0 if owner==0 else 1.0
		var pos: Vector2=game.renderer.camera+Vector2(side*340+(i%5)*22-44,-190+floori(float(i)/5.0)*95)
		var id: int=game.sim.spawn("tank",owner,pos,false)
		if id>0:
			var unit: Dictionary=game.sim.entities[id]
			unit.max_hp=20000.0; unit.hp=20000.0
			ids.append(id)
	return ids

func count_particles(kind: String) -> int:
	var total:=0
	for particle in game.renderer.combat_fx.particles:
		if particle.kind==kind: total+=1
	return total

func send_roaming_orders(friendly: Array[int], enemy: Array[int], reverse: bool) -> void:
	# Refresh the advancing attack order. Opposing target offsets make the two
	# forces keep closing while combat repeatedly reacquires threats.
	var direction:=1.0 if reverse else -1.0
	game.sim.command(friendly,game.renderer.camera+Vector2(direction*24,0),"attack_move")
	game.sim.command(enemy,game.renderer.camera-Vector2(direction*24,0),"attack_move")

func run() -> void:
	rows.append("checkpoint_s,window_fps,window_frame_ms,memory_bytes,roster_units,projectiles,impact_effects,explosions,smoke_particles,total_particles,pool_free,pool_created,pool_reused,pool_peak,wrecks,tracks,draw_calls,primitives")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for _i in 4: await process_frame
	game.skip_intro(); game.start_game(); game.paused=false
	game.renderer.profile_enabled=true; game.sim.ai_timer=999999.0
	var friendly:=spawn_force(0); var enemy:=spawn_force(1)
	game.sim.update_fog(false)
	for y in range(game.sim.grid.height):
		for x in range(game.sim.grid.width):
			var p: Vector2=game.sim.grid.center(Vector2i(x,y))
			if absf(p.x-game.renderer.camera.x)<950 and absf(p.y-game.renderer.camera.y)<720:
				game.sim.fog[0][y*game.sim.grid.width+x]=1
	game.sim.command(friendly,game.renderer.camera,"attack_move")
	game.sim.command(enemy,game.renderer.camera,"attack_move")
	# Let the forces approach, then refresh the attack-move order every 30
	# seconds so later checkpoints remain a live, moving battle rather than idle.
	var next_roam_order:=20.0
	var reverse_roam:=false
	var started:=Time.get_ticks_usec()
	var window_started:=started; var window_frames:=0
	var checkpoint_index:=0
	var peak_particles:=0; var peak_tracks:=0; var peak_wrecks:=0; var peak_projectiles:=0
	while float(Time.get_ticks_usec()-started)/1000000.0<duration_seconds:
		await process_frame
		window_frames+=1
		var elapsed:=float(Time.get_ticks_usec()-started)/1000000.0
		if elapsed>=next_roam_order:
			send_roaming_orders(friendly,enemy,reverse_roam)
			reverse_roam=not reverse_roam
			next_roam_order+=30.0
		peak_particles=maxi(peak_particles,game.renderer.combat_fx.particles.size())
		peak_tracks=maxi(peak_tracks,game.renderer.tracks.size())
		peak_wrecks=maxi(peak_wrecks,game.renderer.combat_fx.ruins.size())
		peak_projectiles=maxi(peak_projectiles,game.sim.projectiles.size())
		if checkpoint_index<checkpoints.size() and elapsed>=checkpoints[checkpoint_index]:
			var window_seconds:=float(Time.get_ticks_usec()-window_started)/1000000.0
			var fps:=float(window_frames)/maxf(0.001,window_seconds)
			var row: Array=["%.0f"%checkpoints[checkpoint_index],"%.2f"%fps,"%.2f"%(1000.0/fps),"%d"%Performance.get_monitor(Performance.MEMORY_STATIC),str(friendly.size()+enemy.size()),str(game.sim.projectiles.size()),str(game.sim.effects.size()+count_particles("hit")+count_particles("impact")),str(count_particles("destroy")),str(count_particles("dust")),str(game.renderer.combat_fx.particles.size()),str(game.renderer.combat_fx.free_particles.size()),str(game.renderer.combat_fx.particle_pool_created),str(game.renderer.combat_fx.particle_pool_reused),str(game.renderer.combat_fx.particle_pool_peak),str(game.renderer.combat_fx.ruins.size()),str(game.renderer.tracks.size()),str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))]
			rows.append(",".join(row))
			print("LONG COMBAT %ds | %.1f FPS | roster %d | projectiles %d | effects %d | pool %d/%d | wrecks %d tracks %d | peak particles %d tracks %d wrecks %d" % [int(checkpoints[checkpoint_index]),fps,friendly.size()+enemy.size(),game.sim.projectiles.size(),game.renderer.combat_fx.particles.size(),game.renderer.combat_fx.particles.size(),game.renderer.combat_fx.free_particles.size(),game.renderer.combat_fx.ruins.size(),game.renderer.tracks.size(),peak_particles,peak_tracks,peak_wrecks])
			window_started=Time.get_ticks_usec(); window_frames=0; checkpoint_index+=1
	var file:=FileAccess.open("res://test-output/combat_perf_long.csv",FileAccess.WRITE)
	file.store_string("\n".join(rows)+"\n"); file.close()
	game.music.shutdown(); game.queue_free(); await process_frame
	quit(0)
