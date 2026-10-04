extends SceneTree
func _initialize() -> void: call_deferred("run")
func sample(label_value: String) -> void:
 for i in 12: await process_frame
 var durations: Array[float] = []
 var last := Time.get_ticks_usec()
 for i in 90:
  await process_frame
  var now := Time.get_ticks_usec()
  durations.append((now-last)/1000.0); last=now
 durations.sort()
 var total := 0.0
 for value in durations: total+=value
 print("ASHLINE RENDER %s: average %.2f ms; p95 %.2f ms; %.1f FPS; draw calls %d" % [label_value,total/90.0,durations[85],90000.0/total,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game); await process_frame
 game.skip_intro(); game.start_game(); game.set_process(false)
 var sim: Simulation = game.sim; sim.ai_timer=99999
 for i in 40: sim.spawn("tank",0,Vector2(300+(i%8)*48,1250+floori(i/8.0)*48),false)
 sim.fog[0].fill(1); sim.explored[0].fill(1)
 game.renderer.camera=Vector2(700,1400); game.renderer.zoom=1.0
 await sample("40 idle vehicles")
 game.renderer.heat_layer.visible=false
 await sample("40 idle vehicles without heat effect")
 game.music.shutdown(); quit()
