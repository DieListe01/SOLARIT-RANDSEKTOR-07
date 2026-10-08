extends SceneTree

const InviteCode := preload("res://scripts/private_lobby_code.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PRIVATE LOBBY CODE: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var secret := "00112233445566778899AABBCCDDEEFF"
	var code := InviteCode.encode("79.240.71.178", secret, 2456)
	check(not code.is_empty() and code.begins_with("SR07-"), "creates a formatted private invite code")
	var decoded := InviteCode.decode(code)
	check(bool(decoded.get("ok", false)), "decodes a valid code")
	check(str(decoded.get("address", "")) == "79.240.71.178" and int(decoded.get("port", 0)) == 2456, "preserves host address and port")
	check(str(decoded.get("secret", "")) == secret, "keeps the access secret in the invite")
	check(InviteCode.looks_like_code(code), "recognizes invite-code input")
	check(bool(InviteCode.decode(code.to_lower().replace("-", " ")).get("ok", false)), "accepts lowercase and spaced code groups")
	var changed := code.left(code.length() - 1) + ("0" if code.ends_with("1") else "1")
	check(not bool(InviteCode.decode(changed).get("ok", false)), "rejects a damaged checksum")
	check(not bool(InviteCode.decode("SR07-0011").get("ok", false)), "rejects an incomplete code")
	check(InviteCode.encode("79.240.71.178", "bad").is_empty(), "refuses a malformed secret")
	check(InviteCode.encode("0.0.0.0", secret).is_empty(), "refuses an unspecified address")
	var challenge := "ABCDEF0123456789ABCDEF0123456789"
	var proof := InviteCode.make_proof(secret, challenge)
	check(InviteCode.proof_matches(secret, challenge, proof), "valid invite secret proves access to a fresh challenge")
	check(not InviteCode.proof_matches("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", challenge, proof), "wrong invite secret cannot prove access")
	check(not InviteCode.proof_matches(secret, challenge, ""), "empty proof is rejected")
	var generated := InviteCode.create_secret()
	check(generated.length() == 32 and InviteCode._is_hex(generated), "creates a random 128-bit access secret")
	print("PRIVATE LOBBY CODE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
