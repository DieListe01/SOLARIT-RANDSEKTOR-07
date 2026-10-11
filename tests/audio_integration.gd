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
	check(director.music_catalog.get("schema_version",0)==2,"Central music catalog loads")
	for faction_id in ["forge","drift","lumen"]:
		var faction: Dictionary=director.music_catalog.get("factions",{}).get(faction_id,{})
		check(not faction.is_empty(),"Music catalog defines faction "+faction_id)
		for track_state in ["calm","contact","battle","alarm"]:
			var choices: Array=faction.get("tracks",{}).get(track_state,[])
			check(not choices.is_empty(),"Music catalog defines "+faction_id+" / "+track_state)
			if not choices.is_empty():
				var loaded_track: AudioStream=director._load_track_stream(choices[0])
				check(loaded_track is AudioStreamOggVorbis,"Catalog OGG imports for "+faction_id+" / "+track_state)
				if loaded_track is AudioStreamOggVorbis:
					check((loaded_track as AudioStreamOggVorbis).loop and loaded_track.get_length()>90.0,"Long catalog loop is configured for "+faction_id+" / "+track_state)
	var title: AudioStream=director._load_track_stream(director.music_catalog.get("title_track",{}))
	check(title is AudioStreamOggVorbis and title.get_length()>=120.0,"Title score is a long OGG source")
	check(director.harvest_loop.stream is AudioStreamOggVorbis,"Harvester has a compressed mechanical work loop")
	check(director.samples.get("harvest_start_demo")!=null and director.samples.get("harvest_collect_demo")!=null and director.samples.get("harvest_unload_demo")!=null,"Harvester start, collection and unload cues load")
	var sim := Simulation.new(Catalog.new())
	director.start(sim)
	await create_timer(0.15).timeout
	check(director.layers.size()==4,"Four synchronized state stems")
	check(director.selected_tracks.size()==4,"Music tracks resolve from catalog metadata")
	check(director.faction_id==str(sim.factions[0]),"Mission music uses the selected faction family")
	var head: float = director.layers[0].get_playback_position()
	for layer in director.layers:
		check(layer.playing and absf(layer.get_playback_position()-head)<0.05,"Layer transport synchronized")
		check(layer.stream is AudioStreamOggVorbis,"Runtime music uses compressed Ogg Vorbis")
		if layer.stream is AudioStreamOggVorbis:
			check((layer.stream as AudioStreamOggVorbis).loop,"Long music stem loops in the audio stream")
		check(layer.stream.get_length()>90.0,"Runtime music stem is at least 90 seconds before repeating")
	check(float(director.selected_tracks[0].get("bpm",0))>0.0,"Track tempo metadata is available to bar transitions")
	director.cue("explosion",0.5,Vector2(1200,500))
	var spatial_voice: AudioStreamPlayer2D
	for player in director.voices:
		if player.playing and int(player.get_meta("cue_priority",0))==7: spatial_voice=player; break
	check(spatial_voice!=null and is_equal_approx(spatial_voice.panning_strength,1.0),"World combat sound uses stereo positional panning")
	for i in director.voices.size(): director.cue("select")
	director.cue("core_impact")
	check(director.voices.any(func(player: AudioStreamPlayer2D): return player.playing and int(player.get_meta("cue_priority",0))==7),"High-priority impact takes a voice over UI cues")
	check(director.play_voice(load("res://assets/audio/complete.wav")),"Dedicated voice player accepts a voice stream")
	await create_timer(0.08).timeout
	check(director.voice_duck<1.0,"Active voice gently ducks music")
	director.set_harvester_working(true,Vector2(1200,500))
	check(director.harvest_loop.playing and is_equal_approx(director.harvest_loop.panning_strength,1.0),"Harvester work loop is positional and starts on work state")
	director.set_harvester_working(false)
	check(not director.harvest_loop.playing,"Harvester loop stops outside the active work state")
	var core: Dictionary = sim.buildings(0,"core")[0]
	sim.spawn("tank",1,core.pos+Vector2(100,0),false)
	sim.update_fog()
	var harvest_events:Array[String]=[]
	sim.event.connect(func(kind:String,_pos:Vector2,_message:String): harvest_events.append(kind))
	var collector_id:int=sim.spawn("harvester",0,core.pos+Vector2(140,0),false)
	var collector:Dictionary=sim.entities[collector_id]
	sim.set_harvest_state(collector,"HARVEST")
	sim.set_harvest_state(collector,"UNLOAD")
	check(harvest_events==["harvest_start","harvest_stop","harvest_unload"],"Harvester work-state transitions emit one-shot sound cues without per-frame repeats")
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
