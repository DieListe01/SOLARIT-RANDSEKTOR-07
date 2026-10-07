extends Node
class_name OnlineDirectory

signal lobbies_received(entries: Array, message: String)
signal publish_finished(ok: bool, message: String, address: String)
signal status_changed(message: String)

const BASE_URL := "https://api.dl-home.de"
const GAME_ID := "solarit-randsektor-07"
const REQUEST_TIMEOUT_SECONDS := 8.0
const HEARTBEAT_SECONDS := 20.0

var base_url := BASE_URL
var client_id := ""
var game_version := ""
var enabled := true
var request: HTTPRequest
var queue: Array[Dictionary] = []
var active := false
var active_item: Dictionary = {}
var published_lobby_id := ""
var published_token := ""
var heartbeat_elapsed := 0.0

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	request.request_completed.connect(_on_request_completed)

func _process(delta: float) -> void:
	if not enabled or published_lobby_id.is_empty():
		return
	heartbeat_elapsed += delta
	if heartbeat_elapsed >= HEARTBEAT_SECONDS:
		heartbeat_elapsed = 0.0
		_queue("heartbeat", "/api/v1/games/" + GAME_ID + "/lobbies/heartbeat", _host_payload())

func list_lobbies() -> void:
	if not enabled:
		lobbies_received.emit([], "Lobby-Dienst in lokalen Tests deaktiviert")
		return
	_queue("list", "/api/v1/games/" + GAME_ID + "/lobbies", {})

func publish_lobby(profile_id: String, nickname: String, mode: String, mission_id: String, mission_name: String, port: int) -> void:
	if not enabled:
		publish_finished.emit(false, "Lobby-Dienst in lokalen Tests deaktiviert", "")
		return
	if client_id.length() < 8 or profile_id.length() < 8:
		publish_finished.emit(false, "Spielerprofil noch nicht bereit", "")
		return
	var payload := {
		"profile_id": profile_id,
		"client_id": client_id,
		"nickname": nickname,
		"mode": mode,
		"mission": mission_id,
		"mission_name": mission_name,
		"game_version": game_version,
		"port": port
	}
	_queue("publish", "/api/v1/games/" + GAME_ID + "/lobbies", payload)

func close_lobby() -> void:
	if published_lobby_id.is_empty():
		return
	var payload := _host_payload()
	_queue("close", "/api/v1/games/" + GAME_ID + "/lobbies/close", payload)
	published_lobby_id = ""
	published_token = ""
	heartbeat_elapsed = 0.0

func _host_payload() -> Dictionary:
	return {"lobby_id": published_lobby_id, "lobby_token": published_token, "client_id": client_id}

func _queue(kind: String, path: String, payload: Dictionary) -> void:
	queue.append({"kind": kind, "path": path, "payload": payload.duplicate(true)})
	_pump()

func _pump() -> void:
	if active or queue.is_empty() or not enabled:
		return
	active_item = queue.pop_front()
	var headers := PackedStringArray(["Accept: application/json"])
	var method := HTTPClient.METHOD_GET
	var body := ""
	if active_item.kind != "list":
		method = HTTPClient.METHOD_POST
		headers.append("Content-Type: application/json")
		body = JSON.stringify(active_item.payload)
	active = true
	var error := request.request(base_url + str(active_item.path), headers, method, body)
	if error != OK:
		active = false
		_handle_result(HTTPRequest.RESULT_CONNECTION_ERROR, 0, {})

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
	_handle_result(result, response_code, parsed if parsed is Dictionary else {})

func _handle_result(result: int, response_code: int, parsed: Dictionary) -> void:
	var completed := active_item.duplicate(true)
	active = false
	active_item.clear()
	var ok := result == HTTPRequest.RESULT_SUCCESS and response_code in [200, 201] and bool(parsed.get("ok", completed.kind == "list"))
	match str(completed.get("kind", "")):
		"list":
			if ok and parsed.get("lobbies", []) is Array:
				lobbies_received.emit(parsed.lobbies, "")
			else:
				lobbies_received.emit([], "Lobby-Liste gerade nicht erreichbar")
		"publish":
			if ok and parsed.has("lobby_id") and parsed.has("lobby_token"):
				published_lobby_id = str(parsed.lobby_id)
				published_token = str(parsed.lobby_token)
				heartbeat_elapsed = 0.0
				var address := str(parsed.get("address", ""))
				publish_finished.emit(true, "Öffentlich gelistet · " + address, address)
			else:
				publish_finished.emit(false, str(parsed.get("error", "Lobby konnte nicht veröffentlicht werden")), "")
		"heartbeat":
			if not ok and not published_lobby_id.is_empty():
				status_changed.emit("Lobby-Listung unterbrochen · bitte erneut veröffentlichen")
		"close":
			pass
	_pump()
