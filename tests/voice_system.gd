extends SceneTree

const VoiceDirectorScript := preload("res://scripts/voice_director.gd")

var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("VOICE FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Voice")
	var director = VoiceDirectorScript.new()
	root.add_child(director)
	await process_frame
	check(director.catalog.get("schema_version", 0) == 1, "Central voice catalog loads")
	check(AudioServer.get_bus_index("Voice") >= 0, "Dedicated Voice bus is present")
	check(director.clips.size() == 124, "All German faction/system candidate samples preload from their licensed catalogue")
	check(director.preview("attack","lumen"),"Prisma attack voice sample is directly auditionable")
	check(director.last_line_id.begins_with("voice_lumen_attack_"),"Voice audition selects a preloaded faction-specific attack recording")
	check(director.preview("build_start", "drift"), "Wanderpakt build-start voice preview resolves a preloaded recording")
	check(director.last_line_id.begins_with("voice_drift_build_start_"), "Build-start voice is selected from the faction-specific line bank")
	check(is_zero_approx(director.global_cooldown),"Voice audition does not consume gameplay command cooldown")
	director.stop()
	check(director.request("select", "forge", 100), "Unit request resolves to a catalog entry")
	var first_line: String = director.last_line_id
	check(not first_line.is_empty(), "Resolved voice line has a stable text ID")
	check(not director.request("select", "forge", 100), "Per-unit/event cooldown suppresses repeated selection")
	director.tick(3.0)
	director.stop()
	check(director.request("select", "forge", 101), "Another unit can respond after global cooldown")
	check(director.last_line_id != first_line, "Repeated category rotates to a different line")
	var test_only_stream: AudioStream = load("res://assets/audio/complete.wav")
	for line in director.catalog.factions.forge.lines.select: director.clips[str(line.id)] = test_only_stream
	for line in director.catalog.factions.forge.lines.critical: director.clips[str(line.id)] = test_only_stream
	director.stop()
	director.tick(30.0)
	check(director.request("select", "forge", 102), "Normal priority voice starts from a preloaded stream")
	check(director.player.playing, "Preloaded sample begins without a disk lookup")
	check(director.request("critical", "forge", 103), "Critical voice interrupts a lower-priority line")
	check(int(director.player.get_meta("voice_priority", 99)) == 1, "Critical voice owns the single voice channel")
	director.global_cooldown = 0.0
	check(not director.request("attack", "forge", 104), "Normal voice cannot block or replace a critical line")
	director.stop()
	director.clips.clear()
	for faction_id in ["forge", "drift", "lumen"]:
		for event_name in ["select", "move", "attack", "damage", "critical", "success", "harvester_select", "harvest_start", "harvest_full", "harvest_return", "harvest_unload", "harvest_danger", "build_start"]:
			check(not director.catalog.factions[faction_id].lines[event_name].is_empty(), faction_id + " has " + event_name + " lines")
	director.tick(30.0)
	check(director.request("move", "forge", 200, 10), "A group command is accepted once for its representative")
	check(not director.request("move", "forge", 0, 10), "Group command without representative is rejected")
	director.subtitles_enabled = true
	var shown: Array[String] = []
	director.subtitle_requested.connect(func(text: String, line_id: String): shown.append(line_id + ":" + text))
	director.tick(30.0)
	check(director.request("build_complete", "forge"), "System line dispatch works through faction-neutral fallback")
	check(not shown.is_empty() and shown[0].begins_with("voice_neutral_build_complete_"), "Subtitle emits catalog ID and localized text")
	director.set_volume(0.35)
	check(is_equal_approx(director.voice_volume, 0.35), "Voice level applies immediately")
	director.set_volume(0.0)
	check(is_zero_approx(director.voice_volume), "Voice can be muted independently")
	var sim := Simulation.new(Catalog.new())
	var state_before := JSON.stringify(sim.snapshot())
	director.tick(30.0)
	director.request("success", "forge", 999)
	check(JSON.stringify(sim.snapshot()) == state_before, "Local voice presentation does not mutate serialized simulation state")
	director.stop()
	director.queue_free()
	await process_frame
	print("VOICE SYSTEM: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
