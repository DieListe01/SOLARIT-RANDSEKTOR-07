extends Node
class_name MusicDirector

const VoiceDirectorScript := preload("res://scripts/voice_director.gd")

var sim: Simulation
var layers: Array[AudioStreamPlayer] = []
var stem_players: Array[AudioStreamPlayer] = []
var stem_names: Array[String] = []
var adaptive_stem_set: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var voice_players: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var music_catalog: Dictionary = {}
var selected_tracks: Array[Dictionary] = []
var track_history: Dictionary = {}
var music_rng := RandomNumberGenerator.new()
var faction_id := "forge"
var state := "BASE_CALM"
var intensity := 0.0
var age := 0.0
var last_music_bar := -1
var active_arrangement_index := 0
var previous_arrangement_index := 0
var arrangement_crossfade_elapsed := 1.25
const ARRANGEMENT_CROSSFADE_SECONDS := 1.25
var pending := "BASE_CALM"
var music_volume := 0.65
var sfx_volume := 0.75
var ended := false
var paused := false
var shot_cooldown := 0.0
var tactical_scan_timer := 0.0
var cached_movers := 0
var cached_visible_enemies := 0
var cue_cooldowns: Dictionary = {}
var variants: Dictionary = {}
var cue_indices: Dictionary = {}
var frontend_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer
var frontend := false
var engine_voice: AudioStreamPlayer
var audio_listener: AudioListener2D
var harvest_loop: AudioStreamPlayer2D
var voice_duck := 1.0
var speech: Variant
const LAYER_NAMES = ["calm_a","calm_b","contact","battle_low","battle_high","critical"]
const CATALOG_PATH := "res://assets/audio/music_catalog.json"

func _ready() -> void:
	music_rng.randomize()
	var parsed_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed_catalog is Dictionary:
		music_catalog = parsed_catalog
	else:
		push_error("Music catalog could not be loaded: "+CATALOG_PATH)
	for bus in ["Music","SFX","UI","Voice","Ambience","Vehicles","Combat"]:
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
	stinger_player=AudioStreamPlayer.new()
	stinger_player.bus="Music"
	stinger_player.volume_db=-3.0
	add_child(stinger_player)
	speech=VoiceDirectorScript.new()
	speech.name="VoiceDirector"
	add_child(speech)
	for name_value in ["select","move","build","complete","ready","alarm","victory","defeat","error","save","shot","explosion","impact","pulse_shot","cannon_shot","siege_shot"]:
		samples[name_value]=load("res://assets/audio/"+name_value+".wav")
	samples["harvest_start_demo"]=load("res://assets/audio/sfx/harvest_start_demo.ogg")
	samples["harvest_collect_demo"]=load("res://assets/audio/sfx/harvest_collect_demo.ogg")
	samples["harvest_unload_demo"]=load("res://assets/audio/sfx/harvest_unload_demo.ogg")
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
	_load_sfx_candidates()
	for i in 24:
		var voice := AudioStreamPlayer2D.new()
		voice.bus="SFX"
		voice.attenuation=0.0
		voice.max_distance=1800.0
		voice.panning_strength=0.0
		add_child(voice)
		voices.append(voice)
	audio_listener=AudioListener2D.new()
	add_child(audio_listener)
	audio_listener.make_current()
	for i in 2:
		var voice_player := AudioStreamPlayer.new()
		voice_player.bus="Voice"
		add_child(voice_player)
		voice_players.append(voice_player)
	engine_voice=AudioStreamPlayer.new()
	engine_voice.bus="Ambience"
	var motor: AudioStream=samples.get("engine",load("res://assets/audio/engine.wav")).duplicate()
	if motor is AudioStreamWAV:
		var motor_wav:=motor as AudioStreamWAV
		motor_wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; motor_wav.loop_begin=0; motor_wav.loop_end=roundi(motor_wav.get_length()*motor_wav.mix_rate)
	elif motor is AudioStreamOggVorbis:
		(motor as AudioStreamOggVorbis).loop=true
	engine_voice.stream=motor; engine_voice.volume_db=-70
	add_child(engine_voice)
	harvest_loop=AudioStreamPlayer2D.new()
	harvest_loop.bus="Vehicles"
	harvest_loop.attenuation=0.0
	harvest_loop.max_distance=1800.0
	harvest_loop.panning_strength=0.0
	var harvest_source: AudioStream=samples.get("harvester_work_demo",load("res://assets/audio/sfx/harvester_work_demo.ogg")) as AudioStream
	if harvest_source is AudioStreamOggVorbis:
		var harvest_stream:=harvest_source.duplicate() as AudioStreamOggVorbis
		harvest_stream.loop=true
		harvest_stream.loop_offset=0.0
		harvest_loop.stream=harvest_stream
	harvest_loop.volume_db=-70
	add_child(harvest_loop)

func _load_sfx_candidates() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sfx_catalog.json"))
	if not parsed is Dictionary: return
	for cue_name in parsed.get("cues",{}):
		var bank: Array=[]
		for clip in parsed.cues[cue_name]:
			var path:=str(clip.get("path",""))
			if not path.is_empty() and ResourceLoader.exists(path): bank.append(load(path))
		if not bank.is_empty():
			samples[str(cue_name)]=bank[0]
			variants[str(cue_name)]=bank
			if str(cue_name)=="impact":
				for family_name in CombatEffects.FAMILIES.keys():
					var family_cue:=str(family_name).to_lower()+"_impact"
					samples[family_cue]=bank[0]; variants[family_cue]=bank
			elif str(cue_name)=="pulse_shot":
				samples["energy_shot"]=bank[0]; variants["energy_shot"]=bank
			elif str(cue_name)=="cannon_shot":
				samples["ballistic_heavy_shot"]=bank[0]; variants["ballistic_heavy_shot"]=bank

func start(model: Simulation) -> void:
	if speech!=null: speech.stop()
	engine_voice.stream_paused=false; engine_voice.volume_db=-70; engine_voice.play()
	harvest_loop.stream_paused=false; harvest_loop.stop()
	frontend=false
	frontend_player.stop()
	sim=model
	ended=false
	paused=false
	state="BASE_CALM"; pending=state; age=0; intensity=0; last_music_bar=-1
	set_meta("alert_stinger_played",false)
	active_arrangement_index=0; previous_arrangement_index=0
	arrangement_crossfade_elapsed=ARRANGEMENT_CROSSFADE_SECONDS
	var music_owner:=clampi(int(sim.get("view_owner")),0,maxi(0,sim.factions.size()-1))
	faction_id=str(sim.factions[music_owner]) if not sim.factions.is_empty() else "forge"
	if not music_catalog.get("factions",{}).has(faction_id): faction_id="forge"
	tactical_scan_timer=0.0; cached_movers=0; cached_visible_enemies=0
	for layer in layers: layer.stream_paused=false; layer.stop(); layer.stream=null; layer.queue_free()
	layers.clear()
	for stem_player in stem_players: stem_player.stream_paused=false; stem_player.stop(); stem_player.stream=null; stem_player.queue_free()
	stem_players.clear()
	stem_names.clear()
	adaptive_stem_set.clear()
	selected_tracks.clear()
	var faction_data: Dictionary=music_catalog.get("factions",{}).get(faction_id,{})
	var stem_set: Dictionary=faction_data.get("adaptive_stems",{})
	if not stem_set.is_empty() and _start_adaptive_stems(stem_set,sim.time):
		selected_tracks.append(stem_set)
	else:
		for name_value in LAYER_NAMES:
			var layer := AudioStreamPlayer.new()
			var track := _choose_track(faction_id,name_value)
			var stream := _load_track_stream(track)
			if stream == null:
				push_error("Music track missing: "+str(track.get("path","")))
				continue
			layer.stream=stream
			layer.bus="Music"
			layer.volume_db=-60 if name_value!="calm" else -7
			add_child(layer)
			layers.append(layer)
			selected_tracks.append(track)
		for i in layers.size():
			var duration: float = layers[i].stream.get_length()
			layers[i].play(fposmod(sim.time,duration) if duration>0.0 else 0.0)
	last_music_bar=-1
	play_global_stinger("mission_start")

func play_global_stinger(stinger_name: String) -> bool:
	var spec: Dictionary=music_catalog.get("global_stingers",{}).get(stinger_name,{})
	if spec.is_empty(): return false
	var stream:=_load_track_stream(spec)
	if stream==null: return false
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop=false
	stinger_player.stream=stream
	stinger_player.volume_linear=clampf(music_volume*0.85,0.0,1.0)
	stinger_player.play()
	return true

func _start_adaptive_stems(stem_set: Dictionary, start_time: float) -> bool:
	var stem_catalog: Dictionary=stem_set.get("layers",{})
	if stem_catalog.is_empty() or not stem_catalog.has("atmosphere"):
		return false
	var ordered_names: Array[String]=["atmosphere","pulse","bass","rhythm","percussion","motif","combat","critical"]
	var prepared: Array[Dictionary]=[]
	for stem_name in ordered_names:
		if not stem_catalog.has(stem_name): continue
		var spec: Dictionary=stem_catalog[stem_name]
		var stream:=_load_track_stream({
			"path":str(spec.get("path","")),
			"loop_start_seconds":float(stem_set.get("loop_start_seconds",0.0)),
			"loop_end_seconds":float(stem_set.get("loop_end_seconds",0.0))
		})
		if stream==null:
			push_warning("Adaptive music stem unavailable; retaining full-mix fallback: "+stem_name)
			return false
		prepared.append({"name":stem_name,"stream":stream,"gain":clampf(float(spec.get("gain",1.0)),0.0,2.0)})
	if prepared.is_empty(): return false
	adaptive_stem_set=stem_set.duplicate(true)
	for item in prepared:
		var stem_player:=AudioStreamPlayer.new()
		stem_player.stream=item.stream
		stem_player.bus="Music"
		stem_player.volume_db=-70.0
		add_child(stem_player)
		stem_players.append(stem_player)
		stem_names.append(str(item.name))
		var duration: float=stem_player.stream.get_length()
		stem_player.play(fposmod(start_time,duration) if duration>0.0 else 0.0)
	_update_stem_mix(0.0)
	return true

func _choose_track(for_faction: String, for_state: String) -> Dictionary:
	var faction: Dictionary = music_catalog.get("factions",{}).get(for_faction,{})
	var choices: Array = faction.get("tracks",{}).get(for_state,[])
	if choices.is_empty(): return {}
	var history_key := for_faction+"/"+for_state
	var last_id := str(track_history.get(history_key,""))
	var candidates: Array = []
	for choice in choices:
		if choices.size()==1 or str(choice.get("id",""))!=last_id: candidates.append(choice)
	if candidates.is_empty(): candidates=choices
	var total_weight := 0.0
	for candidate in candidates: total_weight+=maxf(0.001,float(candidate.get("weight",1.0)))
	var pick := music_rng.randf()*total_weight
	var selected: Dictionary = candidates.back()
	for candidate in candidates:
		pick-=maxf(0.001,float(candidate.get("weight",1.0)))
		if pick<=0.0:
			selected=candidate
			break
	track_history[history_key]=str(selected.get("id",""))
	return selected

func _load_track_stream(track: Dictionary) -> AudioStream:
	var path := str(track.get("path",""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var source := load(path) as AudioStream
	if source==null: return null
	var stream: AudioStream = source.duplicate()
	var duration := stream.get_length()
	var loop_start := clampf(float(track.get("loop_start_seconds",0.0)),0.0,maxf(0.0,duration-0.001))
	var loop_end := float(track.get("loop_end_seconds",0.0))
	if loop_end<=loop_start or loop_end>duration: loop_end=duration
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var rate := maxi(1,wav.mix_rate)
		wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin=roundi(loop_start*rate)
		wav.loop_end=maxi(wav.loop_begin+1,roundi(loop_end*rate))
	elif stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop=true
		ogg.loop_offset=loop_start
	return stream

func start_frontend(restart: bool = false) -> void:
	if speech!=null: speech.stop()
	engine_voice.stop()
	harvest_loop.stop()
	frontend=true; sim=null; paused=false; state="FIRST_SIGNAL"
	for layer in layers: layer.stream_paused=false; layer.stop()
	for voice in voices: voice.stream_paused=false; voice.stop()
	if frontend_player.stream==null:
		var title: Dictionary = music_catalog.get("title_track",{})
		frontend_player.stream=_load_track_stream(title)
	frontend_player.stream_paused=false
	if restart or not frontend_player.playing:
		frontend_player.volume_db=-38
		frontend_player.play()

func cue(name_value: String, attenuation: float = 1.0, screen_position: Vector2 = Vector2(-1,-1)) -> void:
	if not samples.has(name_value): return
	if name_value.ends_with("_shot") or name_value.ends_with("_impact"):
		if float(cue_cooldowns.get(name_value,0))>0: return
		cue_cooldowns[name_value]=0.055 if name_value.ends_with("_shot") else 0.035
	var priority := _cue_priority(name_value)
	var voice: AudioStreamPlayer2D
	for candidate in voices:
		if not candidate.playing:
			voice=candidate
			break
	if voice==null:
		var weakest_priority := 999
		for candidate in voices:
			var current_priority := int(candidate.get_meta("cue_priority",0))
			if current_priority<weakest_priority:
				weakest_priority=current_priority
				voice=candidate
		if voice==null or priority<=weakest_priority: return
		voice.stop()
	var bank: Array = variants.get(name_value,[samples[name_value]])
	var index := int(cue_indices.get(name_value,0))
	voice.stream=bank[index%bank.size()]
	cue_indices[name_value]=index+1
	voice.pitch_scale=music_rng.randf_range(0.985,1.015) if bank.size()>1 else 1.0
	voice.volume_db=linear_to_db(maxf(0.001,sfx_volume*attenuation*0.65))
	var is_ui := name_value in ["select","move","error","save"]
	var is_combat := name_value.ends_with("_shot") or name_value.ends_with("_impact") or name_value in ["explosion","core_impact"]
	voice.bus="UI" if is_ui else ("Combat" if is_combat else "SFX")
	if screen_position.x>=0.0:
		voice.position=screen_position
		voice.panning_strength=1.0
	else:
		voice.position=audio_listener.position
		voice.panning_strength=0.0
	voice.set_meta("cue_priority",priority)
	voice.play()

func _cue_priority(cue_name: String) -> int:
	if cue_name in ["victory","defeat","alarm"]: return 8
	if cue_name in ["core_impact","explosion","special_impact"]: return 7
	if cue_name.begins_with("siege_") or cue_name.begins_with("artillery_"): return 5
	if cue_name in ["select","move","error","save"]: return 2
	if cue_name.ends_with("_shot") or cue_name.ends_with("_impact"): return 3
	return 4

func play_voice(stream: AudioStream, voice_volume_db: float = -2.0) -> bool:
	if stream==null: return false
	for voice_player in voice_players:
		if not voice_player.playing:
			voice_player.stream=stream
			voice_player.volume_db=voice_volume_db
			voice_player.play()
			return true
	return false

func set_voice_volume(value: float) -> void:
	if speech!=null: speech.set_volume(value)

func set_harvester_working(active: bool, screen_position: Vector2 = Vector2(-1,-1), attenuation: float = 0.7) -> void:
	if harvest_loop==null or harvest_loop.stream==null: return
	if not active:
		harvest_loop.volume_db=-70.0
		harvest_loop.stop()
		return
	if screen_position.x>=0.0:
		harvest_loop.position=screen_position
		harvest_loop.panning_strength=1.0
	else:
		harvest_loop.position=audio_listener.position
		harvest_loop.panning_strength=0.0
	harvest_loop.volume_db=linear_to_db(maxf(0.001,sfx_volume*attenuation*0.5))
	if not harvest_loop.playing: harvest_loop.play()

func set_paused(value: bool) -> void:
	engine_voice.stream_paused=value
	paused=value
	frontend_player.stream_paused=value
	if stinger_player!=null: stinger_player.stream_paused=value
	for layer in layers: layer.stream_paused=value
	for stem_player in stem_players: stem_player.stream_paused=value
	for voice in voices: voice.stream_paused=value
	for voice_player in voice_players: voice_player.stream_paused=value
	if harvest_loop!=null: harvest_loop.stream_paused=value
	if speech!=null and is_instance_valid(speech.player): speech.player.stream_paused=value

func shutdown() -> void:
	if is_instance_valid(engine_voice): engine_voice.stream_paused=false; engine_voice.stop()
	if is_instance_valid(stinger_player): stinger_player.stream_paused=false; stinger_player.stop(); stinger_player.stream=null
	if is_instance_valid(harvest_loop): harvest_loop.stream_paused=false; harvest_loop.stop(); harvest_loop.stream=null
	frontend_player.stream_paused=false; frontend_player.stop(); frontend_player.stream=null
	for layer in layers: layer.stream_paused=false; layer.stop(); layer.stream=null
	for stem_player in stem_players: stem_player.stream_paused=false; stem_player.stop(); stem_player.stream=null
	for voice in voices: voice.stream_paused=false; voice.stop(); voice.stream=null
	for voice_player in voice_players: voice_player.stream_paused=false; voice_player.stop(); voice_player.stream=null
	if speech!=null: speech.stop()

func _exit_tree() -> void:
	shutdown()

func _process(dt: float) -> void:
	if speech!=null: speech.tick(dt)
	if audio_listener!=null:
		audio_listener.position=get_viewport().get_visible_rect().size*0.5
	shot_cooldown=maxf(0,shot_cooldown-dt)
	for cue_name in cue_cooldowns: cue_cooldowns[cue_name]=maxf(0,float(cue_cooldowns[cue_name])-dt)
	var voice_active: bool = voice_players.any(func(player: AudioStreamPlayer): return player.playing) or (speech!=null and is_instance_valid(speech.player) and speech.player.playing)
	voice_duck=move_toward(voice_duck,0.72 if voice_active else 1.0,dt*1.5)
	if frontend and not paused:
		frontend_player.volume_db=move_toward(frontend_player.volume_db,linear_to_db(maxf(0.001,music_volume*0.7)),dt*12)
		return
	if stinger_player!=null and stinger_player.playing:
		stinger_player.volume_linear=clampf(music_volume*0.85*voice_duck,0.0,1.0)
	if sim==null or (layers.is_empty() and stem_players.is_empty()) or paused: return
	tactical_scan_timer-=dt
	if tactical_scan_timer<=0.0:
		tactical_scan_timer=0.25
		cached_movers=0
		cached_visible_enemies=0
		for e in sim.entities.values():
			var is_enemy: bool=e.owner!=sim.view_owner
			var is_moving_unit: bool=not e.building and e.velocity.length()>8
			if not is_enemy and not is_moving_unit: continue
			if not sim.is_visible(e,sim.view_owner): continue
			if is_enemy: cached_visible_enemies+=1
			if is_moving_unit: cached_movers+=1
	engine_voice.volume_db=move_toward(engine_voice.volume_db,linear_to_db(maxf(0.0001,minf(0.20,cached_movers*0.035)*sfx_volume)),dt*35)
	age+=dt
	var desired := clampf(sim.combat_heat+cached_visible_enemies*0.025+(0.4 if sim.base_alarm>0 else 0.0),0,1)
	intensity=move_toward(intensity,desired,dt*0.45)
	var next := "BASE_CALM"
	if sim.result!="": next=sim.result.to_upper()
	elif sim.base_alarm>0: next="BASE_UNDER_ATTACK"
	elif intensity>0.75: next="MAJOR_BATTLE"
	elif intensity>0.4: next="BATTLE"
	elif intensity>0.18: next="SKIRMISH"
	elif cached_visible_enemies>0: next="ENEMY_CONTACT"
	elif not sim.buildings(sim.view_owner,"refinery").is_empty(): next="ECONOMY"
	if next!=pending: pending=next
	# Minimum dwell plus transitions at a 2-second bar boundary.
	var playhead: float = layers[0].get_playback_position() if not layers.is_empty() else stem_players[0].get_playback_position()
	var bpm := float(music_catalog.get("default_tempo_bpm",120))
	var beats_per_bar := float(music_catalog.get("default_beats_per_bar",4))
	var beat_unit := 4.0
	if not selected_tracks.is_empty():
		bpm=float(selected_tracks[0].get("bpm",bpm))
		beats_per_bar=float(selected_tracks[0].get("beats_per_bar",beats_per_bar))
		beat_unit=float(selected_tracks[0].get("beat_unit",4))
	var bar_seconds := 60.0/maxf(1.0,bpm)*maxf(1.0,beats_per_bar)*4.0/maxf(1.0,beat_unit)
	var music_bar := floori(playhead/bar_seconds)
	var crossed_bar := music_bar!=last_music_bar
	last_music_bar=music_bar
	if pending!=state and age>2.0 and crossed_bar:
		state=pending; age=0
	if sim.result!="" and not ended:
		ended=true; state=sim.result.to_upper(); cue(sim.result)
		play_global_stinger("victory" if sim.result.to_lower()=="victory" else "defeat")
		if speech!=null: speech.request("mission",faction_id)
	elif state=="BASE_UNDER_ATTACK" and pending==state and not bool(get_meta("alert_stinger_played",false)):
		play_global_stinger("major_alert")
		set_meta("alert_stinger_played",true)
	# Authored stem sets are mixed dynamically when present. Until real faction
	# stems are supplied, keep the validated complete-mix transition path.
	_update_arrangement_mix(dt)

func _arrangement_index_for_state(value: String) -> int:
	match value:
		"ECONOMY": return 1
		"ENEMY_CONTACT": return 2
		"SKIRMISH": return 3
		"BATTLE", "MAJOR_BATTLE": return 4
		"BASE_UNDER_ATTACK", "VICTORY", "DEFEAT": return 5
		_: return 0

func _update_arrangement_mix(dt: float) -> void:
	if not stem_players.is_empty():
		_update_stem_mix(dt)
		return
	if layers.is_empty(): return
	var requested_index := _arrangement_index_for_state(state)
	if ended: requested_index=0
	if requested_index!=active_arrangement_index:
		previous_arrangement_index=active_arrangement_index
		active_arrangement_index=requested_index
		arrangement_crossfade_elapsed=0.0
	arrangement_crossfade_elapsed=minf(ARRANGEMENT_CROSSFADE_SECONDS,arrangement_crossfade_elapsed+dt)
	var blend := smoothstep(0.0,ARRANGEMENT_CROSSFADE_SECONDS,arrangement_crossfade_elapsed)
	for i in layers.size():
		var weight := 0.0
		if arrangement_crossfade_elapsed>=ARRANGEMENT_CROSSFADE_SECONDS:
			weight=1.0 if i==active_arrangement_index else 0.0
		else:
			# Equal-power fade prevents a level dip; at most two full arrangements overlap.
			if i==previous_arrangement_index: weight=cos(blend*PI*0.5)
			if i==active_arrangement_index: weight=maxf(weight,sin(blend*PI*0.5))
		var state_gain := 0.72 if active_arrangement_index<=1 else (0.82 if active_arrangement_index==2 else (0.92 if active_arrangement_index<=4 else 0.86))
		var gain := weight*state_gain*music_volume*voice_duck
		var target_db := linear_to_db(maxf(0.0001,gain))
		layers[i].volume_db=target_db

func _update_stem_mix(dt: float) -> void:
	if stem_players.is_empty(): return
	var gains: Dictionary={"atmosphere":0.68,"pulse":0.08,"bass":0.16,"rhythm":0.0,"percussion":0.0,"motif":0.30,"combat":0.0,"critical":0.0}
	var battle:=clampf(intensity,0.0,1.0)
	var contact:=1.0 if state in ["ENEMY_CONTACT","SKIRMISH","BATTLE","MAJOR_BATTLE","BASE_UNDER_ATTACK"] else 0.0
	var combat_state:=1.0 if state in ["BATTLE","MAJOR_BATTLE","BASE_UNDER_ATTACK","VICTORY","DEFEAT"] else 0.0
	gains["pulse"]=0.08+battle*0.40
	gains["bass"]=0.16+battle*0.44
	gains["rhythm"]=contact*(0.16+battle*0.43)
	gains["percussion"]=combat_state*(0.22+maxf(battle,0.35)*0.52)
	gains["motif"]=0.30 if state in ["BASE_CALM","ECONOMY"] else 0.18+battle*0.22
	gains["combat"]=combat_state*clampf((battle-0.25)*0.90,0.0,0.65)
	gains["critical"]=0.72 if state in ["BASE_UNDER_ATTACK","MAJOR_BATTLE","VICTORY","DEFEAT"] or (sim!=null and sim.base_alarm>0) else 0.0
	var layer_specs: Dictionary=adaptive_stem_set.get("layers",{})
	for i in stem_players.size():
		var stem_name:=stem_names[i]
		var spec: Dictionary=layer_specs.get(stem_name,{})
		var gain:=clampf(float(gains.get(stem_name,0.0))*float(spec.get("gain",1.0))*music_volume*voice_duck,0.0,1.5)
		var target_db:=linear_to_db(maxf(0.0001,gain))
		stem_players[i].volume_db=move_toward(stem_players[i].volume_db,target_db,maxf(0.0,dt)*10.0)
