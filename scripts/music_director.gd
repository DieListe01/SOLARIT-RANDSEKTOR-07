extends Node
class_name MusicDirector

var sim: Simulation
var layers: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var state := "BASE_CALM"
var intensity := 0.0
var age := 0.0
var last_music_bar := -1
var pending := "BASE_CALM"
var music_volume := 0.65
var sfx_volume := 0.75
var ended := false
var paused := false
var shot_cooldown := 0.0
var cue_cooldowns: Dictionary = {}
var variants: Dictionary = {}
var cue_indices: Dictionary = {}
var frontend_player: AudioStreamPlayer
var frontend := false
var engine_voice: AudioStreamPlayer
const LAYER_NAMES = ["calm","contact","battle","alarm"]

func _ready() -> void:
	for bus in ["Music","SFX","UI","Voice","Ambience"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_bus)==0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db=-1.0; limiter.threshold_db=-4.0
		AudioServer.add_bus_effect(sfx_bus,limiter)
	frontend_player=AudioStreamPlayer.new()
	frontend_player.bus="Music"
	add_child(frontend_player)
	for name_value in ["select","move","build","complete","ready","alarm","victory","defeat","error","save","shot","explosion","impact","pulse_shot","cannon_shot","siege_shot"]:
		samples[name_value]=load("res://assets/audio/"+name_value+".wav")
	for family_name in CombatEffects.FAMILIES.keys():
		for event_name in ["shot","impact"]:
			var cue_name: String = family_name.to_lower()+"_"+event_name
			samples[cue_name]=load("res://assets/audio/"+cue_name+".wav")
	samples["core_impact"]=load("res://assets/audio/core_impact.wav")
	for cue_name in samples:
		var bank: Array = [samples[cue_name]]
		for variant in [1,2]:
			var path: String = "res://assets/audio/"+str(cue_name)+"_v"+str(variant)+".wav"
			if ResourceLoader.exists(path): bank.append(load(path))
		variants[cue_name]=bank
	for cue_name in ["rotate","repair"]:
		samples[cue_name]=load("res://assets/audio/"+cue_name+".wav")
	for i in 24:
		var voice := AudioStreamPlayer.new()
		voice.bus="SFX"
		add_child(voice)
		voices.append(voice)
	engine_voice=AudioStreamPlayer.new()
	engine_voice.bus="Ambience"
	var motor: AudioStreamWAV = load("res://assets/audio/engine.wav").duplicate()
	motor.loop_mode=AudioStreamWAV.LOOP_FORWARD; motor.loop_begin=0; motor.loop_end=roundi(motor.get_length()*motor.mix_rate)
	engine_voice.stream=motor; engine_voice.volume_db=-70
	add_child(engine_voice)

func start(model: Simulation) -> void:
	engine_voice.stream_paused=false; engine_voice.volume_db=-70; engine_voice.play()
	frontend=false
	frontend_player.stop()
	sim=model
	ended=false
	paused=false
	state="BASE_CALM"; pending=state; age=0; intensity=0; last_music_bar=-1
	for layer in layers: layer.stream_paused=false; layer.stop(); layer.stream=null; layer.queue_free()
	layers.clear()
	for name_value in LAYER_NAMES:
		var layer := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load("res://assets/audio/"+sim.factions[0]+"_"+name_value+".wav").duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		# Imported WAVs may be QOA/ADPCM. Byte count is not a PCM frame count.
		stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
		layer.stream=stream
		layer.bus="Music"
		layer.volume_db=-55 if name_value!="calm" else -7
		add_child(layer)
		layers.append(layer)
	for layer in layers: layer.play(fmod(sim.time,16.0))

func start_frontend(restart: bool = false) -> void:
	engine_voice.stop()
	frontend=true; sim=null; paused=false; state="FIRST_SIGNAL"
	for layer in layers: layer.stream_paused=false; layer.stop()
	for voice in voices: voice.stream_paused=false; voice.stop()
	if frontend_player.stream==null:
		var stream: AudioStreamWAV = load("res://assets/audio/first_signal.wav").duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
		frontend_player.stream=stream
	frontend_player.stream_paused=false
	if restart or not frontend_player.playing:
		frontend_player.volume_db=-38
		frontend_player.play()

func cue(name_value: String, attenuation: float = 1.0) -> void:
	if not samples.has(name_value): return
	if name_value.ends_with("_shot") or name_value.ends_with("_impact"):
		if float(cue_cooldowns.get(name_value,0))>0: return
		cue_cooldowns[name_value]=0.055 if name_value.ends_with("_shot") else 0.035
	for voice in voices:
		if not voice.playing:
			var bank: Array = variants.get(name_value,[samples[name_value]])
			var index := int(cue_indices.get(name_value,0))
			voice.stream=bank[index%bank.size()]
			cue_indices[name_value]=index+1
			voice.pitch_scale=1.0
			voice.volume_db=linear_to_db(maxf(0.001,sfx_volume*attenuation*0.65))
			voice.bus="UI" if name_value in ["select","move","error","save"] else "SFX"
			voice.play()
			return

func set_paused(value: bool) -> void:
	engine_voice.stream_paused=value
	paused=value
	frontend_player.stream_paused=value
	for layer in layers: layer.stream_paused=value
	for voice in voices: voice.stream_paused=value

func shutdown() -> void:
	if is_instance_valid(engine_voice): engine_voice.stream_paused=false; engine_voice.stop()
	frontend_player.stream_paused=false; frontend_player.stop(); frontend_player.stream=null
	for layer in layers: layer.stream_paused=false; layer.stop(); layer.stream=null
	for voice in voices: voice.stream_paused=false; voice.stop(); voice.stream=null

func _exit_tree() -> void:
	shutdown()

func _process(dt: float) -> void:
	shot_cooldown=maxf(0,shot_cooldown-dt)
	for cue_name in cue_cooldowns: cue_cooldowns[cue_name]=maxf(0,float(cue_cooldowns[cue_name])-dt)
	if frontend and not paused:
		frontend_player.volume_db=move_toward(frontend_player.volume_db,linear_to_db(maxf(0.001,music_volume*0.7)),dt*12)
		return
	if sim==null or layers.is_empty() or paused: return
	var movers := 0
	for e in sim.entities.values():
		if not e.building and e.velocity.length()>8 and sim.is_visible(e,sim.view_owner): movers+=1
	engine_voice.volume_db=move_toward(engine_voice.volume_db,linear_to_db(maxf(0.0001,minf(0.20,movers*0.035)*sfx_volume)),dt*35)
	age+=dt
	var visible_enemies := 0
	for e in sim.entities.values():
		if e.owner!=sim.view_owner and sim.is_visible(e,sim.view_owner): visible_enemies+=1
	var desired := clampf(sim.combat_heat+visible_enemies*0.025+(0.4 if sim.base_alarm>0 else 0.0),0,1)
	intensity=move_toward(intensity,desired,dt*0.45)
	var next := "BASE_CALM"
	if sim.result!="": next=sim.result.to_upper()
	elif sim.base_alarm>0: next="BASE_UNDER_ATTACK"
	elif intensity>0.75: next="MAJOR_BATTLE"
	elif intensity>0.4: next="BATTLE"
	elif intensity>0.18: next="SKIRMISH"
	elif visible_enemies>0: next="ENEMY_CONTACT"
	elif not sim.buildings(sim.view_owner,"refinery").is_empty(): next="ECONOMY"
	if next!=pending: pending=next
	# Minimum dwell plus transitions at a 2-second bar boundary.
	var playhead: float = layers[0].get_playback_position()
	var music_bar := floori(playhead/2.0)
	var crossed_bar := music_bar!=last_music_bar
	last_music_bar=music_bar
	if pending!=state and age>2.0 and crossed_bar:
		state=pending; age=0
	if sim.result!="" and not ended:
		ended=true; state=sim.result.to_upper(); cue(sim.result)
	# Strongly differentiated adaptive arrangements. The four synchronized stems are
	# intentionally mixed very differently per tactical state, so contact, economy,
	# battle and base alarm are immediately audible rather than feeling like one loop.
	var gains := [0.72,0.0,0.0,0.0]
	match state:
		"ECONOMY": gains=[0.58,0.20,0.0,0.0]
		"ENEMY_CONTACT": gains=[0.38,0.92,0.0,0.0]
		"SKIRMISH": gains=[0.28,0.62,0.55,0.0]
		"BATTLE": gains=[0.16,0.34,1.0,0.0]
		"MAJOR_BATTLE": gains=[0.10,0.26,1.0,0.70]
		"BASE_UNDER_ATTACK": gains=[0.06,0.18,0.88,1.0]
		"VICTORY", "DEFEAT": gains=[0.22,0.0,0.0,0.0]
	if ended: gains=[0.22,0.0,0.0,0.0]
	for i in layers.size():
		var target_db := linear_to_db(maxf(0.002,float(gains[i])*music_volume))
		layers[i].volume_db=move_toward(layers[i].volume_db,target_db,dt*15)
