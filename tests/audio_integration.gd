extends SceneTree
var failures: Array[String] = []
var checks := 0
var director: MusicDirector

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error("AUDIO FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func wait_for_state(expected: String) -> void:
	var deadline := Time.get_ticks_msec()+8500
	while director.state!=expected and Time.get_ticks_msec()<deadline: await process_frame

func run() -> void:
	director=MusicDirector.new()
	root.add_child(director)
	await process_frame
	var sim := Simulation.new(Catalog.new())
	director.start(sim)
	await create_timer(0.15).timeout
	check(director.layers.size()==4,"Four original music stems")
	var head: float = director.layers[0].get_playback_position()
	for layer in director.layers:
		check(layer.playing and absf(layer.get_playback_position()-head)<0.05,"Layer transport synchronized")
		check(layer.stream.loop_end>300000,"Loop covers the full 16-second pattern")
	var core: Dictionary = sim.buildings(0,"core")[0]
	sim.spawn("tank",1,core.pos+Vector2(100,0),false)
	sim.update_fog()
	await wait_for_state("ENEMY_CONTACT")
	check(director.state=="ENEMY_CONTACT","Contact state enters on a musical bar boundary")
	sim.combat_heat=1.0; sim.base_alarm=8.0
	await wait_for_state("BASE_UNDER_ATTACK")
	check(director.state=="BASE_UNDER_ATTACK","Base attack enables intense arrangement")
	var mix_deadline := Time.get_ticks_msec()+3500
	while director.layers[3].volume_db<=-20 and Time.get_ticks_msec()<mix_deadline: await process_frame
	check(director.layers[3].volume_db>-20,"Alarm stem audible in target arrangement")
	director.set_paused(true)
	var paused_head: float = director.layers[0].get_playback_position()
	var paused_intensity: float = director.intensity
	await create_timer(0.25).timeout
	check(absf(director.layers[0].get_playback_position()-paused_head)<0.05,"Pause freezes music playback")
	check(director.intensity==paused_intensity,"Pause freezes music decisions")
	director.set_paused(false)
	sim.result="victory"
	await process_frame
	await process_frame
	check(director.state=="VICTORY" and director.ended,"Victory overrides combat state")
	check(director.voices.any(func(v):return v.playing),"Victory jingle plays")
	director.shutdown()
	director.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("AUDIO INTEGRATION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
