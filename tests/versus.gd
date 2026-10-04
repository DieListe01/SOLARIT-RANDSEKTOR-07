extends SceneTree

const Session = preload("res://scripts/online_session.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error("VERSUS: "+message)

func _initialize() -> void:
	for path in ["res://data/veyra.json","res://data/dry_vein.json","res://data/khepri_pass.json"]:
		var sim:=Simulation.new(Catalog.new(path))
		var config:=Session.normalize_config({"mode":"versus","host_faction":"lumen","client_faction":"forge","host_color":"408bf4","client_color":"f1c744","start_credits":6000})
		sim.configure_versus(config)
		check(sim.entities.size()==4 and sim.credits==[6000.0,6000.0],"equal starting armies and credits: "+path)
		check(sim.factions==["lumen","forge"] and sim.campaign_tech_level==2,"chosen factions and equal technology")
		for owner in 2:
			check(sim.buildings(owner,"core").size()==1,"both players have a core")
			var scout: Dictionary=sim.entities.values().filter(func(e):return e.owner==owner and not e.building)[0]
			check(sim.grid.is_free(sim.grid.cell(scout.pos)),"scout has traversable start cell")
			var core: Dictionary=sim.buildings(owner,"core")[0]
			for y in 3:
				for x in 3: check(sim.grid.terrain[(core.cell.y+y)*sim.grid.width+core.cell.x+x]!=2,"core has buildable ground")
		var before:=sim.snapshot()
		for index in 90: sim.tick(1.0/30.0)
		check(sim.ai_state==before.ai_state and sim.entities.size()==4,"AI and campaign waves stay disabled")
		var state:=sim.snapshot_for(1)
		check(state.entities.all(func(e):return e.owner==1),"hidden enemy entities never transmitted")
		check(state.credits[0]==0 and state.known[0].is_empty() and state.explored[0].all(func(v):return v==0),"opponent economy, intel and exploration withheld")
		check(state.rng_state=="0" and state.triggered_waves.is_empty(),"private simulation state withheld")
		var replica:=Simulation.new(Catalog.new(path))
		check(replica.restore(state)==OK and replica.view_owner==1,"filtered state restores for player two")
		check(replica.restore(JSON.parse_string(JSON.stringify(state)))==OK,"filtered state accepts JSON integer representation")
		var broken:=state.duplicate(true)
		broken.view_owner=0.5
		check(replica.restore(broken)==ERR_INVALID_DATA and replica.view_owner==1,"fractional viewer rejected atomically")
		broken=state.duplicate(true); broken.viewer_fog[0]=0.5
		check(replica.restore(broken)==ERR_INVALID_DATA,"nonbinary visibility rejected")
		check(replica.fog[1]==sim.fog[1] and replica.explored[1]==sim.explored[1],"own fog is authoritative")
		var enemy: Dictionary=sim.entities.values().filter(func(e):return e.owner==0 and not e.building)[0]
		var own: Dictionary=sim.entities.values().filter(func(e):return e.owner==1 and not e.building)[0]
		enemy.pos=own.pos+Vector2(30,0); enemy.path=[Vector2(12,34)]
		enemy.destination=Vector2(123,456); enemy.queue=[{"kind":"tank","paid":600}]
		enemy.secret="must not cross network"
		sim.update_fog()
		state=sim.snapshot_for(1)
		var public: Dictionary=state.entities.filter(func(e):return e.id==enemy.id)[0]
		check(public.path.is_empty() and public.queue.is_empty() and public.destination==public.pos and not public.has("secret"),"visible enemies expose no private intentions")
		check(replica.restore(state)==OK,"visible enemy appearance remains restore compatible")
		check(not sim.submit_command({"type":"hold","owner_id":1,"ids":[enemy.id]},1),"player cannot control rival unit")
		check(sim.submit_command({"type":"hold","owner_id":1,"ids":[own.id]},1),"player two controls own unit")
		check(not sim.submit_command({"type":"hold","owner_id":0,"ids":[own.id]},1),"owner spoof rejected")
		enemy.pos=sim.buildings(0,"core")[0].pos
		sim.update_fog()
		check(sim.snapshot_for(1).entities.all(func(e):return e.owner==1),"enemy vanishes after leaving sight")
		sim.destroy(sim.buildings(0,"core")[0].id)
		sim.check_objectives()
		check(sim.winner==1 and sim.result=="defeat" and sim.snapshot_for(1).result=="victory","both perspectives agree on winner")
		check(sim.side_stats[0].buildings_lost==1 and sim.side_stats[1].kills==1,"statistics separated by side")
	var config:=Session.normalize_config({"mode":"versus","host_color":"19ddd4","client_color":"19ddd4","host_faction":"invalid","start_credits":99999})
	check(config.host_color!=config.client_color and config.host_faction=="forge" and config.start_credits==10000,"lobby choices normalized")
	check(Session.clean_chat("  Hallo"+String.chr(10)+"Welt"+String.chr(1)+"  ")=="HalloWelt","chat strips control characters")
	check(Session.clean_chat("x".repeat(500)).length()==300,"chat length bounded")
	print("VERSUS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
