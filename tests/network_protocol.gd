extends SceneTree

const Protocol = preload("res://scripts/network_protocol.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error("NETWORK PROTOCOL: "+message)

func _initialize() -> void:
	var command={"type":"move","owner_id":1,"ids":[12,13],"point":[550.0,900.0]}
	var packet:=Protocol.create_command("session_123456",1,1,600,command)
	var accepted:=Protocol.validate_command(packet,"session_123456",590,0,[0,1])
	check(accepted.ok and accepted.command==command and accepted.target_tick==600,"valid scheduled command envelope accepted")
	check(Protocol.validate_command(packet,"other_123456",590,0).reason=="SESSION_MISMATCH","foreign session rejected")
	var bad:=packet.duplicate(true); bad.protocol_version=Protocol.VERSION+1
	check(Protocol.validate_command(bad,"session_123456",590,0).reason=="PROTOCOL_MISMATCH","protocol versions must match")
	bad=packet.duplicate(true); bad.player_id=0
	check(Protocol.validate_command(bad,"session_123456",590,0).reason=="OWNER_MISMATCH","player cannot issue another player's command")
	check(Protocol.validate_command(packet,"session_123456",590,1).reason=="SEQUENCE_MISMATCH","replayed sequence rejected")
	bad=packet.duplicate(true); bad.target_tick=589
	check(Protocol.validate_command(bad,"session_123456",590,0).reason=="TICK_OUT_OF_WINDOW","late command rejected")
	bad=packet.duplicate(true); bad.target_tick=590+Protocol.MAX_FUTURE_TICKS+1
	check(Protocol.validate_command(bad,"session_123456",590,0).reason=="TICK_OUT_OF_WINDOW","excessively delayed command rejected")
	bad=packet.duplicate(true); bad.command.type="give_everything"
	check(Protocol.validate_command(bad,"session_123456",590,0).reason=="UNKNOWN_COMMAND","unknown command rejected before simulation")
	bad=packet.duplicate(true); bad.command.owner_id=0
	check(Protocol.validate_command(bad,"session_123456",590,0).reason=="OWNER_MISMATCH","owner spoof rejected before simulation")
	var ordered_a={"z":1,"a":{"y":2,"b":3}}
	var ordered_b={"a":{"b":3,"y":2},"z":1}
	check(Protocol.state_hash(ordered_a)==Protocol.state_hash(ordered_b),"state fingerprint ignores dictionary insertion order")
	ordered_b.a.b=4
	check(Protocol.state_hash(ordered_a)!=Protocol.state_hash(ordered_b),"state fingerprint detects changed values")
	print("NETWORK PROTOCOL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
