extends SceneTree

const Protocol := preload("res://scripts/network_protocol.gd")

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func make_production(kind: String) -> Dictionary:
	var sim := Simulation.new(Catalog.new(), "forge", "easy")
	sim.ai_timer = 99999.0
	var factory_id := sim.spawn("factory", 0, Vector2(32, 38) * 32.0, true)
	var factory: Dictionary = sim.entities[factory_id]
	factory.queue = [{"kind": kind, "paid": 0}]
	var duration := float(sim.db.units[kind].time)
	factory.progress = duration - 0.2
	sim.process_building(factory, 1.0)
	return {"sim": sim, "factory_id": factory_id, "unit_id": sim.next_id - 1}

func make_pending_progress(ratio: float) -> Dictionary:
	var sim := Simulation.new(Catalog.new(), "forge", "easy")
	var factory_id := sim.spawn("factory", 0, Vector2(32, 38) * 32.0, true)
	var factory: Dictionary = sim.entities[factory_id]
	factory.queue = [{"kind": "tank", "paid": 440}]
	factory.progress = float(sim.db.units.tank.time) * ratio
	return {"sim": sim, "factory_id": factory_id, "progress": float(factory.progress)}

func finish_exit(sim: Simulation, unit: Dictionary) -> void:
	for _step in 300:
		if not bool(unit.get("production_exit_active", false)): return
		sim.move_unit(unit, 1.0 / 30.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for ratio in [0.25, 0.75, 0.95]:
		var pending := make_pending_progress(ratio)
		var pending_sim: Simulation = pending.sim
		var payload: Dictionary = JSON.parse_string(JSON.stringify(pending_sim.snapshot()))
		var pending_copy := Simulation.new(Catalog.new(), "forge", "easy")
		check(pending_copy.restore(payload) == OK, "Save/load accepts in-progress production at %.0f%%" % (ratio * 100.0))
		var loaded_factory: Dictionary = pending_copy.entities[pending.factory_id]
		check(is_equal_approx(float(loaded_factory.progress), pending.progress) and loaded_factory.queue.size() == 1 and not loaded_factory.has("production_exit_unit"), "Save at %.0f%% restores exactly one queued visual and no live unit" % (ratio * 100.0))
		if ratio == 0.95:
			var mobile_before_destruction := pending_copy.mobile_entity_count
			pending_copy.destroy(pending.factory_id)
			check(pending_copy.mobile_entity_count == mobile_before_destruction, "Destroying a factory before completion cancels the proxy without spawning a vehicle")

	for kind in ["scout", "raider", "tank", "siege", "harvester"]:
		var scenario := make_production(kind)
		var sim: Simulation = scenario.sim
		var factory: Dictionary = sim.entities[scenario.factory_id]
		var unit: Dictionary = sim.entities[scenario.unit_id]
		var expected_exit: Vector2 = unit.production_exit_to
		check(bool(unit.get("production_exit_active", false)), "%s is active only after production completion and starts in an exit sequence" % kind)
		check(unit.pos.distance_to(unit.production_exit_to) > 1.0, "%s begins inside the exit lane instead of popping at the outside point" % kind)
		check(unit.path.is_empty(), "%s buffers the rally route until it leaves the building" % kind)
		if kind != "harvester":
			sim.command([unit.id], factory.rally + Vector2(160, 0))
			check(unit.path.is_empty() and unit.destination == factory.rally + Vector2(160, 0), "%s buffers player orders during exit" % kind)
		var save_json := JSON.stringify(sim.snapshot())
		var restored := Simulation.new(Catalog.new(), "forge", "easy")
		var restore_err := restored.restore(JSON.parse_string(save_json))
		check(restore_err == OK, "%s production exit survives JSON save/load" % kind)
		if restore_err == OK:
			unit = restored.entities[scenario.unit_id]
			expected_exit = unit.production_exit_to
			check(unit.production_exit_active and unit.production_exit_from is Vector2 and unit.production_exit_to is Vector2, "%s restores the active exit path without losing its proxy handoff" % kind)
			if kind=="tank":
				var host_copy := Simulation.new(Catalog.new(),"forge","easy")
				check(host_copy.restore(JSON.parse_string(save_json))==OK,"Tank exit snapshot restores on an independent multiplayer peer")
				for tick_index in 12:
					restored.tick(1.0/30.0)
					host_copy.tick(1.0/30.0)
					check(Protocol.state_hash(restored.snapshot())==Protocol.state_hash(host_copy.snapshot()),"Production exit remains deterministic between host and client simulation tick %d" % tick_index)
			finish_exit(restored, unit)
			check(not unit.production_exit_active and unit.pos.distance_to(expected_exit) < 0.1, "%s completes its exit before normal movement" % kind)
			if kind != "harvester": check(restored.path_requests.has(unit.id), "%s resumes its buffered rally order after exiting" % kind)
		# Destroying a yard after completion never deletes the already-created unit.
		if kind == "tank":
			var alive_id: int = int(unit.id)
			restored.destroy(scenario.factory_id)
			check(restored.entities.has(alive_id), "A completed vehicle survives factory destruction during exit")
			finish_exit(restored, restored.entities[alive_id])

	# A blocked exit retargets to a nearby free perimeter cell without teleporting the vehicle.
	var blocked_case := make_production("bulwark")
	var blocked_sim: Simulation = blocked_case.sim
	var blocked_unit: Dictionary = blocked_sim.entities[blocked_case.unit_id]
	var blocked_target: Vector2 = blocked_unit.production_exit_to
	blocked_sim.spawn("scout", 1, blocked_target, false)
	var start_position: Vector2 = blocked_unit.pos
	blocked_sim.move_unit(blocked_unit, 0.2)
	check(blocked_unit.pos.distance_to(start_position) < 20.0, "A blocked exit waits rather than teleporting through another unit")
	check(blocked_unit.production_exit_to != blocked_target, "A blocked exit seeks a nearby safe perimeter cell")
	var blocked_origin := blocked_sim.grid.cell(blocked_target)
	for y in range(-4,5):
		for x in range(-4,5):
			blocked_sim.grid.reserve(blocked_origin+Vector2i(x,y),[1,1],900000+(y+4)*9+x+4,true)
	check(blocked_sim._nearest_production_exit_cell(blocked_origin,blocked_unit,4).x<0,"A fully obstructed local exit has no unsafe short-range fallback")
	var distant_fallback := blocked_sim._nearest_production_exit_cell(blocked_origin,blocked_unit,18)
	check(distant_fallback.x>=0 and distant_fallback.distance_to(blocked_origin)>4,"A prolonged obstruction can find a farther free fallback cell")

	# The next queued vehicle waits until the previous one finishes leaving.
	var queue_case := make_production("tank")
	var queue_sim: Simulation = queue_case.sim
	var queue_factory: Dictionary = queue_sim.entities[queue_case.factory_id]
	var queue_unit: Dictionary = queue_sim.entities[queue_case.unit_id]
	queue_factory.queue = [{"kind": "scout", "paid": 0}]
	queue_factory.progress = 0.0
	queue_sim.process_building(queue_factory, 1.0)
	check(queue_factory.progress == 0.0 and queue_factory.queue.size() == 1, "Production queue waits while the prior unit exits")
	finish_exit(queue_sim, queue_unit)
	queue_sim.process_building(queue_factory, 1.0)
	check(queue_factory.progress > 0.0, "The next queued vehicle starts after the exit lane clears")

	# Two independent yards can assemble at once without sharing exit state.
	var concurrent := Simulation.new(Catalog.new(), "forge", "easy")
	var first_id := concurrent.spawn("factory", 0, Vector2(32, 38) * 32.0, true)
	var second_id := concurrent.spawn("factory", 0, Vector2(39, 38) * 32.0, true)
	for factory_id in [first_id, second_id]:
		var yard: Dictionary = concurrent.entities[factory_id]
		yard.queue = [{"kind": "scout", "paid": 0}]
		yard.progress = float(concurrent.db.units.scout.time) - 0.2
		concurrent.process_building(yard, 1.0)
	check(int(concurrent.entities[first_id].get("production_exit_unit", 0)) > 0 and int(concurrent.entities[second_id].get("production_exit_unit", 0)) > 0, "Two yards keep independent production and exit states")

	if failures.is_empty():
		print("FACTORY PRODUCTION: %d checks, 0 failures" % checks)
		quit(0)
	else:
		printerr("FACTORY PRODUCTION: %d checks, %d failures" % [checks, failures.size()])
		quit(1)
