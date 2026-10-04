extends SceneTree

var game: Control
var surface: SubViewport
var probe: Node
var mode := ""
var port := 24652
var snapshots := 0
var reports := 0
var authoritative_report_received := false
var profile_sent := false
var chat_sent := false
var commands_sent := false
var build_sent := false
var rejected := false
var ending := false
var rematching := false
var second_started := false
var finishing := false
var reconnecting := false
var reconnected := false
var guest_reconnected := false
var own_unit_id := 0
var checks := 0

func check(value: bool, message: String) -> bool:
	checks+=1
	if not value: push_error("NETWORK GAME: "+message); quit(1)
	return value

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	mode=str(args[0]); port=int(args[1])
	call_deferred("run")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	surface=SubViewport.new(); surface.name="TestSurface"
	# Network assertions inspect scene state; draw the large test viewport only for captures.
	# Continuous software rendering on hosted CI can otherwise delay command delivery.
	surface.size=Vector2i(1920,1080); surface.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(surface); surface.add_child(game)
	game.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	game.commander_profile.path = "user://network_profile_" + mode + ".json"
	game.commander_profile.load_profile()
	game.commander_profile.set_nickname("DIRK" if mode == "host" else "RAVEN")
	game.online.match_report_received.connect(func(report: Dictionary):
		authoritative_report_received=int(report.get("schema_version",0))==1 and report.get("sides",[]).size()==2 and report.get("samples",[]).size()>0
	)
	game.show_main_menu()
	game.show_online_menu()
	probe=Node.new(); probe.name="NetworkProbe"
	probe.set_script(load("res://tests/network_game_probe.gd"))
	probe.report_received.connect(func(_mission,_sequence,_hash,_order,moved):reports+=1; guest_reconnected=guest_reconnected or moved)
	probe.finished.connect(finish_client)
	root.add_child(probe)
	game.online.command_rejected.connect(func(message):
		if message.contains("OWNER_MISMATCH"): rejected=true
		else: check(false,"unexpected rejection: "+message))
	if mode=="host":
		if not check(game.online.host(port)==OK,"host opens"): return
		var config: Dictionary=game.online_mission_config()
		config.mode="versus"; config.start_credits=6000
		game.online.configure_lobby(config)
	else:
		game.online.world_snapshot_received.connect(on_snapshot)
		if not check(game.online.join("127.0.0.1",port)==OK,"client joins"): return
	game.show_online_menu()
	for frame in 2400:
		if mode=="client" and finishing: return
		if mode=="client" and reconnecting:
			reconnecting=false
			game.online.leave(false)
			await create_timer(0.3).timeout
			if not check(game.online.join("127.0.0.1",port)==OK,"duel reconnect"): return
			reconnected=true
		var online: OnlineSession=game.online
		if frame%200==0:
			print("GAME PHASE %s connected=%s started=%s mission=%d snapshots=%d reports=%d ending=%s rematch=%s guest_reconnected=%s ping=%d"%[mode,online.connected,online.mission_started,online.mission_sequence,snapshots,reports,ending,rematching,guest_reconnected,online.ping_ms])
		if online.connected and not online.mission_started:
			if mode=="client":
				if not online.session_id.is_empty() and not profile_sent:
					profile_sent=true; online.set_profile("lumen","f1c744")
				if online.mission_config.get("client_faction","")=="lumen" and not online.guest_ready: online.set_ready(true)
				if not online.session_id.is_empty() and not chat_sent:
					chat_sent=online.send_chat("[b]Hallo vom Mitspieler[/b]")
			else:
				if not online.host_ready: online.set_ready(true)
				if online.guest_ready and not chat_sent: chat_sent=online.send_chat("Hallo vom Host")
				if online.can_start() and online.chat_history.size()>=2:
					if not check(str(online.mission_config.get("host_nickname", "")) == "DIRK" and str(online.mission_config.get("client_nickname", "")) == "RAVEN", "global commander identities are shared in the lobby"): return
					if not check(game.overlay.get_node("OnlineLobbyPanel").get_node("OnlineChat").visible,"lobby chat visible"): return
					game.start_game()
					if online.mission_sequence>=2: second_started=true; rematching=true
		if mode=="host" and game.playing and game.sim!=null:
			if not ending and reports>=5 and guest_reconnected and not game.sim.buildings(1,"power",false).is_empty():
				var scout: Dictionary=game.sim.entities.values().filter(func(e):return e.owner==1 and not e.building)[0]
				if str(scout.order)=="hold":
					if not check(game.sim.entities.values().filter(func(e):return e.owner==0 and not e.building)[0].order!="hold","remote spoof did not command host scout"): return
					ending=true; game.sim.destroy(game.sim.buildings(0,"core")[0].id)
			if ending and game.sim.result=="defeat" and not rematching:
				if not check(game.ended,"host end screen"): return
				# The client requests the rematch after receiving its victory.
			if online.mission_sequence>=2 and reports>=8 and not finishing:
				finishing=true; probe.rpc_id(online.client_peer_id,"finish")
			if probe.confirmed:
				print("NETWORK GAME HOST: %d checks; lobby, chat, own commands, outcome and rematch passed"%checks)
				online.leave(false); game.music.shutdown(); game.queue_free(); await process_frame; await create_timer(0.15).timeout; quit(0); return
		if mode=="host" and ending and not online.mission_started: rematching=true
		await create_timer(0.025).timeout
	check(false,"timeout in %s: snapshots=%d reports=%d ending=%s rematch=%s second=%s reconnected=%s"%[mode,snapshots,reports,ending,rematching,second_started,reconnected])

func on_snapshot(snapshot: Dictionary) -> void:
	snapshots+=1
	if not check(game.local_owner()==1 and game.renderer.sim.view_owner==1,"client views player two"): return
	if not check(game.sim.credits[0]==0 and snapshot.entities.all(func(e):return e.owner==1),"rival base hidden"): return
	if not check(game.chat_log.bbcode_enabled==false,"chat text cannot inject formatting"): return
	if not check(game.online.chat_history.size()>=2,"both chat directions delivered"): return
	if not check(game.online.chat_history.any(func(item): return item.sender == "DIRK") and game.online.chat_history.any(func(item): return item.sender == "RAVEN"), "chat attributes messages to persistent commander names"): return
	if not check(game.sim.factions[1]=="lumen" and game.sim.player_colors[1]=="f1c744","guest lobby choices applied"): return
	var scout: Dictionary=game.sim.entities.values().filter(func(e):return e.owner==1 and not e.building)[0]
	own_unit_id=int(scout.id)
	if not commands_sent:
		commands_sent=true
		game.online.send_command({"type":"hold","owner_id":0,"ids":[own_unit_id]})
		game.submit_player_command({"type":"hold","owner_id":1,"ids":[own_unit_id]})
	if snapshots>=2 and not build_sent:
		var core: Dictionary=game.sim.buildings(1,"core")[0]
		for y in range(-6,7):
			for x in range(-6,7):
				var cell: Vector2i=core.cell+Vector2i(x,y)
				if game.sim.build_reason("power",1,cell)=="": 
					build_sent=game.submit_player_command({"type":"build","owner_id":1,"kind":"power","cell":[cell.x,cell.y]})
					break
			if build_sent: break
	probe.rpc_id(1,"report",game.online.mission_sequence,game.online.last_snapshot_sequence,"",str(scout.order),reconnected)
	if snapshots==3: reconnecting=true
	if game.sim.result=="victory" and not rematching:
		rematching=true
		await process_frame
		if not check(rejected and game.ended and game.paused,"client victory screen and rejected spoof: rejected=%s ended=%s paused=%s"%[rejected,game.ended,game.paused]): return
		for attempt in 20:
			if authoritative_report_received: break
			await create_timer(0.025).timeout
		if not check(authoritative_report_received,"host sends the full versioned match report to the duel client"): return
		await create_timer(0.12).timeout
		if DisplayServer.get_name() != "headless":
			surface.render_target_update_mode=SubViewport.UPDATE_ONCE
			game.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			RenderingServer.force_draw(false)
			surface.get_texture().get_image().save_png("res://test-output/network-duel-victory.png")
		game.online.request_rematch()

func finish_client() -> void:
	finishing=true
	if not check(game.sim.result=="" and game.playing and not game.ended and game.online.mission_sequence>=2,"rematch initializes fresh duel"): return
	# Ping is sampled once per second; an immediate rematch may beat its first pong.
	for attempt in 120:
		if game.online.ping_ms>=0: break
		await create_timer(0.025).timeout
	if not check(game.online.ping_ms>=0 and not game.connection_label.text.is_empty(),"ping and sync indicator"): return
	game.toggle_chat()
	await process_frame
	await create_timer(0.12).timeout
	if DisplayServer.get_name() != "headless":
		surface.render_target_update_mode=SubViewport.UPDATE_ONCE
		game.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		RenderingServer.force_draw(false)
		surface.get_texture().get_image().save_png("res://test-output/network-duel-chat.png")
	probe.rpc_id(1,"confirm")
	print("NETWORK GAME CLIENT: %d checks; %d filtered snapshots; chat and rematch verified"%[checks,snapshots])
	await create_timer(0.3).timeout
	game.online.leave(false); game.music.shutdown(); game.queue_free(); await process_frame; await create_timer(0.15).timeout; quit(0)
