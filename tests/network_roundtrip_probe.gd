extends Node

signal report_received(mission: int, sequence: int, hash_value: String, order: String, moved: bool)
signal finished
var confirmed := false

@rpc("any_peer","call_remote","reliable",3)
func report(mission: int, sequence: int, hash_value: String, order: String, moved: bool) -> void:
	report_received.emit(mission,sequence,hash_value,order,moved)

@rpc("authority","call_remote","reliable",3)
func finish() -> void:
	rpc_id(1,"confirm")
	finished.emit()

@rpc("any_peer","call_remote","reliable",3)
func confirm() -> void:
	confirmed=true
