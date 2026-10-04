extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim := Simulation.new(Catalog.new())
	sim.ai_timer=999999
	var ids: Array = []
	for i in 200:
		var cell := Vector2i(4+i%20,34+floori(i/20.0))
		var free := sim.grid.nearest_free(cell)
		ids.append(sim.spawn("tank",0,sim.grid.center(free),false))
	sim.command(ids,sim.grid.center(Vector2i(43,32)))
	var started := Time.get_ticks_usec()
	var maximum := 0
	for i in 300:
		var before := Time.get_ticks_usec()
		sim.tick(1.0/30.0)
		maximum=maxi(maximum,Time.get_ticks_usec()-before)
	var total := Time.get_ticks_usec()-started
	var moving := 0
	for id in ids:
		if sim.entities.has(id) and not sim.entities[id].path.is_empty(): moving+=1
	print("PERFORMANCE: 200 units, 300 ticks; mean %.2f ms/tick; worst %.2f ms; paths pending %d; moving %d" % [total/300000.0,maximum/1000.0,sim.path_requests.size(),moving])
	quit(0 if total/300000.0<33.3 else 1)
