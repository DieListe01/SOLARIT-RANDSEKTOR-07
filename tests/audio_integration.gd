Attempting to perform the InitializeDefaultDrives operation on the 'FileSystem' provider failed.
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
	var deadline := Time.get_ticks_msec()+30000
	while director.state!=expected and Time.get_ticks_msec()<deadline: await process_frame

func current_playback_position(player: AudioStreamPlayer) -> float:
	# AudioStreamPlayer reports the last mixed position; compensate to the
	# current instant so reading several players does not compare stale samples.
	return player.get_playback_position()+AudioServer.get_time_since_last_mix()

func wait_for_transport_settle(players: Array[AudioStreamPlayer], label: String) -> void:
	# Headless CI can expose scheduled starts a few mixer blocks later than the
	# game thread. Preserve the strict 50 ms requirement and wait only for the
	# audio server to publish settled playheads before sampling it.
	var deadline := Time.get_ticks_msec()+2000
	var stable_frames := 0
	var positions: Array[float] = []
	while Time.get_ticks_msec()<deadline:
		await process_frame
		positions.clear()
		for player in players: positions.append(current_playback_position(player))
		var synced := not players.is_empty() and players.all(func(player: AudioStreamPlayer): return player.playing and absf(current_playback_position(player)-positions[0])<0.05)
		stable_frames = stable_frames+1 if synced else 0
		if stable_frames>=2: return
	var formatted: Array[String] = []
	for i in positions.size(): formatted.append("%s=%.4f"%[players[i].name,positions[i]])
	print("AUDIO TRANSPORT DIAGNOSTIC %s: settled_sync=false tolerance=0.050s players=[%s]"%[label,", ".join(formatted)])

func run() -> void:
	director=MusicDirector.new()
	root.add_child(director)
	await process_frame
	check(director.music_catalog.get("schema_version",0)==3,"Central music catalog loads curated candidate schema")
	check(str(director.music_catalog.get("production_status",""))=="curated_cc0_candidate_set_pending_human_listening_review","Music remains explicitly pending human listening approval")
	for faction_id in ["forge","drift","lumen"]:
		var faction: Dictionary=director.music_catalog.get("factions",{}).get(faction_id,{})
		check(not faction.is_empty(),"Music catalog defines faction "+faction_id)
		for track_state in ["calm_a","calm_b","contact","battle_low","battle_high","critical"]:
			var choices: Array=faction.get("tracks",{}).get(track_state,[])
			check(not choices.is_empty(),"Music catalog defines "+faction_id+" / "+track_state)
			if not choices.is_empty():
				for choice in choices:
					check(str(choice.get("asset_status",""))=="candidate" and str(choice.get("human_listening_approval",""))=="pending","Unapproved music stays marked as a candidate pending review: "+faction_id+" / "+track_state+" / "+str(choice.get("id","")))
					check(str(choice.get("license",{}).get("status",""))=="cleared" and bool(choice.get("license",{}).get("commercial_use",false)),"Music provenance explicitly clears CC0 use: "+faction_id+" / "+track_state)
					var variant_stream: AudioStream=director._load_track_stream(choice)
					check(variant_stream is AudioStreamOggVorbis and variant_stream.get_length()>=80.0,"Every selectable music variant imports as a long-form runtime OGG: "+faction_id+" / "+track_state+" / "+str(choice.get("id","")))
					if variant_stream is AudioStreamOggVorbis:
						check((variant_stream as AudioStreamOggVorbis).loop,"Every selectable music variant is loop-configured: "+faction_id+" / "+track_state+" / "+str(choice.get("id","")))
				if track_state=="battle_high":
					check(choices.size()>=2,"High-intensity battle state has a distinct alternate candidate for "+faction_id)
				var loaded_track: AudioStream=director._load_track_stream(choices[0])
				check(loaded_track is AudioStreamOggVorbis,"Catalog OGG imports for "+faction_id+" / "+track_state)
				if loaded_track is AudioStreamOggVorbis:
					check((loaded_track as AudioStreamOggVorbis).loop and loaded_track.get_length()>=175.0,"Three-minute catalog loop is configured for "+faction_id+" / "+track_state)
	var title: AudioStream=director._load_track_stream(director.music_catalog.get("title_track",{}))
	check(str(director.music_catalog.get("title_track",{}).get("asset_status",""))=="candidate" and str(director.music_catalog.get("title_track",{}).get("human_listening_approval",""))=="pending","Title candidate is not falsely approved as final music")
	check(title is AudioStreamOggVorbis and title.get_length()>=120.0,"Title score is a long OGG source")
	check(director.music_catalog.get("global_stingers",{}).size()==5,"Mission, objective, alert, victory and defeat stingers are present")
	check(director.play_global_stinger("mission_start"),"Mission-start stinger resolves and plays")
	var sfx: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sfx_catalog.json"))
	var sim := Simulation.new(Catalog.new())
	director.sim=sim
	check(sfx.get("cues",{}).size()>=8 and director.samples.get("cannon_shot") is AudioStreamOggVorbis,"Curated CC0 SFX bank loads over demo cues")
	check(director.harvest_loop.stream is AudioStreamOggVorbis,"Harvester has a compressed mechanical work loop")
	check(director.samples.get("harvest_collect") is AudioStreamOggVorbis and director.samples.get("harvest_unload") is AudioStreamOggVorbis,"Harvester collection and unload cues load from the CC0 SFX bank")
	check(director.samples.get("refinery_ambience") is AudioStreamOggVorbis and director.refinery_ambience_player.stream is AudioStreamOggVorbis,"Refinery ambience loads as a compressed loop candidate")
	var refinery_sfx:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sfx_catalog.json")).cues.get("refinery_ambience",[])
	check(not refinery_sfx.is_empty() and refinery_sfx[0].asset_status=="candidate" and refinery_sfx[0].human_listening_approval=="pending" and refinery_sfx[0].license.status=="cleared","Industrial runtime sound retains its clear CC0 provenance and pending human review")
	director.cached_refinery_count=1
	director._update_refinery_ambience(0.2)
	check(director.refinery_ambience_player.playing and director.refinery_ambience_player.volume_db>-70.0,"Refinery ambience fades in only while a completed refinery is cached")
	director.cached_refinery_count=0
	director._update_refinery_ambience(20.0)
	check(not director.refinery_ambience_player.playing,"Refinery ambience fades out and stops when no refinery is active")
	check(not director.samples.has("harvest_start_demo"),"Harvest start no longer plays legacy demo audio over the work loop")
	director.start(sim)
	await create_timer(0.15).timeout
	await wait_for_transport_settle(director.layers,"full-mix layers")
	check(director.layers.size()==6,"Six synchronized tactical music states are ready for bar-aligned selection")
	check(director.selected_tracks.size()==6,"Music tracks resolve from catalog metadata")
	check(director.faction_id==str(sim.factions[0]),"Mission music uses the selected faction family")
	var head: float = current_playback_position(director.layers[0])
	for layer in director.layers:
		check(layer.playing and absf(current_playback_position(layer)-head)<0.05,"Layer transport synchronized")
		check(layer.stream is AudioStreamOggVorbis,"Runtime music uses compressed Ogg Vorbis")
		if layer.stream is AudioStreamOggVorbis:
			check((layer.stream as AudioStreamOggVorbis).loop,"Long music stem loops in the audio stream")
		check(layer.stream.get_length()>90.0,"Runtime music stem is at least 90 seconds before repeating")
	check(float(director.selected_tracks[0].get("bpm",0))>0.0,"Track tempo metadata is available to bar transitions")
	check(is_equal_approx(director._transition_bar_seconds({"unmetered":true,"bpm":0}),2.0),"Unmetered ambient music uses a neutral transition grid instead of a fabricated BPM")
	check(is_equal_approx(MusicDirector.MIN_STATE_DWELL_SECONDS,20.0) and is_equal_approx(MusicDirector.MIN_PENDING_STABILITY_SECONDS,6.0),"Tactical music requires a 20-second state hold and 6 seconds of stable new intensity")
	check(is_equal_approx(MusicDirector.ARRANGEMENT_CROSSFADE_SECONDS,4.0),"Tactical music transitions use a 4-second crossfade")
	var saved_state:=director.state
	var saved_pending:=director.pending
	var saved_age:=director.age
	var saved_pending_age:=director.pending_age
	director.state="BASE_CALM"; director.pending="ENEMY_CONTACT"
	director.age=MusicDirector.MIN_STATE_DWELL_SECONDS-0.01; director.pending_age=10.0
	check(not director._can_commit_music_state(director.pending,true),"A new tactical mix cannot cut in before the current state has had its minimum dwell")
	director.age=MusicDirector.MIN_STATE_DWELL_SECONDS; director.pending_age=MusicDirector.MIN_PENDING_STABILITY_SECONDS-0.01
	check(not director._can_commit_music_state(director.pending,true),"A short-lived tactical spike cannot replace the music state")
	director.pending_age=MusicDirector.MIN_PENDING_STABILITY_SECONDS
	check(not director._can_commit_music_state(director.pending,false) and director._can_commit_music_state(director.pending,true),"A stable tactical state transitions only at a musical bar boundary")
	director.pending="BASE_UNDER_ATTACK"; director.age=0.0; director.pending_age=0.0
	check(director._can_commit_music_state(director.pending,true),"An urgent base alarm bypasses the normal dwell")
	director.state=saved_state; director.pending=saved_pending; director.age=saved_age; director.pending_age=saved_pending_age
	director.active_arrangement_index=5
	check(director._current_transition_track()==director.selected_tracks[5],"Tactical transition timing follows the currently audible arrangement")
	director.active_arrangement_index=0
	check(director._arrangement_index_for_state("BASE_CALM")==0 and director._arrangement_index_for_state("ECONOMY")==1 and director._arrangement_index_for_state("ENEMY_CONTACT")==2 and director._arrangement_index_for_state("SKIRMISH")==3 and director._arrangement_index_for_state("BATTLE")==4 and director._arrangement_index_for_state("BASE_UNDER_ATTACK")==5,"Six tactical states select their corresponding music arrangements")
	director.cue("explosion",0.5,Vector2(1200,500))
	var spatial_voice: AudioStreamPlayer2D
	for player in director.voices:
		if player.playing and int(player.get_meta("cue_priority",0))==7: spatial_voice=player; break
	check(spatial_voice!=null and is_equal_approx(spatial_voice.panning_strength,1.0),"World combat sound uses stereo positional panning")
	for i in director.voices.size(): director.cue("select")
	director.cue("core_impact")
	check(director.voices.any(func(player: AudioStreamPlayer2D): return player.playing and int(player.get_meta("cue_priority",0))==7),"High-priority impact takes a voice over UI cues")
	check(director.play_voice(load("res://assets/audio/complete.wav")),"Dedicated voice player accepts a voice stream")
	director._process(0.08)
	check(director.voice_duck<=0.51,"Active voice reaches the -6 dB music duck within 80 ms")
	for voice_player in director.voice_players: voice_player.stop()
	director._process(0.35)
	check(director.voice_duck>=0.99,"Music restores smoothly within 350 ms after speech ends")
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
	collector.harvest_state="HARVEST"; collector.cargo=0.0
	director.harvest_cargo_buckets.clear(); director.harvest_collection_cooldown=0.0
	director._update_harvest_collection_audio()
	collector.cargo=24.0
	director._update_harvest_collection_audio()
	check(director.voices.any(func(player: AudioStreamPlayer2D): return player.playing and player.stream==director.samples.get("harvest_collect")),"Crystal pickup accent is triggered by actual gathered cargo, not duplicated at work start")
	await wait_for_state("ENEMY_CONTACT")
	check(director.state=="ENEMY_CONTACT" and director.age<MusicDirector.MIN_STATE_DWELL_SECONDS,"Contact arrangement enters only after its stable dwell and on a musical bar boundary")
	sim.combat_heat=1.0; sim.base_alarm=8.0
	await wait_for_state("BASE_UNDER_ATTACK")
	check(director.state=="BASE_UNDER_ATTACK","Base attack enables intense arrangement")
	var mix_deadline := Time.get_ticks_msec()+3500
	while director.arrangement_crossfade_elapsed<MusicDirector.ARRANGEMENT_CROSSFADE_SECONDS and Time.get_ticks_msec()<mix_deadline: await process_frame
	check(director.layers[5].volume_db>-20,"Critical arrangement audible after the bar-aligned transition")
	var non_alarm_arrangements_quiet := true
	for i in 5: non_alarm_arrangements_quiet=non_alarm_arrangements_quiet and director.layers[i].volume_db<=-20
	check(non_alarm_arrangements_quiet,"Other full mixes are not summed under the critical arrangement")
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
	for review_faction in ["forge","drift","lumen"]:
		director.start_review_preview(Simulation.new(Catalog.new(),review_faction))
		check(director.faction_id==review_faction and director.selected_tracks.size()==6,"Listening-room preview resolves all six arrangements for "+review_faction)
		check(director.selected_tracks[0].get("id","")==director.music_catalog.factions[review_faction].tracks.calm_a[0].id,"Listening-room preview uses the selected faction's calm music")
		check(director.preview_arrangement(4) and director.active_arrangement_index==4,"Listening-room preview selects high battle music for "+review_faction)
		director.shutdown()
	var stem_path:=str(director.music_catalog.factions.forge.tracks.calm_a[0].path)
	director.music_catalog.factions.forge["adaptive_stems"]={
		"bpm":108,"beats_per_bar":4,"beat_unit":4,"loop_start_seconds":0.0,"loop_end_seconds":106.667,
		"layers":{
			"atmosphere":{"path":stem_path},"pulse":{"path":stem_path},"bass":{"path":stem_path},
			"rhythm":{"path":stem_path},"percussion":{"path":stem_path},"motif":{"path":stem_path},
			"combat":{"path":stem_path},"critical":{"path":stem_path}
		}
	}
	director.music_catalog.factions.forge.adaptive_stems.layers.combat.path="res://assets/audio/music/missing_test_stem.ogg"
	director.start(sim)
	await process_frame
	check(director.stem_players.is_empty() and director.layers.size()==6,"Incomplete adaptive stem set falls back cleanly to the existing full-mix catalog")
	director.shutdown()
	director.music_catalog.factions.forge.adaptive_stems.layers.combat.path=stem_path
	director.start(sim)
	await process_frame
	# Let the audio server apply the scheduled starts before comparing playback
	# positions. This check runs headless in CI, where the dummy mixer can lag
	# one rendered frame behind AudioStreamPlayer.play().
	await create_timer(0.05).timeout
	await wait_for_transport_settle(director.stem_players,"adaptive stems")
	check(director.layers.is_empty() and director.stem_players.size()==8,"Optional adaptive stem set replaces full-mix players when authored stems exist")
	check(director.stem_players.all(func(player): return player.playing),"All available authored stems start together")
	var stem_playhead:=current_playback_position(director.stem_players[0])
	check(director.stem_players.all(func(player): return absf(current_playback_position(player)-stem_playhead)<0.05),"Adaptive stems share a synchronized transport")
	director.state="BASE_CALM"; director.intensity=0.0; director._update_stem_mix(10.0)
	var calm_combat_db:=director.stem_players[6].volume_db
	director.state="BASE_UNDER_ATTACK"; director.intensity=1.0; sim.base_alarm=8.0
	director._update_stem_mix(10.0)
	check(director.stem_players[6].volume_db>calm_combat_db and director.stem_players[7].volume_db>-10.0,"Combat and critical stems rise for an alarm state while ambience remains available")
	director.set_paused(true)
	check(director.stem_players.all(func(player): return player.stream_paused),"Adaptive stems pause with the mission audio")
	director.shutdown()
	director.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("AUDIO INTEGRATION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

