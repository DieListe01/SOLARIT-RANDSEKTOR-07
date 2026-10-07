extends Node
class_name OnlineStats

signal status_changed(message: String)
signal highscores_received(mission: String, entries: Array)
signal server_status_changed(message: String, online: bool)
signal public_address_received(address: String, success: bool)

const BASE_URL := "https://api.dl-home.de"
const GAME_ID := "solarit-randsektor-07"
const HEARTBEAT_SECONDS := 45.0
const REQUEST_TIMEOUT_SECONDS := 6.0
const OUTBOX_PATH := "user://online_results_queue.json"
const CLIENT_ID_PATH := "user://online_client_id.txt"
const CLIENT_VERSION := "1"

var profile_id := ""
var base_url := BASE_URL
var outbox_path := OUTBOX_PATH
var nickname := ""
var game_version := "unbekannt"
var client_id := ""
var enabled := true
var playing := false
var heartbeat_elapsed := 0.0
var request: HTTPRequest
var request_active := false
var active_request: Dictionary = {}
var queued_requests: Array[Dictionary] = []
var pending_results: Array[Dictionary] = []

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	request.request_completed.connect(_on_request_completed)
	client_id = _load_or_create_client_id()
	_load_outbox()

func configure(profile: Dictionary, service_enabled: bool, version: String) -> void:
	profile_id = str(profile.get("profile_id", ""))
	nickname = str(profile.get("nickname", ""))	
	enabled = service_enabled
	game_version = version.left(24)
	if enabled and playing and _has_identity():
		_send_heartbeat()

func set_enabled(value: bool) -> void:
	if not value:
		var was_playing := playing
		playing = false
		if was_playing and enabled and _has_identity():
			_send_heartbeat()
		enabled = false
		status_changed.emit("Online-Statistik deaktiviert")
	else:
		enabled = true
		if playing:
			_send_heartbeat()

func begin_playing() -> void:
	playing = true
	heartbeat_elapsed = 0.0
	if enabled and _has_identity():
		_send_heartbeat()
		_flush_outbox()

func stop_playing() -> void:
	if not playing:
		return
	playing = false
	heartbeat_elapsed = 0.0
	if enabled and _has_identity():
		_send_heartbeat()

func update_profile(profile: Dictionary) -> void:
	profile_id = str(profile.get("profile_id", ""))
	nickname = str(profile.get("nickname", ""))
	if enabled and playing and _has_identity():
		_send_heartbeat()

func submit_highscore(entry: Dictionary) -> void:
	if not enabled or not _has_identity():
		return
	var run_id := str(entry.get("run_id", ""))
	if run_id.is_empty():
		return
	var payload := {
		"profile_id": profile_id,
		"nickname": nickname,
		"run_id": run_id,
		"mission": str(entry.get("mission", "")),
		"mission_name": str(entry.get("mission_name", entry.get("mission", ""))),
		"score": int(entry.get("score", 0)),
		"time": float(entry.get("time", 0.0)),
		"difficulty": str(entry.get("difficulty", "")),
		"faction": str(entry.get("faction", "")),
		"game_version": game_version
	}
	for previous in pending_results:
		if str(previous.get("run_id", "")) == run_id:
			return
	pending_results.append(payload)
	if pending_results.size() > 100:
		pending_results.pop_front()
	_save_outbox()
	_flush_outbox()

func request_highscores(mission: String) -> void:
	if not enabled:
		status_changed.emit("Online-Statistik ist deaktiviert")
		return
	queued_requests.append({"kind": "highscores", "path": "/api/v1/games/" + GAME_ID + "/highscores?mission=" + mission.uri_encode(), "payload": {}, "mission": mission})
	_pump_requests()

func check_server_status() -> void:
	if not enabled:
		server_status_changed.emit("NICHT GEPRÜFT · ONLINE-STATISTIK AUS", false)
		return
	if request_active and str(active_request.get("kind", "")) == "health":
		return
	for queued in queued_requests:
		if str(queued.get("kind", "")) == "health":
			return
	queued_requests.append({"kind": "health", "path": "/health", "payload": {}})
	_pump_requests()

func request_public_address() -> void:
	if not enabled:
		public_address_received.emit("", false)
		return
	if request_active and str(active_request.get("kind", "")) == "public_address":
		return
	for queued in queued_requests:
		if str(queued.get("kind", "")) == "public_address":
			return
	queued_requests.append({"kind": "public_address", "path": "/api/v1/network/address", "payload": {}})
	_pump_requests()

func _process(delta: float) -> void:
	if not enabled or not playing or not _has_identity():
		return
	heartbeat_elapsed += delta
	if heartbeat_elapsed >= HEARTBEAT_SECONDS:
		heartbeat_elapsed = 0.0
		_send_heartbeat()
		_flush_outbox()

func _has_identity() -> bool:
	return not profile_id.is_empty() and not nickname.is_empty() and not client_id.is_empty()

func _send_heartbeat() -> void:
	if not enabled or not _has_identity():
		return
	var payload := {
		"profile_id": profile_id,
		"client_id": client_id,
		"nickname": nickname,
		"game_version": game_version,
		"playing": playing
	}
	_queue_request("heartbeat", "/api/v1/games/" + GAME_ID + "/heartbeat", payload)

func _flush_outbox() -> void:
	if not enabled or pending_results.is_empty():
		return
	_queue_request("result", "/api/v1/games/" + GAME_ID + "/results", pending_results[0])

func _queue_request(kind: String, path: String, payload: Dictionary) -> void:
	queued_requests.append({"kind": kind, "path": path, "payload": payload.duplicate(true)})
	_pump_requests()

func _pump_requests() -> void:
	if request_active or queued_requests.is_empty() or not enabled:
		return
	active_request = queued_requests.pop_front()
	var headers := PackedStringArray(["Accept: application/json"])
	var method := HTTPClient.METHOD_GET
	var body := ""
	if not (active_request.kind in ["highscores", "health", "public_address"]):
		method = HTTPClient.METHOD_POST
		headers.append("Content-Type: application/json")
		body = JSON.stringify(active_request.payload)
	request_active = true
	var error := request.request(base_url + str(active_request.path), headers, method, body)
	if error != OK:
		request_active = false
		if active_request.kind == "health":
			server_status_changed.emit("OFFLINE · Verbindung fehlgeschlagen", false)
		elif active_request.kind == "public_address":
			public_address_received.emit("", false)
		else:
			status_changed.emit("Online-Dienst nicht erreichbar · Ergebnis bleibt lokal vorgemerkt")
		active_request.clear()
		return

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_active = false
	var completed := active_request.duplicate(true)
	active_request.clear()
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
	if completed.kind == "health":
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and parsed is Dictionary and bool(parsed.get("ok", false)):
			server_status_changed.emit("ONLINE · API antwortet", true)
		else:
			server_status_changed.emit("OFFLINE · API nicht erreichbar", false)
	elif completed.kind == "public_address":
		var address := str(parsed.get("address", "")) if parsed is Dictionary else ""
		var valid_address := result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and parsed is Dictionary and bool(parsed.get("ok", false)) and _is_public_ipv4(address)
		public_address_received.emit(address if valid_address else "", valid_address)
	elif completed.kind == "heartbeat":
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and parsed is Dictionary and bool(parsed.get("ok", false)):
			status_changed.emit("Online-Dienst verbunden · %d Kommandanten aktiv" % int(parsed.get("online_players", 0)))
		else:
			status_changed.emit("Online-Dienst offline · lokale Partie funktioniert weiter")
	elif completed.kind == "result":
		if result == HTTPRequest.RESULT_SUCCESS and response_code in [200, 201] and parsed is Dictionary and bool(parsed.get("ok", false)):
			var sent_run := str(completed.payload.get("run_id", ""))
			if not pending_results.is_empty() and str(pending_results[0].get("run_id", "")) == sent_run:
				pending_results.pop_front()
				_save_outbox()
			status_changed.emit("Highscore online gespeichert")
		else:
			status_changed.emit("Highscore wird beim nächsten Verbindungsversuch erneut gesendet")
			queued_requests.clear()
	elif completed.kind == "highscores":
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and parsed is Dictionary and parsed.get("entries", []) is Array:
			var entries: Array = parsed.entries
			for entry in entries:
				if entry is Dictionary and entry.has("created_at"):
					entry["date"] = Time.get_date_string_from_unix_time(int(entry.created_at))
			highscores_received.emit(str(completed.get("mission", "")), entries)
			status_changed.emit("Online-Bestenliste geladen")
		else:
			status_changed.emit("Online-Bestenliste nicht erreichbar · lokale Liste bleibt verfügbar")
	_pump_requests()

func _load_or_create_client_id() -> String:
	if FileAccess.file_exists(CLIENT_ID_PATH):
		var saved := FileAccess.get_file_as_string(CLIENT_ID_PATH).strip_edges()
		if saved.length() >= 8 and saved.length() <= 64:
			return saved
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var generated := "%08x-%08x-%08x-%08x" % [rng.randi(), rng.randi(), Time.get_ticks_usec() & 0xffffffff, rng.randi()]
	var file := FileAccess.open(CLIENT_ID_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(generated)
		file.close()
	return generated

func _is_public_ipv4(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return false
	return not value.begins_with("10.") and not value.begins_with("192.168.") and not value.begins_with("127.") and not value.begins_with("169.254.")

func _load_outbox() -> void:
	if not FileAccess.file_exists(outbox_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(outbox_path))
	if parsed is Array:
		for result in parsed:
			if result is Dictionary and not str(result.get("run_id", "")).is_empty() and pending_results.size() < 100:
				pending_results.append(result)

func _save_outbox() -> void:
	var file := FileAccess.open(outbox_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(pending_results))
	file.close()
