extends RefCounted
class_name NetworkProtocol

const VERSION := 6
const TICKS_PER_SECOND := 30
const MAX_FUTURE_TICKS := 300
const MAX_COMMAND_BYTES := 16384
const COMMAND_TYPES := ["build","produce","cancel_produce","cancel_queue_at","prioritize_queue","move_queue","upgrade","move","attack","attack_move","harvest","stop","hold","guard","rally","repair","return"]

static func create_command(session_id: String, player_id: int, sequence: int, target_tick: int, command: Dictionary) -> Dictionary:
	return {
		"protocol_version": VERSION,
		"session_id": session_id,
		"player_id": player_id,
		"sequence": sequence,
		"target_tick": target_tick,
		"command": command.duplicate(true),
	}

static func validate_command(packet: Variant, expected_session: String, host_tick: int, last_sequence: int, allowed_players: Array = [0,1], owner_by_player: Dictionary = {0:0,1:1}) -> Dictionary:
	if not packet is Dictionary: return reject("PACKET_NOT_OBJECT")
	if int(packet.get("protocol_version",-1))!=VERSION: return reject("PROTOCOL_MISMATCH")
	var session_id:=str(packet.get("session_id",""))
	if session_id!=expected_session or not valid_session_id(session_id): return reject("SESSION_MISMATCH")
	var player_value: Variant=packet.get("player_id",null)
	if not is_integer(player_value): return reject("INVALID_PLAYER")
	var player_id:=int(player_value)
	if not allowed_players.has(player_id): return reject("PLAYER_NOT_ALLOWED")
	var sequence_value: Variant=packet.get("sequence",null)
	if not is_integer(sequence_value) or int(sequence_value)!=last_sequence+1: return reject("SEQUENCE_MISMATCH")
	var tick_value: Variant=packet.get("target_tick",null)
	if not is_integer(tick_value): return reject("INVALID_TICK")
	var target_tick:=int(tick_value)
	if target_tick<host_tick or target_tick>host_tick+MAX_FUTURE_TICKS: return reject("TICK_OUT_OF_WINDOW")
	var command: Variant=packet.get("command",null)
	if not command is Dictionary: return reject("COMMAND_NOT_OBJECT")
	if not COMMAND_TYPES.has(str(command.get("type",""))): return reject("UNKNOWN_COMMAND")
	var owner_value: Variant=command.get("owner_id",null)
	if not is_integer(owner_value) or not owner_by_player.has(player_id) or int(owner_value)!=int(owner_by_player[player_id]): return reject("OWNER_MISMATCH")
	var encoded:=JSON.stringify(command)
	if encoded.is_empty() or encoded.to_utf8_buffer().size()>MAX_COMMAND_BYTES: return reject("COMMAND_TOO_LARGE")
	return {"ok":true,"reason":"","player_id":player_id,"sequence":int(sequence_value),"target_tick":target_tick,"command":command.duplicate(true)}

static func valid_session_id(value: String) -> bool:
	if value.length()<8 or value.length()>96: return false
	var allowed: String="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
	for character in value:
		if not allowed.contains(character): return false
	return true

static func is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

static func reject(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

static func state_hash(state: Dictionary) -> String:
	var canonical: Variant=canonicalize(state)
	var context:=HashingContext.new()
	if context.start(HashingContext.HASH_SHA256)!=OK: return ""
	if context.update(JSON.stringify(canonical).to_utf8_buffer())!=OK: return ""
	return context.finish().hex_encode()

static func canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array=value.keys()
		keys.sort_custom(func(a,b): return str(a)<str(b))
		var result: Dictionary={}
		for key in keys: result[str(key)]=canonicalize(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value: result.append(canonicalize(item))
		return result
	return value
