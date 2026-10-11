extends Node
class_name VoiceDirector

signal subtitle_requested(text: String, line_id: String)

const CATALOG_PATH := "res://assets/audio/voice/voice_catalog.json"
const EVENT_COOLDOWNS := {"select": 1.4, "move": 2.2, "attack": 2.0, "damage": 8.0, "critical": 14.0, "success": 8.0, "harvester_select": 1.6, "harvest_start": 8.0, "harvest_full": 10.0, "harvest_return": 8.0, "harvest_unload": 8.0, "harvest_danger": 10.0, "build_complete": 3.0, "unit_ready": 3.0, "base_attack": 12.0, "energy_critical": 20.0, "mission": 20.0}

var catalog: Dictionary = {}
var clips: Dictionary = {}
var rng := RandomNumberGenerator.new()
var player: AudioStreamPlayer
var voice_volume := 0.8
var subtitles_enabled := false
var global_cooldown := 0.0
var unit_cooldowns: Dictionary = {}
var event_cooldowns: Dictionary = {}
var last_line_by_bucket: Dictionary = {}
var last_line_id := ""
var accepted_count := 0
var suppressed_count := 0

func _ready() -> void:
	rng.randomize()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary: catalog = parsed
	else: push_error("Voice catalog could not be loaded: " + CATALOG_PATH)
	player = AudioStreamPlayer.new()
	player.bus = "Voice"
	add_child(player)
	for faction_id in catalog.get("factions", {}):
		var faction: Dictionary = catalog.factions[faction_id]
		for event_name in faction.get("lines", {}): _preload_lines(faction.lines[event_name])
	for event_name in catalog.get("system", {}): _preload_lines(catalog.system[event_name])
	_apply_volume()

func _preload_lines(lines: Array) -> void:
	for line in lines:
		var path := str(line.get("asset", ""))
		if not path.is_empty() and ResourceLoader.exists(path): clips[str(line.get("id", ""))] = load(path)

func set_volume(value: float) -> void:
	voice_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Voice")
	if bus >= 0: AudioServer.set_bus_volume_linear(bus, voice_volume)

func request(event_name: String, faction_id: String = "forge", unit_id: int = 0, group_size: int = 1) -> bool:
	var priority := _event_priority(event_name, faction_id)
	var key := "%s:%d" % [event_name, unit_id]
	if event_name in ["select", "move", "attack"] and group_size > 1 and unit_id == 0:
		suppressed_count += 1
		return false
	if float(unit_cooldowns.get(key, 0.0)) > 0.0 or float(event_cooldowns.get(event_name, 0.0)) > 0.0:
		suppressed_count += 1
		return false
	if priority > 1 and global_cooldown > 0.0:
		suppressed_count += 1
		return false
	var line := _choose_line(event_name, faction_id)
	if line.is_empty(): return false
	if player.playing:
		var playing_priority := int(player.get_meta("voice_priority", 99))
		if priority >= playing_priority:
			suppressed_count += 1
			return false
		player.stop()
	player.set_meta("voice_priority", priority)
	last_line_id = str(line.id)
	unit_cooldowns[key] = float(line.get("unit_cooldown", 5.0))
	event_cooldowns[event_name] = float(line.get("event_cooldown", EVENT_COOLDOWNS.get(event_name, 4.0)))
	global_cooldown = 0.45 if priority == 1 else 1.15
	accepted_count += 1
	var clip: AudioStream = clips.get(last_line_id)
	if clip != null and voice_volume > 0.0:
		player.stream = clip
		player.volume_linear = voice_volume
		player.play()
	if subtitles_enabled: subtitle_requested.emit(str(line.get("text", "")), last_line_id)
	return true

func _choose_line(event_name: String, faction_id: String) -> Dictionary:
	var faction: Dictionary = catalog.get("factions", {}).get(faction_id, {})
	var lines: Array = faction.get("lines", {}).get(event_name, [])
	if lines.is_empty(): lines = catalog.get("system", {}).get(event_name, [])
	if lines.is_empty(): return {}
	var bucket := faction_id + ":" + event_name
	var previous := str(last_line_by_bucket.get(bucket, ""))
	var candidates: Array = lines.filter(func(line: Dictionary): return str(line.get("id", "")) != previous)
	if candidates.is_empty(): candidates = lines
	var selected: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	last_line_by_bucket[bucket] = str(selected.get("id", ""))
	return selected

func _event_priority(event_name: String, faction_id: String) -> int:
	var lines: Array = catalog.get("factions", {}).get(faction_id, {}).get("lines", {}).get(event_name, [])
	if lines.is_empty(): lines = catalog.get("system", {}).get(event_name, [])
	return clampi(int(lines[0].get("priority", 3)), 1, 3) if not lines.is_empty() else 3

func tick(delta: float) -> void:
	global_cooldown = maxf(0.0, global_cooldown - delta)
	for key in unit_cooldowns: unit_cooldowns[key] = maxf(0.0, float(unit_cooldowns[key]) - delta)
	for key in event_cooldowns: event_cooldowns[key] = maxf(0.0, float(event_cooldowns[key]) - delta)

func stop() -> void:
	if is_instance_valid(player): player.stop(); player.stream = null
