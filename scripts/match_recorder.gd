extends RefCounted
class_name MatchRecorder

const SCHEMA_VERSION := 1
const SAMPLE_INTERVAL := 5.0
const ARCHIVE_DIR := "user://match_reports"

var report: Dictionary = {}
var output_path := ""
var next_sample := 0.0
var observed_entities: Dictionary = {}
var observed_queues: Dictionary = {}

func begin(sim: Simulation, metadata: Dictionary) -> void:
	var match_id := str(metadata.get("match_id", ""))
	if match_id.is_empty(): return
	var safe_id := _safe_id(match_id)
	output_path = ARCHIVE_DIR + "/" + safe_id + ".json"
	var sides: Array = []
	for owner in 2:
		sides.append({
			"owner": owner,
			"nickname": str(metadata.get("side_%d_nickname" % owner, "Kommandant %d" % (owner + 1))),
			"faction": str(sim.factions[owner]),
			"team_color": str(sim.player_colors[owner])
		})
	report = {
		"schema_version": SCHEMA_VERSION,
		"game_version": str(metadata.get("game_version", "unbekannt")),
		"match_id": match_id,
		"started_at": Time.get_datetime_string_from_system(false, true),
		"date": Time.get_date_string_from_system(false),
		"mode": str(metadata.get("mode", "singleplayer")),
		"mission_id": str(sim.db.mission.get("id", "")),
		"mission_name": str(sim.db.mission.get("display_name", sim.db.mission.get("name", sim.db.mission.get("id", "")))),
		"difficulty": str(sim.difficulty),
		"winner": -1,
		"outcome": "",
		"duration_seconds": 0.0,
		"sides": sides,
		"samples": [],
		"events": []
	}
	observed_entities.clear()
	observed_queues.clear()
	for raw_id in sim.entities:
		var e: Dictionary = sim.entities[raw_id]
		observed_entities[int(raw_id)] = _entity_state(e)
		if e.building: observed_queues[int(raw_id)] = _queue_signature(e)
	next_sample = 0.0
	observe(sim)

func observe(sim: Simulation) -> void:
	if report.is_empty() or sim == null: return
	var current: Dictionary = {}
	for raw_id in sim.entities:
		var id := int(raw_id)
		var e: Dictionary = sim.entities[raw_id]
		var state := _entity_state(e)
		current[id] = state
		if not observed_entities.has(id):
			_add_event(sim, "spawn", e, str("Gebäude begonnen" if e.building and not e.complete else ("Gebäude errichtet" if e.building else "Fahrzeug produziert")))
		else:
			var old: Dictionary = observed_entities[id]
			if bool(state.complete) and not bool(old.complete): _add_event(sim, "complete", e, "Bau abgeschlossen")
			if int(state.upgrade_level) > int(old.upgrade_level): _add_event(sim, "upgrade", e, "Ausbau Stufe %d" % int(state.upgrade_level))
		if e.building:
			var queue := _queue_signature(e)
			if observed_queues.has(id) and queue != str(observed_queues[id]):
				var previous := str(observed_queues[id])
				if queue.length() > previous.length(): _add_event(sim, "queue", e, "Produktionsauftrag geändert")
			observed_queues[id] = queue
	for old_id in observed_entities:
		if not current.has(old_id):
			var old_state: Dictionary = observed_entities[old_id]
			_add_event_state(sim, "destroy", old_state, "Zerstört")
	observed_entities = current
	for id in observed_queues.keys():
		if not sim.entities.has(id): observed_queues.erase(id)
	while sim.time + 0.0001 >= next_sample:
		_add_sample(sim)
		next_sample += SAMPLE_INTERVAL

func finish(sim: Simulation) -> bool:
	if report.is_empty() or sim == null or sim.result not in ["victory", "defeat"]: return false
	observe(sim)
	if report.samples.is_empty() or not is_equal_approx(float(report.samples.back().get("time", -1.0)), float(sim.time)):
		_add_sample(sim)
	report.winner = int(sim.winner)
	report.outcome = str(sim.result)
	report.duration_seconds = float(sim.time)
	report.finished_at = Time.get_datetime_string_from_system(false, true)
	_add_event_state(sim, "match_end", {"owner": sim.winner}, "Sieg" if sim.result == "victory" else "Niederlage")
	return _write_report()

func store_host_report(remote_report: Dictionary) -> bool:
	if int(remote_report.get("schema_version", 0))>SCHEMA_VERSION or str(remote_report.get("match_id", ""))!=str(report.get("match_id", "")):
		return false
	report=remote_report.duplicate(true)
	return _write_report()

func _write_report() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARCHIVE_DIR))
	if error != OK and error != ERR_ALREADY_EXISTS: return false
	var temporary:=output_path+".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	var absolute_temporary:=ProjectSettings.globalize_path(temporary)
	var absolute_output:=ProjectSettings.globalize_path(output_path)
	var backup:=output_path+".previous"
	var absolute_backup:=ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(output_path):
		var backup_error:=DirAccess.rename_absolute(absolute_output,absolute_backup)
		if backup_error!=OK:
			DirAccess.remove_absolute(absolute_temporary)
			return false
	var rename_error:=DirAccess.rename_absolute(absolute_temporary,absolute_output)
	if rename_error!=OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(absolute_backup,absolute_output)
		return false
	return true

func _add_sample(sim: Simulation) -> void:
	var side_samples: Array = []
	for owner in 2:
		var units: Dictionary = {}
		var buildings: Dictionary = {}
		var unit_total := 0
		var building_total := 0
		for e in sim.entities.values():
			if int(e.owner) != owner: continue
			if e.building:
				building_total += 1
				buildings[e.kind] = int(buildings.get(e.kind, 0)) + 1
			else:
				unit_total += 1
				units[e.kind] = int(units.get(e.kind, 0)) + 1
		var s: Dictionary = sim.side_stats[owner]
		side_samples.append({
			"credits": float(sim.credits[owner]),
			"units": unit_total,
			"buildings": building_total,
			"units_by_type": units,
			"buildings_by_type": buildings,
			"gathered": float(s.get("gathered", 0)),
			"produced": int(s.get("produced", 0)),
			"built": int(s.get("built", 0)),
			"kills": int(s.get("kills", 0)),
			"lost": int(s.get("lost", 0)),
			"buildings_lost": int(s.get("buildings_lost", 0))
		})
	var sample := {"time": float(sim.time), "sides": side_samples}
	if not report.samples.is_empty():
		var previous: Dictionary=report.samples.back()
		var previous_sides: Array=previous.get("sides",[])
		for metric in ["credits", "units", "buildings", "produced", "gathered"]:
			if previous_sides.size()<2: continue
			var old_leader:=_leader(previous_sides,metric)
			var new_leader:=_leader(side_samples,metric)
			if old_leader>=0 and new_leader>=0 and old_leader!=new_leader:
				_add_event_state(sim,"lead_change",{"owner":new_leader},"Überholt bei %s · %s: %.0f zu %.0f"%[_metric_label(metric),str(report.sides[new_leader].nickname),_value_for(side_samples[new_leader],metric),_value_for(side_samples[old_leader],metric)])
	report.samples.append(sample)

func _leader(sides: Array, metric: String) -> int:
	var a:=_value_for(sides[0],metric)
	var b:=_value_for(sides[1],metric)
	return 0 if a>b else (1 if b>a else -1)

func _value_for(side: Dictionary, metric: String) -> float:
	if metric=="units": return float(side.get("units",0))
	if metric=="buildings": return float(side.get("buildings",0))
	return float(side.get(metric,0.0))

func _metric_label(metric: String) -> String:
	return str({"credits":"Solarit-Lager", "units":"Fahrzeugbestand", "buildings":"Gebäudebestand", "produced":"Produktion", "gathered":"gesammeltem Solarit"}.get(metric,metric))

func _add_event(sim: Simulation, kind: String, entity: Dictionary, description: String) -> void:
	_add_event_state(sim, kind, _entity_state(entity), description)

func _add_event_state(sim: Simulation, kind: String, state: Dictionary, description: String) -> void:
	if report.is_empty(): return
	report.events.append({
		"time": float(sim.time),
		"kind": kind,
		"owner": int(state.get("owner", -1)),
		"entity_kind": str(state.get("kind", "")),
		"building": bool(state.get("building", false)),
		"complete": bool(state.get("complete", true)),
		"position": state.get("position", [0.0, 0.0]),
		"description": description
	})

func _entity_state(e: Dictionary) -> Dictionary:
	var pos: Vector2 = e.get("pos", Vector2.ZERO)
	return {"owner": int(e.get("owner", -1)), "kind": str(e.get("kind", "")), "building": bool(e.get("building", false)), "complete": bool(e.get("complete", true)), "upgrade_level": int(e.get("upgrade_level", 0)), "position": [pos.x, pos.y]}

func _queue_signature(e: Dictionary) -> String:
	var parts: Array[String] = []
	for job in e.get("queue", []): parts.append(str(job.get("kind", "")))
	return ",".join(parts)

func _safe_id(raw: String) -> String:
	var safe := RegEx.new()
	safe.compile("[^A-Za-z0-9_-]")
	return safe.sub(raw, "_", true).left(96)
