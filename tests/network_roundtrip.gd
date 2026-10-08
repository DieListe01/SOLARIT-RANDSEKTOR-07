extends SceneTree

const CatalogData = preload("res://scripts/catalog.gd")
const GameSimulation = preload("res://scripts/simulation.gd")
const Session = preload("res://scripts/online_session.gd")
const Protocol = preload("res://scripts/network_protocol.gd")
const InviteCode = preload("res://scripts/private_lobby_code.gd")
const MISSION := "res://data/veyra.json"
const CONFIG := {"mission":"veyra","faction":"forge","difficulty":"easy","tech_level":0,"game_version":"0.36.12"}
const INVITE_SECRET := "00112233445566778899AABBCCDDEEFF"

var session: OnlineSession
var probe: Node
var sim: Simulation
var mode := ""
var port := 24651
var game_started := false
var test_unit_id := 0
var snapshots := 0
var reports := 0
var expected: Dictionary = {}
var saw_hold := false
var saw_move := false
var saw_stop := false
var moved := false
var initial_position := Vector2.ZERO
var previous_time := -1.0
var reconnecting := false
var reconnected := false
var restarted := false
var finish_requested := false
var verified_restart_command := false
var restart_command_sent := false
var bad_invite_rejected := false
var valid_invite_attempted := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode=str(args[0]) if not args.is_empty() else ""
	if args.size()>1: port=int(args[1])
	call_deferred("run")

func make_sim() -> void:
	sim=GameSimulation.new(CatalogData.new(MISSION),"forge","easy",0)
	sim.ai_timer=99999
	# Exercise fragmentation well beyond the MTU and the original 78 KB state.
	for index in 80:
		sim.spawn("scout",0,sim.grid.center(Vector2i(9+index%8,40+index/8)),false)
	var units := sim.entities.values().filter(func(e):return int(e.owner)==0 and not bool(e.building))
	test_unit_id=int(units[0].id)
	initial_position=sim.entities[test_unit_id].pos

func run() -> void:
	make_sim()
	session=Session.new()
	session.name="OnlineSession"
	session.local_game_version="0.36.12"
	root.add_child(session)
	# A separate node provides test-only state reports over the real ENet peer.
	probe=Node.new()
	probe.set_script(load("res://tests/network_roundtrip_probe.gd"))
	probe.name="NetworkProbe"
	probe.report_received.connect(_on_report)
	probe.finished.connect(_on_finished)
	root.add_child(probe)
	session.status_changed.connect(func(message):print(mode.to_upper()," STATUS: ",message))
	if mode=="host":
		var result := session.host(port)
		if result!=OK: fail("host failed: %d"%result); return
		session.required_invite_secret=INVITE_SECRET
		session.set_authority(sim)
		session.configure_lobby(CONFIG)
		session.status_changed.connect(_on_host_status)
	else:
		session.game_start_received.connect(_on_game_start)
		session.world_snapshot_received.connect(_on_snapshot)
		session.command_rejected.connect(func(message):fail(message))
		session.status_changed.connect(func(message):
			if message.contains("Einladungscode ungültig"): bad_invite_rejected=true)
		if session.join("127.0.0.1",port,"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")!=OK: fail("invalid invite attempt failed to start"); return
	for frame in 1500:
		if mode=="host":
			sim.tick(1.0/30.0)
			var before := session.snapshot_sequence
			session.advance_host(1.0/30.0,sim)
			if expected.size()>2: fail("snapshot queue grew while client polling was stalled"); return
			if session.snapshot_sequence>before:
				var key := "%d:%d"%[session.mission_sequence,session.snapshot_sequence]
				expected[key]=state_hash(sim.snapshot())
			if reports>=12 and saw_hold and saw_move and saw_stop and moved and restarted and verified_restart_command and session.last_remote_sequence>=1 and not finish_requested:
				finish_requested=true
				probe.rpc_id(session.client_peer_id,"finish")
				# Leave time for the client's final confirmation before closing ENet.
			if probe.confirmed:
				print("NETWORK ROUNDTRIP HOST: %d matching snapshots; hold/move/stop, reconnect and mission restart passed"%reports)
				session.leave(false)
				quit(0); return
		else:
			if mode=="client" and bad_invite_rejected and not valid_invite_attempted:
				valid_invite_attempted=true
				var invite := InviteCode.decode(InviteCode.encode("127.0.0.1",INVITE_SECRET,port))
				if not bool(invite.get("ok",false)): fail("valid invite code did not decode"); return
				if session.join(str(invite.address),int(invite.port),str(invite.secret))!=OK: fail("valid invite join failed to start"); return
			if reconnecting:
				reconnecting=false
				session.leave(false)
				game_started=false; previous_time=-1.0
				await create_timer(0.4).timeout
				if session.join("127.0.0.1",port,INVITE_SECRET)!=OK: fail("rejoin failed"); return
		await create_timer(1.0/30.0).timeout
	fail("timed out: snapshots=%d reports=%d hold=%s move=%s stop=%s moved=%s"%[snapshots,reports,saw_hold,saw_move,saw_stop,moved])

func _on_host_status(message: String) -> void:
	if message.begins_with("Mitspieler verbunden") and not session.mission_started:
		session.begin_mission(CONFIG)

func _on_game_start(_config: Dictionary) -> void:
	make_sim()
	game_started=true
	previous_time=-1.0

# restore deliberately drops pending host pathfinding jobs; the client never ticks.
func state_hash(snapshot: Dictionary) -> String:
	var copy := snapshot.duplicate(true)
	for entity in copy.entities: entity.path_pending=false
	return Protocol.state_hash(copy)

func _on_snapshot(snapshot: Dictionary) -> void:
	if not game_started: fail("snapshot arrived before mission initialization"); return
	if float(snapshot.time)<previous_time: fail("snapshot time moved backwards"); return
	previous_time=float(snapshot.time)
	if sim.restore(snapshot)!=OK: fail("client rejected snapshot"); return
	var received_hash := state_hash(snapshot)
	var restored_hash := state_hash(sim.snapshot())
	if received_hash!=restored_hash:
		fail("restored state differs from received state"); return
	snapshots+=1
	var unit: Dictionary=sim.entities[test_unit_id]
	var order := str(unit.order)
	probe.rpc_id(1,"report",session.mission_sequence,session.last_snapshot_sequence,received_hash,order,unit.pos.distance_to(initial_position)>1.0)
	if not reconnected:
		if snapshots==1:
			if var_to_bytes(snapshot).size()<100000: fail("large snapshot fixture is too small"); return
			if not session.send_command({"type":"hold","owner_id":0,"ids":[test_unit_id]}): fail("hold was not sent")
		elif snapshots==3:
			var goal := initial_position+Vector2(100,0)
			if not session.send_command({"type":"move","owner_id":0,"ids":[test_unit_id],"point":[goal.x,goal.y]}): fail("move was not sent")
		elif snapshots==6:
			if not session.send_command({"type":"stop","owner_id":0,"ids":[test_unit_id]}): fail("stop was not sent")
		elif snapshots==8:
			reconnected=true; reconnecting=true
	if snapshots==7: stall_client_polling()
	if snapshots==9:
		if not session.send_command({"type":"hold","owner_id":0,"ids":[test_unit_id]}): fail("command after reconnect was not sent")
	if session.mission_sequence>=2 and not restart_command_sent:
		restart_command_sent=true
		var stale := Protocol.create_command(session.session_id,1,1,session.host_tick+15,{"type":"hold","owner_id":0,"ids":[test_unit_id]})
		stale["mission_sequence"]=session.mission_sequence-1
		session.rpc_id(1,"receive_command_request",stale)
		if not session.send_command({"type":"stop","owner_id":0,"ids":[test_unit_id]}): fail("command after restart was not sent")
	print("CLIENT VERIFIED snapshot=%d mission=%d time=%.3f bytes=%d"%[snapshots,session.mission_sequence,sim.time,var_to_bytes(snapshot).size()])

func stall_client_polling() -> void:
	# Withhold delivery/ACKs for several snapshot intervals, like a stalled link.
	multiplayer_poll=false
	await create_timer(0.9).timeout
	multiplayer_poll=true

func _on_report(mission: int, sequence: int, hash_value: String, order: String, position_changed: bool) -> void:
	var key := "%d:%d"%[mission,sequence]
	if not expected.has(key) or expected[key]!=hash_value: fail("host/client state mismatch at "+key); return
	expected.erase(key)
	reports+=1
	verified_restart_command=verified_restart_command or (mission==2 and order=="stop")
	saw_hold=saw_hold or order=="hold"
	saw_move=saw_move or order=="move"
	saw_stop=saw_stop or order=="stop"
	moved=moved or position_changed
	if reports==10 and not restarted:
		restarted=true
		make_sim()
		session.set_authority(sim)
		session.begin_mission(CONFIG)

func _on_finished() -> void:
	print("NETWORK ROUNDTRIP CLIENT: %d snapshots restored and confirmed"%snapshots)
	# The SceneTree stays alive to deliver the reliable finish acknowledgement.
	await create_timer(0.3).timeout
	session.leave(false)
	quit(0)

func fail(message: String) -> void:
	push_error("NETWORK ROUNDTRIP: "+message)
	quit(1)
