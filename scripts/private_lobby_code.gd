extends RefCounted
class_name PrivateLobbyCode

const PREFIX := "SR07"
const HEX := "0123456789ABCDEF"

static func create_secret() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode().to_upper()

static func make_proof(secret: String, challenge: String) -> String:
	return (secret + challenge).sha256_text()

static func proof_matches(secret: String, challenge: String, proof: String) -> bool:
	return secret.length() == 32 and challenge.length() == 32 and proof == make_proof(secret, challenge)

static func encode(address: String, secret: String, port: int = 2456) -> String:
	var parts := address.strip_edges().split(".")
	if parts.size() != 4 or port < 1 or port > 65535 or secret.length() != 32 or not _is_hex(secret.to_upper()):
		return ""
	var ip_hex := ""
	var all_zero := true
	for part in parts:
		if part.is_empty() or not part.is_valid_int():
			return ""
		var octet := int(part)
		if octet < 0 or octet > 255:
			return ""
		all_zero = all_zero and octet == 0
		ip_hex += "%02X" % octet
	if all_zero: return ""
	var payload := ip_hex + ("%04X" % port) + secret.to_upper()
	var checksum := payload.sha256_text().substr(0, 4).to_upper()
	return "%s-%s-%s-%s-%s" % [PREFIX, ip_hex, payload.substr(8, 4), payload.substr(12, 32), checksum]

static func looks_like_code(value: String) -> bool:
	return value.strip_edges().to_upper().replace("-", "").begins_with(PREFIX)

static func decode(value: String) -> Dictionary:
	var normalized := value.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if not normalized.begins_with(PREFIX):
		return {"ok": false, "error": "Das ist kein SOLARIT-Einladungscode."}
	if normalized.length() != 52:
		return {"ok": false, "error": "Der Einladungscode ist unvollständig."}
	var payload := normalized.substr(4, 44)
	var checksum := normalized.substr(48, 4)
	if not _is_hex(payload) or not _is_hex(checksum):
		return {"ok": false, "error": "Der Einladungscode enthält ungültige Zeichen."}
	if payload.sha256_text().substr(0, 4).to_upper() != checksum:
		return {"ok": false, "error": "Der Einladungscode ist beschädigt oder falsch abgeschrieben."}
	var octets: Array[int] = []
	for index in 4:
		octets.append(_hex_to_int(payload.substr(index * 2, 2)))
	var address := "%d.%d.%d.%d" % [octets[0], octets[1], octets[2], octets[3]]
	var port := _hex_to_int(payload.substr(8, 4))
	var secret := payload.substr(12, 32)
	if address == "0.0.0.0" or port < 1:
		return {"ok": false, "error": "Der Einladungscode enthält keine gültige Host-Adresse."}
	return {"ok": true, "address": address, "port": port, "secret": secret}

static func _is_hex(value: String) -> bool:
	for character in value:
		if HEX.find(character) < 0:
			return false
	return true

static func _hex_to_int(value: String) -> int:
	var number := 0
	for character in value:
		number = number * 16 + HEX.find(character)
	return number
