extends SceneTree
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := Catalog.new()
	var sim := Simulation.new(db,"forge","easy")
	var plan := [
		["power",Vector2i(14,43)],
		["refinery",Vector2i(14,47)],
		["factory",Vector2i(9,49)],
		["refinery",Vector2i(20,49)],
		["power",Vector2i(18,50)],
		["tower",Vector2i(16,40)],
		["radar",Vector2i(9,39)],
		["power",Vector2i(6,46)],
		["tower",Vector2i(17,40)]
	]
	var next := 0
	var next_command := 0.0
	var attacked := false
	var discovered := false
	var enemy_core_id: int = sim.buildings(1,"core")[0].id
	var last_report := -1
	while sim.time<1200 and sim.result=="":
		if sim.time>=next_command:
			next_command=sim.time+2
			var constructing := sim.buildings(0,"",false).any(func(e):return not e.complete)
			if next<plan.size() and not constructing:
				if sim.build(plan[next][0],0,plan[next][1])>0: next+=1
			var army := sim.entities.values().filter(func(e):return e.owner==0 and not e.building and e.kind!="harvester")
			if not sim.buildings(0,"factory").is_empty():
				if sim.buildings(0,"factory")[0].queue.size()<2:
					if next>=5 or sim.credits[0]>1200:
						var kind := "siege" if sim.prerequisites("siege",0) and army.size()%4==0 else "tank"
						sim.enqueue(kind,0)
			# The human test driver also learns enemy positions exclusively from its vision.
			if not discovered:
				var scouts := army.filter(func(e):return e.kind=="scout")
				if not scouts.is_empty() and scouts[0].path.is_empty(): sim.command([scouts[0].id],Vector2(49,25)*32,"move")
			for intel in sim.known[0].values():
				if intel.kind=="core" and intel.building: discovered=true
			var threats := sim.entities.values().filter(func(e):return e.owner==1 and sim.is_visible(e,0) and e.pos.distance_to(sim.buildings(0,"core")[0].pos)<500)
			if not threats.is_empty():
				var defenders: Array = []
				for e in army: defenders.append(e.id)
				sim.command(defenders,threats[0].pos,"attack",threats[0].id)
			elif not discovered and army.size()>=7:
				var scouts: Array = []
				for e in army: scouts.append(e.id)
				sim.command(scouts,Vector2(49,25)*32,"attack_move")
			if threats.is_empty() and discovered and (army.size()>=8 or attacked):
				attacked=true
				var ids: Array = []
				for e in army: ids.append(e.id)
				var intel: Dictionary = sim.known[0].get(str(enemy_core_id),{})
				if not intel.is_empty(): sim.command(ids,intel.pos,"attack_move")
		var minute := int(sim.time)/60
		if minute!=last_report:
			last_report=minute
			print("t=%d credits=%d army=%d gathered=%d AI=%s build=%d" % [int(sim.time),int(sim.credits[0]),sim.entities.values().filter(func(e):return e.owner==0 and not e.building and e.kind!="harvester").size(),int(sim.stats.gathered),sim.ai_state,next])
		sim.tick(1.0/30.0)
	print("PLAYTHROUGH: %s at %.1fs; gathered %.0f; produced %d; kills %d; player losses %d" % [sim.result,sim.time,sim.stats.gathered,sim.stats.produced,sim.stats.kills,sim.stats.lost])
	if sim.result!="victory":
		push_error("Paid end-to-end playthrough did not win")
		quit(1)
	else: quit(0)
