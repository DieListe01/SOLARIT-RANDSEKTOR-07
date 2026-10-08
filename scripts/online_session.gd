extends Node
class_name OnlineSession

signal status_changed(message: String)
signal game_start_received(config: Dictionary)
signal world_snapshot_received(snapshot: Dictionary)
signal command_rejected(message: String)
signal lobby_changed
signal chat_received(sender: String, message: String)
signal rematch_received
signal connection_lost
signal match_report_received(report: Dictionary)

const DEFAULT_PORT := 2456
const MAX_CLIENTS := 1
const SNAPSHOT_INTERVAL := 0.25
const PROTOCOL := preload("res://scripts/network_protocol.gd")
const PROFILE := preload("res://scripts/player_profile.gd")

var role := ""
var active := false
var connected := false
var session_id := ""
var client_peer_id := 0
var command_sequence := 0
var host_tick := 0
var snapshot_elapsed := 0.0
var last_remote_sequence := 0
# A single acknowledged snapshot bounds the reliable send queue on slow links.
var mission_sequence := 0
var mission_started := false
var client_ready := false
var snapshot_sequence := 0
var last_snapshot_sequence := 0
var pending_snapshot_sequence := 0
var mission_config: Dictionary = {}
var host_ready := false
var guest_ready := false
var ready_request_pending := false
var ready_request_value := false
var ping_ms := -1
var ping_elapsed := 0.0
var last_snapshot_at := 0
var chat_history: Array = []
var last_chat_at := -1000
var last_remote_chat_at := -1000
var reconnect_address := ""
var reconnect_port := DEFAULT_PORT
var local_game_version := ""
var required_invite_secret := ""
var join_invite_secret := ""
var pending_auth_challenges: Dictionary = {}
var auth_failures_by_ip: Dictionary = {}
var identity_session_sent := ""
var authority_sim: Simulation

const PRIVATE_INVITE_CODE := preload("res://scripts/private_lobby_code.gd")

static func game_versions_match(host_version: String, client_version: String) -> bool:
	var numeric_version := RegEx.new()
	if numeric_version.compile("^\\d+\\.\\d+\\.\\d+$") != OK: return false
	return numeric_version.search(host_version) != null and host_version == client_version

func is_host() -> bool:
	return active and role == "host"

func is_client() -> bool:
	return active and role == "client"

func host(port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port,MAX_CLIENTS)
	if result != OK: return result
	multiplayer.multiplayer_peer=peer
	role="host"; active=true; connected=false
	session_id=_new_session_id()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status_changed.emit("Lobby offen · UDP-Port %d · warte auf Mitspieler"%port)
	return OK

func join(address: String, port: int = DEFAULT_PORT, invite_secret: String = "") -> Error:
	leave(false)
	if address.strip_edges().is_empty(): return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(),port)
	if result != OK: return result
	multiplayer.multiplayer_peer=peer
	reconnect_address=address.strip_edges(); reconnect_port=port
	role="client"; active=true; connected=false; command_sequence=0; join_invite_secret=invite_secret
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	status_changed.emit("Verbinde mit %s:%d …"%[address.strip_edges(),port])
	return OK

func leave(show_status: bool = true) -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected): multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected): multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server): multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed): multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected): multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.multiplayer_peer!=null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer=null
	role=""; active=false; connected=false; client_peer_id=0
	session_id=""; command_sequence=0; host_tick=0; last_remote_sequence=0
	mission_config.clear(); authority_sim=null
	required_invite_secret=""; join_invite_secret=""; pending_auth_challenges.clear(); auth_failures_by_ip.clear()
	identity_session_sent=""
	mission_sequence=0; mission_started=false; client_ready=false
	snapshot_sequence=0; last_snapshot_sequence=0; pending_snapshot_sequence=0
	snapshot_elapsed=0.0
	host_ready=false; guest_ready=false; ready_request_pending=false; ping_ms=-1; last_snapshot_at=0; ping_elapsed=0.0
	chat_history.clear(); last_chat_at=-1000; last_remote_chat_at=-1000
	if show_status: status_changed.emit("Online-Verbindung getrennt")

func is_versus() -> bool:
	return str(mission_config.get("mode","coop"))=="versus"

func local_owner() -> int:
	return 1 if is_client() and is_versus() else 0

func can_start() -> bool:
	return is_host() and connected and host_ready and guest_ready

func begin_mission(config: Dictionary) -> void:
	if not is_host(): return
	mission_config=normalize_config(config)
	announce_system("Einsatz wird gestartet.")
	mission_sequence+=1; mission_started=true; client_ready=false; last_remote_sequence=0
	pending_snapshot_sequence=0; snapshot_elapsed=SNAPSHOT_INTERVAL
	if connected:
		rpc_id(client_peer_id,"receive_game_start",session_id,mission_sequence,mission_config)

func send_match_report(report: Dictionary) -> void:
	if not is_host() or not connected or not mission_started or report.is_empty(): return
	rpc_id(client_peer_id,"receive_match_report",session_id,mission_sequence,report.duplicate(true))

func set_authority(simulation: Simulation) -> void:
	authority_sim=simulation

func send_command(command: Dictionary) -> bool:
	if not is_client() or not connected or not client_ready or last_snapshot_sequence==0 or session_id.is_empty(): return false
	command_sequence+=1
	var packet: Dictionary=PROTOCOL.create_command(session_id,1,command_sequence,command_target_tick(),command)
	packet["mission_sequence"]=mission_sequence
	rpc_id(1,"receive_command_request",packet)
	return true

func command_lead_ticks() -> int:
	var snapshot_age_ms:= maxi(0,Time.get_ticks_msec()-last_snapshot_at) if last_snapshot_at>0 else 0
	var round_trip_ms:=maxi(0,ping_ms)
	var observed_delay_ticks:=ceili(float(snapshot_age_ms+round_trip_ms)*PROTOCOL.TICKS_PER_SECOND/1000.0)
	return clampi(15+observed_delay_ticks,15,PROTOCOL.MAX_FUTURE_TICKS)

func command_target_tick() -> int:
	return host_tick+command_lead_ticks()

func submit_local_host_command(command: Dictionary) -> bool:
	if not is_host() or authority_sim==null: return false
	return authority_sim.submit_command(command,0)

func advance_host(dt: float, simulation: Simulation) -> void:
	if not is_host(): return
	authority_sim=simulation
	host_tick=roundi(simulation.time*PROTOCOL.TICKS_PER_SECOND)
	if not connected or not mission_started or not client_ready: return
	snapshot_elapsed=minf(snapshot_elapsed+dt,SNAPSHOT_INTERVAL)
	if snapshot_elapsed<SNAPSHOT_INTERVAL or pending_snapshot_sequence!=0: return
	snapshot_elapsed=0.0
	snapshot_sequence+=1
	pending_snapshot_sequence=snapshot_sequence
	rpc_id(client_peer_id,"receive_world_snapshot",session_id,mission_sequence,snapshot_sequence,simulation.snapshot_for(1) if is_versus() else simulation.snapshot())

func configure_lobby(config: Dictionary) -> void:
	if not is_host(): return
	var previous := mission_config.duplicate(true)
	mission_config=normalize_config(config)
	host_ready=false; guest_ready=false
	if previous.is_empty(): announce_system("Lobby eröffnet · Einsatzgruppe bereit.")
	else:
		if previous.get("mission", "") != mission_config.get("mission", ""): announce_system("Einsatzkarte geändert.")
		if previous.get("host_faction", "") != mission_config.get("host_faction", ""): announce_system(str(mission_config.host_nickname) + " hat die Fraktion geändert.")
		if previous.get("client_faction", "") != mission_config.get("client_faction", ""): announce_system(str(mission_config.client_nickname) + " hat die Fraktion geändert.")
	broadcast_lobby()

func _on_peer_connected(peer_id: int) -> void:
	if not is_host(): return
	var remote_address: String = multiplayer.multiplayer_peer.get_peer(peer_id).get_remote_address()
	var lockout: Dictionary = auth_failures_by_ip.get(remote_address,{})
	if int(lockout.get("blocked_until",0)) > Time.get_ticks_msec():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	if client_peer_id!=0 and client_peer_id!=peer_id:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	client_peer_id=peer_id; connected=false
	if not required_invite_secret.is_empty():
		var challenge := Crypto.new().generate_random_bytes(16).hex_encode().to_lower()
		pending_auth_challenges[peer_id] = challenge
		rpc_id(peer_id,"request_private_lobby_auth",session_id,challenge)
		return
	_accept_peer_connection(peer_id)

func _accept_peer_connection(peer_id: int) -> void:
	if not is_host() or peer_id != client_peer_id: return
	connected=true; last_remote_sequence=0
	client_ready=false; pending_snapshot_sequence=0; guest_ready=false
	rpc_id(peer_id,"receive_lobby_offer",session_id,PROTOCOL.VERSION,mission_config)
	rpc_id(peer_id,"receive_chat_history",session_id,chat_history)
	if mission_started:
		snapshot_elapsed=SNAPSHOT_INTERVAL
		rpc_id(peer_id,"receive_game_start",session_id,mission_sequence,mission_config)
	status_changed.emit("Mitspieler verbunden · 1:1-Duell" if is_versus() else "Mitspieler verbunden · gemeinsam gegen die KI")
	announce_system(str(mission_config.get("client_nickname", "Mitspieler")) + " ist der Einsatzgruppe beigetreten.")
	broadcast_lobby()

func _on_peer_disconnected(peer_id: int) -> void:
	pending_auth_challenges.erase(peer_id)
	if peer_id!=client_peer_id: return
	client_peer_id=0; connected=false; last_remote_sequence=0
	client_ready=false; pending_snapshot_sequence=0
	guest_ready=false; ping_ms=-1
	status_changed.emit("Mitspieler getrennt · Duell wartet auf Wiederverbindung" if is_versus() else "Mitspieler getrennt · Host kann lokal fortfahren")
	announce_system("Mitspieler hat die Verbindung verloren.")
	lobby_changed.emit()

func _on_connected_to_server() -> void:
	connected=false
	status_changed.emit("Verbindung aufgebaut · Lobby-Passwort wird geprüft")

func _on_connection_failed() -> void:
	leave(false)
	status_changed.emit("Verbindung fehlgeschlagen · Adresse, Port und Firewall prüfen")

func _on_server_disconnected() -> void:
	connection_lost.emit()
	leave(false)
	status_changed.emit("Host nicht mehr erreichbar · Online-Partie beendet")

@rpc("authority","call_remote","reliable",0)
func request_private_lobby_auth(remote_session: String, challenge: String) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1 or not PROTOCOL.valid_session_id(remote_session): return
	if challenge.length()!=32 or not _is_hex_string(challenge): return
	var proof := PRIVATE_INVITE_CODE.make_proof(join_invite_secret,challenge) if join_invite_secret.length() in [32,64] else ""
	rpc_id(1,"submit_private_lobby_auth",remote_session,proof)

@rpc("any_peer","call_remote","reliable",0)
func submit_private_lobby_auth(remote_session: String, proof: String) -> void:
	if not is_host() or remote_session!=session_id: return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id!=client_peer_id or not pending_auth_challenges.has(peer_id): return
	var challenge := str(pending_auth_challenges[peer_id])
	pending_auth_challenges.erase(peer_id)
	if not PRIVATE_INVITE_CODE.proof_matches(required_invite_secret,challenge,proof):
		var remote_address: String = multiplayer.multiplayer_peer.get_peer(peer_id).get_remote_address()
		var now := Time.get_ticks_msec()
		var failures: Dictionary = auth_failures_by_ip.get(remote_address,{"count":0,"window_started":now,"blocked_until":0})
		if now - int(failures.get("window_started",now)) > 300000:
			failures={"count":0,"window_started":now,"blocked_until":0}
		failures.count=int(failures.get("count",0))+1
		if int(failures.count) >= 5:
			failures.blocked_until=now+600000
		auth_failures_by_ip[remote_address]=failures
		rpc_id(peer_id,"receive_private_lobby_auth_result",session_id,false,"Passwort falsch · Zugang abgelehnt")
		return
	_accept_peer_connection(peer_id)

@rpc("authority","call_remote","reliable",0)
func receive_private_lobby_auth_result(remote_session: String, accepted: bool, message: String) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1 or not PROTOCOL.valid_session_id(remote_session): return
	if accepted: return
	leave(false)
	status_changed.emit(message if not message.is_empty() else "Einladungscode ungültig · Zugang abgelehnt")

func _is_hex_string(value: String) -> bool:
	for character in value.to_upper():
		if "0123456789ABCDEF".find(character)<0: return false
	return true

@rpc("any_peer","call_remote","reliable")
func receive_command_request(packet: Variant) -> void:
	if not is_host() or not client_ready or authority_sim==null: return
	var sender := multiplayer.get_remote_sender_id()
	if sender!=client_peer_id: return
	if not packet is Dictionary or packet.get("mission_sequence",-1)!=mission_sequence: return
	var owner_map := {1:1 if is_versus() else 0}
	var checked: Dictionary=PROTOCOL.validate_command(packet,session_id,host_tick,last_remote_sequence,[1],owner_map)
	# Consume a correctly sequenced request even when rejected; otherwise one
	# stale command would permanently block every subsequent reliable command.
	if packet.get("session_id","")==session_id and packet.get("protocol_version",-1)==PROTOCOL.VERSION and packet.get("player_id",-1)==1 and PROTOCOL.is_integer(packet.get("sequence")) and int(packet.sequence)==last_remote_sequence+1:
		last_remote_sequence=int(packet.sequence)
	if not bool(checked.get("ok",false)):
		rpc_id(sender,"receive_command_result",int(packet.get("sequence",0)) if packet is Dictionary else 0,false,str(checked.get("reason","COMMAND_REJECTED")))
		return
	last_remote_sequence=int(checked.sequence)
	var accepted := authority_sim.submit_command(checked.command,int(owner_map[1]))
	rpc_id(sender,"receive_command_result",int(checked.sequence),accepted,"ACCEPTED" if accepted else "COMMAND_REJECTED")

@rpc("authority","call_remote","reliable",2)
func receive_lobby_offer(remote_session: String, protocol_version: int, config: Dictionary) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1: return
	if protocol_version!=PROTOCOL.VERSION or not PROTOCOL.valid_session_id(remote_session):
		leave(false); status_changed.emit("Protokollversion stimmt nicht überein")
		return
	var host_version := str(config.get("game_version", ""))
	if not game_versions_match(host_version, local_game_version):
		leave(false)
		status_changed.emit("Versionskonflikt · Host nutzt %s, installiert ist %s" % [host_version if not host_version.is_empty() else "unbekannt", local_game_version])
		return
	session_id=remote_session; connected=true; mission_config=config.duplicate(true)
	status_changed.emit("Lobby verbunden · wähle Fraktion und bestätige Bereit")
	lobby_changed.emit()

@rpc("authority","call_remote","reliable",2)
func receive_game_start(remote_session: String, remote_mission: int, config: Dictionary) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1 or remote_session!=session_id: return
	if remote_mission<=mission_sequence: return
	mission_sequence=remote_mission; mission_started=true; client_ready=false
	last_snapshot_sequence=0; host_tick=0; command_sequence=0
	mission_config=config.duplicate(true)
	game_start_received.emit(mission_config)
	# Signal handlers initialize the client simulation synchronously.
	if not is_client(): return
	client_ready=true
	rpc_id(1,"receive_mission_ready",session_id,mission_sequence)

@rpc("any_peer","call_remote","reliable",2)
func receive_mission_ready(remote_session: String, remote_mission: int) -> void:
	if not is_host() or multiplayer.get_remote_sender_id()!=client_peer_id: return
	if remote_session!=session_id or remote_mission!=mission_sequence or not mission_started: return
	client_ready=true
	snapshot_elapsed=SNAPSHOT_INTERVAL

@rpc("authority","call_remote","reliable",2)
func receive_world_snapshot(remote_session: String, remote_mission: int, sequence: int, snapshot: Dictionary) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1 or remote_session!=session_id: return
	if not client_ready or remote_mission!=mission_sequence or sequence<=last_snapshot_sequence: return
	host_tick=roundi(float(snapshot.get("time",0.0))*PROTOCOL.TICKS_PER_SECOND)
	last_snapshot_sequence=sequence; last_snapshot_at=Time.get_ticks_msec()
	world_snapshot_received.emit(snapshot)
	if is_client():
		rpc_id(1,"receive_snapshot_ack",session_id,mission_sequence,sequence)

@rpc("authority","call_remote","reliable",2)
func receive_match_report(remote_session: String, remote_mission: int, report: Dictionary) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1 or remote_session!=session_id: return
	if remote_mission!=mission_sequence or str(report.get("match_id", ""))!="online:"+session_id+":"+str(mission_sequence): return
	match_report_received.emit(report.duplicate(true))

@rpc("any_peer","call_remote","reliable",2)
func receive_snapshot_ack(remote_session: String, remote_mission: int, sequence: int) -> void:
	if not is_host() or multiplayer.get_remote_sender_id()!=client_peer_id: return
	if remote_session!=session_id or remote_mission!=mission_sequence: return
	if sequence==pending_snapshot_sequence: pending_snapshot_sequence=0

@rpc("authority","call_remote","reliable")
func receive_command_result(sequence: int, accepted: bool, reason: String) -> void:
	if not is_client() or multiplayer.get_remote_sender_id()!=1: return
	if not accepted: command_rejected.emit("Befehl abgelehnt (%d): %s"%[sequence,reason])

func _new_session_id() -> String:
	var random := RandomNumberGenerator.new()
	random.randomize()
	var alphabet := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
	var result := ""
	for index in 24: result+=alphabet.substr(random.randi_range(0,alphabet.length()-1),1)
	return result


const COLORS := ["19ddd4","f34c32","b967ef","408bf4","f1c744","74ce47","f478bf","eee0bc"]
const FACTIONS := ["forge","drift","lumen"]

static func normalize_config(config: Dictionary) -> Dictionary:
	var clean:=config.duplicate(true)
	clean.mode="versus" if str(clean.get("mode","coop"))=="versus" else "coop"
	for nick_key in ["host_nickname", "client_nickname"]:
		clean[nick_key] = PROFILE.sanitize_network_nickname(str(clean.get(nick_key, "Kommandant")))
	for prefix in ["host","client"]:
		var faction:=str(clean.get(prefix+"_faction","forge" if prefix=="host" else "drift"))
		clean[prefix+"_faction"]=faction if faction in FACTIONS else "forge"
		var color:=str(clean.get(prefix+"_color",COLORS[0] if prefix=="host" else COLORS[1]))
		clean[prefix+"_color"]=color if color in COLORS else COLORS[0]
	if clean.host_color==clean.client_color:
		clean.client_color=COLORS[(COLORS.find(clean.host_color)+1)%COLORS.size()]
	clean.start_credits=clampi(int(clean.get("start_credits",4200)),2000,10000)
	return clean

func broadcast_lobby() -> void:
	lobby_changed.emit()
	if is_host() and connected:
		rpc_id(client_peer_id,"receive_lobby_offer",session_id,PROTOCOL.VERSION,mission_config)
		rpc_id(client_peer_id,"receive_ready_state",session_id,host_ready,guest_ready)

func set_ready(value: bool) -> void:
	if not active or mission_started: return
	if is_host():
		if host_ready == value: return
		host_ready=value
		announce_system(str(mission_config.get("host_nickname", "Host")) + (" ist bereit." if value else " hat die Bereitschaft zurückgenommen."))
		broadcast_lobby()
	elif connected and (not ready_request_pending or ready_request_value != value):
		ready_request_pending=true
		ready_request_value=value
		rpc_id(1,"receive_ready_request",session_id,value)

func sanitize_nickname(raw: String) -> String:
	var value := raw.strip_edges().left(20)
	if value.length() < 2: return "Kommandant"
	var allowed := RegEx.new()
	if allowed.compile("^[\\p{L}\\p{N} _-]+$") != OK or allowed.search(value) == null: return "Kommandant"
	return value

func set_nickname(nickname: String) -> void:
	var safe := sanitize_nickname(nickname)
	if not active or mission_config.is_empty(): return
	if is_host():
		if str(mission_config.get("host_nickname", "")) == safe: return
		mission_config.host_nickname = safe
		broadcast_lobby()
	elif connected and str(mission_config.get("client_nickname", "")) != safe:
		rpc_id(1, "request_nickname", session_id, safe)

@rpc("any_peer", "call_remote", "reliable", 2)
func request_nickname(remote_session: String, nickname: String) -> void:
	if not is_host() or remote_session != session_id or multiplayer.get_remote_sender_id() != client_peer_id: return
	var safe := sanitize_nickname(nickname)
	if str(mission_config.get("client_nickname", "")) == safe: return
	mission_config.client_nickname = safe
	broadcast_lobby()

func announce_system(message: String) -> void:
	if is_host(): publish_chat("SYSTEM", clean_chat(message))

func set_profile(faction: String, color: String) -> void:
	if mission_started or faction not in FACTIONS or color not in COLORS: return
	if is_host():
		var config:=mission_config.duplicate(true)
		config.host_faction=faction; config.host_color=color
		configure_lobby(config)
	elif connected: rpc_id(1,"request_profile",session_id,faction,color)

@rpc("any_peer","call_remote","reliable",2)
func request_profile(remote_session: String, faction: String, color: String) -> void:
	if not is_host() or mission_started or remote_session!=session_id or multiplayer.get_remote_sender_id()!=client_peer_id: return
	if faction not in FACTIONS or color not in COLORS: return
	var config:=mission_config.duplicate(true)
	config.client_faction=faction; config.client_color=color
	configure_lobby(config)

@rpc("any_peer","call_remote","reliable",2)
func receive_ready_request(remote_session: String, value: bool) -> void:
	if not is_host() or mission_started or remote_session!=session_id or multiplayer.get_remote_sender_id()!=client_peer_id: return
	if guest_ready == value: return
	guest_ready=value
	announce_system(str(mission_config.get("client_nickname", "Mitspieler")) + (" ist bereit." if value else " hat die Bereitschaft zurückgenommen."))
	broadcast_lobby()

@rpc("authority","call_remote","reliable",2)
func receive_ready_state(remote_session: String, host_value: bool, guest_value: bool) -> void:
	if not is_client() or remote_session!=session_id: return
	host_ready=host_value; guest_ready=guest_value
	if ready_request_pending and guest_ready == ready_request_value: ready_request_pending=false
	lobby_changed.emit()

static func clean_chat(message: String) -> String:
	var clean:=""
	for character in message:
		if character.unicode_at(0)>=32 and character.unicode_at(0)!=127: clean+=character
	return clean.strip_edges().left(300)

func send_chat(message: String) -> bool:
	var clean:=clean_chat(message)
	var now:=Time.get_ticks_msec()
	if not active or clean.is_empty() or now-last_chat_at<500: return false
	last_chat_at=now
	if is_host(): publish_chat(str(mission_config.get("host_nickname", "Host")),clean)
	elif connected and not session_id.is_empty(): rpc_id(1,"request_chat",session_id,clean)
	else: return false
	return true

func publish_chat(sender: String, message: String) -> void:
	append_chat(sender,message)
	if connected: rpc_id(client_peer_id,"receive_chat",session_id,sender,message)

func append_chat(sender: String, message: String) -> void:
	chat_history.append({"sender":sender,"message":message,"time":Time.get_time_string_from_system().substr(0,5)})
	while chat_history.size()>50: chat_history.pop_front()
	chat_received.emit(sender,message)

@rpc("any_peer","call_remote","reliable",1)
func request_chat(remote_session: String, message: String) -> void:
	if not is_host() or remote_session!=session_id or multiplayer.get_remote_sender_id()!=client_peer_id: return
	var now:=Time.get_ticks_msec()
	if now-last_remote_chat_at<500: return
	var clean:=clean_chat(message)
	if clean.is_empty(): return
	last_remote_chat_at=now
	publish_chat(str(mission_config.get("client_nickname", "Mitspieler")),clean)

@rpc("authority","call_remote","reliable",1)
func receive_chat(remote_session: String, sender: String, message: String) -> void:
	if not is_client() or remote_session!=session_id: return
	append_chat(sender,clean_chat(message))

func request_rematch() -> void:
	if not active or not mission_started: return
	if is_host(): reset_for_rematch()
	elif connected: rpc_id(1,"receive_rematch_request",session_id)

@rpc("any_peer","call_remote","reliable",2)
func receive_rematch_request(remote_session: String) -> void:
	if not is_host() or remote_session!=session_id or multiplayer.get_remote_sender_id()!=client_peer_id: return
	if authority_sim!=null and authority_sim.result!="": reset_for_rematch()

func reset_for_rematch() -> void:
	if authority_sim==null or authority_sim.result=="": return
	mission_started=false; client_ready=false; pending_snapshot_sequence=0
	host_ready=false; guest_ready=false
	if connected: rpc_id(client_peer_id,"receive_rematch",session_id)
	rematch_received.emit()
	broadcast_lobby()

@rpc("authority","call_remote","reliable",2)
func receive_rematch(remote_session: String) -> void:
	if not is_client() or remote_session!=session_id: return
	mission_started=false; client_ready=false
	host_ready=false; guest_ready=false
	rematch_received.emit()

func _process(dt: float) -> void:
	if not active or not connected or session_id.is_empty(): return
	ping_elapsed+=dt
	if ping_elapsed<1.0: return
	ping_elapsed=0.0
	rpc_id(client_peer_id if is_host() else 1,"receive_ping",session_id,Time.get_ticks_msec())

@rpc("any_peer","call_remote","unreliable",4)
func receive_ping(remote_session: String, stamp: int) -> void:
	var sender:=multiplayer.get_remote_sender_id()
	if remote_session!=session_id or sender!=(client_peer_id if is_host() else 1): return
	rpc_id(sender,"receive_pong",remote_session,stamp)

@rpc("any_peer","call_remote","unreliable",4)
func receive_pong(remote_session: String, stamp: int) -> void:
	if remote_session!=session_id or multiplayer.get_remote_sender_id()!=(client_peer_id if is_host() else 1): return
	ping_ms=maxi(0,Time.get_ticks_msec()-stamp)


@rpc("authority","call_remote","reliable",2)
func receive_chat_history(remote_session: String, entries: Array) -> void:
	if not is_client() or remote_session!=session_id or entries.size()>50: return
	chat_history.clear()
	for entry in entries:
		if entry is Dictionary and entry.get("sender","") is String and entry.get("message") is String:
			var sender := "SYSTEM" if str(entry.sender) == "SYSTEM" else sanitize_nickname(str(entry.sender))
			append_chat(sender,clean_chat(str(entry.message)))
			if entry.get("time", "") is String and not str(entry.get("time", "")).is_empty(): chat_history[-1].time = str(entry.time).left(5)
