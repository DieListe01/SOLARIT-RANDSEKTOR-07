extends SceneTree

const CatalogScript := preload("res://scripts/catalog.gd")
const SimulationScript := preload("res://scripts/simulation.gd")
const RecorderScript := preload("res://scripts/match_recorder.gd")

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MATCH RECORDER: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var match_id := "match-report-test-%d" % Time.get_ticks_usec()
	var path := RecorderScript.ARCHIVE_DIR + "/" + match_id + ".json"
	var sim=SimulationScript.new(CatalogScript.new())
	var recorder=RecorderScript.new()
	recorder.begin(sim,{"match_id":match_id,"game_version":"test-9.9","mode":"duel","side_0_nickname":"Alpha","side_1_nickname":"Beta"})
	var before_events: int=recorder.report.events.size()
	sim.spawn("tank",0,Vector2(720,1300),false)
	var enemy_id: int=sim.spawn("tank",1,Vector2(1000,1300),false)
	sim.credits[0]=150
	sim.credits[1]=400
	sim.time=5.0
	recorder.observe(sim)
	check(recorder.report.samples.size()>=2,"Timeline samples are created at five-second simulation intervals")
	var latest: Dictionary=recorder.report.samples.back()
	check(float(latest.sides[0].credits)==150.0 and int(latest.sides[0].units_by_type.get("tank",0))==1 and int(latest.sides[1].units_by_type.get("tank",0))==2,"Samples preserve each side's resources and vehicle counts by type")
	check(recorder.report.events.size()>before_events,"Construction and production lifecycle events are captured")
	sim.credits[0]=500
	sim.time=10.0
	recorder.observe(sim)
	check(recorder.report.events.any(func(e):return str(e.kind)=="lead_change" and str(e.description).contains("Solarit-Lager")),"The report records when a player takes the lead in a tracked metric")
	check(not FileAccess.file_exists(path),"An unfinished match is not written as an archived report")
	sim.destroy(enemy_id)
	recorder.observe(sim)
	sim.result="victory"
	sim.winner=0
	check(recorder.finish(sim),"Only a completed victory or defeat is written to the archive")
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and int(parsed.get("schema_version",0))==RecorderScript.SCHEMA_VERSION and str(parsed.get("game_version",""))=="test-9.9","The saved report has a schema version and game version")
	check(parsed is Dictionary and str(parsed.get("outcome",""))=="victory" and parsed.get("events",[]).any(func(e):return str(e.kind)=="destroy"),"Completed results include the outcome and destroyed-unit history")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MATCH RECORDER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
