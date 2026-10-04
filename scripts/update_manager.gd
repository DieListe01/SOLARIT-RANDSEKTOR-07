extends Node
class_name UpdateManager

signal update_check_finished(result: Dictionary)
signal installer_download_finished(success: bool, message: String)

const INSTALLER_PREFIX := "ASHLINE-Setup-"
const MAX_INSTALLER_BYTES := 300 * 1024 * 1024

var current_version := "0.0"
var repository := ""
var latest_version := ""
var latest_notes := ""
var installer_path := ""
var installer_url := ""
var expected_sha256 := ""
var release_assets: Array = []
var busy := false

var api_request: HTTPRequest
var transfer_request: HTTPRequest

func _ready() -> void:
	if not can_check(): return
	api_request=HTTPRequest.new()
	api_request.timeout=12.0
	api_request.body_size_limit=1024*1024
	api_request.max_redirects=4
	add_child(api_request)
	api_request.request_completed.connect(_on_api_completed)
	transfer_request=HTTPRequest.new()
	transfer_request.timeout=0.0
	transfer_request.body_size_limit=1024*1024
	transfer_request.max_redirects=8
	add_child(transfer_request)
	transfer_request.request_completed.connect(_on_transfer_completed)

func configure(version: String, channel: Dictionary) -> void:
	current_version=version
	repository=str(channel.get("repository","" )).strip_edges()

func can_check() -> bool:
	return repository_is_valid(repository) and OS.get_name()=="Windows"

func check_for_update() -> bool:
	if busy or not can_check(): return false
	busy=true
	latest_version=""; latest_notes=""; release_assets=[]
	var error:=api_request.request("https://api.github.com/repos/%s/releases/latest"%repository,["Accept: application/vnd.github+json","User-Agent: ASHLINE-Game"])
	if error!=OK:
		busy=false
		update_check_finished.emit({"ok":false,"available":false,"message":"GitHub ist gerade nicht erreichbar."})
		return false
	return true

func _on_api_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy: return
	if result!=HTTPRequest.RESULT_SUCCESS or response_code!=200:
		finish_check_error("Die Update-Abfrage ist fehlgeschlagen.")
		return
	var release: Variant=JSON.parse_string(body.get_string_from_utf8())
	if not release is Dictionary:
		finish_check_error("GitHub hat keine gültigen Release-Daten geliefert.")
		return
	latest_version=normalize_version(str(release.get("tag_name","")))
	if not version_is_valid(latest_version):
		finish_check_error("Die veröffentlichte Versionsnummer ist ungültig.")
		return
	latest_notes=str(release.get("body","" )).strip_edges()
	release_assets=release.get("assets",[]) if release.get("assets",[]) is Array else []
	var available:=is_newer_version(latest_version,current_version)
	busy=false
	update_check_finished.emit({"ok":true,"available":available,"version":latest_version,"notes":latest_notes})

func begin_installer_download() -> bool:
	if busy or latest_version.is_empty() or not is_newer_version(latest_version,current_version): return false
	var manifest_name: String="ASHLINE-%s-release.json"%latest_version
	var manifest_asset:=find_asset(manifest_name)
	if manifest_asset.is_empty():
		installer_download_finished.emit(false,"Das Prüfsummen-Manifest fehlt im Release.")
		return false
	var url:=safe_asset_url(str(manifest_asset.get("browser_download_url","")))
	if url.is_empty():
		installer_download_finished.emit(false,"Der Downloadlink des Manifests ist ungültig.")
		return false
	busy=true
	transfer_request.download_file=""
	transfer_request.body_size_limit=1024*1024
	var error:=transfer_request.request(url,["Accept: application/octet-stream","User-Agent: ASHLINE-Game"])
	if error!=OK:
		busy=false
		installer_download_finished.emit(false,"Das Update-Manifest konnte nicht geladen werden.")
		return false
	return true

func _on_transfer_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy: return
	if result!=HTTPRequest.RESULT_SUCCESS or response_code!=200:
		busy=false
		installer_download_finished.emit(false,"Der Update-Download ist fehlgeschlagen.")
		return
	if transfer_request.download_file.is_empty():
		var manifest: Variant=JSON.parse_string(body.get_string_from_utf8())
		if not manifest is Dictionary or str(manifest.get("version",""))!=latest_version:
			busy=false
			installer_download_finished.emit(false,"Das Update-Manifest passt nicht zur Release-Version.")
			return
		var expected_name:=INSTALLER_PREFIX+latest_version+".exe"
		if str(manifest.get("installer",""))!=expected_name:
			busy=false
			installer_download_finished.emit(false,"Der Installername im Manifest ist ungültig.")
			return
		expected_sha256=str(manifest.get("sha256","" )).to_lower()
		if not is_sha256(expected_sha256):
			busy=false
			installer_download_finished.emit(false,"Die Prüfsumme im Manifest ist ungültig.")
			return
		var asset:=find_asset(expected_name)
		if asset.is_empty() or int(asset.get("size",0))<=0 or int(asset.get("size",0))>MAX_INSTALLER_BYTES:
			busy=false
			installer_download_finished.emit(false,"Der Installer fehlt oder überschreitet die erlaubte Größe.")
			return
		installer_url=safe_asset_url(str(asset.get("browser_download_url","")))
		if installer_url.is_empty():
			busy=false
			installer_download_finished.emit(false,"Der Installer-Downloadlink ist ungültig.")
			return
		var update_dir:=ProjectSettings.globalize_path("user://updates")
		DirAccess.make_dir_recursive_absolute(update_dir)
		installer_path=update_dir.path_join(expected_name)
		transfer_request.download_file=installer_path
		transfer_request.body_size_limit=MAX_INSTALLER_BYTES
		var error:=transfer_request.request(installer_url,["Accept: application/octet-stream","User-Agent: ASHLINE-Game"])
		if error!=OK:
			busy=false
			transfer_request.download_file=""
			installer_download_finished.emit(false,"Der Installer-Download konnte nicht gestartet werden.")
		return
	var actual_hash:=FileAccess.get_sha256(installer_path).to_lower()
	transfer_request.download_file=""
	busy=false
	if not is_sha256(actual_hash) or actual_hash!=expected_sha256:
		DirAccess.remove_absolute(installer_path)
		installer_download_finished.emit(false,"Die Prüfsumme stimmt nicht. Der Installer wurde verworfen.")
		return
	installer_download_finished.emit(true,"Update geladen und geprüft.")

func launch_installer() -> bool:
	if installer_path.is_empty() or not FileAccess.file_exists(installer_path) or OS.get_name()!="Windows": return false
	var arguments:=PackedStringArray(["/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART","/CLOSEAPPLICATIONS","/RESTARTAPPLICATIONS"])
	return OS.create_process(installer_path,arguments,false)>0

func finish_check_error(message: String) -> void:
	busy=false
	update_check_finished.emit({"ok":false,"available":false,"message":message})

func find_asset(name: String) -> Dictionary:
	for asset in release_assets:
		if asset is Dictionary and str(asset.get("name",""))==name: return asset
	return {}

func safe_asset_url(url: String) -> String:
	var prefix: String="https://github.com/%s/releases/download/"%repository
	return url if url.begins_with(prefix) else ""

static func repository_is_valid(value: String) -> bool:
	var parts:=value.split("/",false)
	if parts.size()!=2: return false
	var allowed_characters: String="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
	for part in parts:
		if part.is_empty() or part=="." or part=="..": return false
		for character in part:
			if not allowed_characters.contains(character): return false
	return true

static func normalize_version(value: String) -> String:
	return value.trim_prefix("v").strip_edges()

static func version_is_valid(value: String) -> bool:
	var parts:=value.split(".",false)
	if parts.size()<2 or parts.size()>4: return false
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or int(part)<0: return false
	return true

static func is_newer_version(candidate: String, current: String) -> bool:
	if not version_is_valid(candidate) or not version_is_valid(current): return false
	var left:=candidate.split(".",false)
	var right:=current.split(".",false)
	for index in maxi(left.size(),right.size()):
		var a:=int(left[index]) if index<left.size() else 0
		var b:=int(right[index]) if index<right.size() else 0
		if a!=b: return a>b
	return false

static func is_sha256(value: String) -> bool:
	if value.length()!=64: return false
	for character in value:
		if not character.to_lower() in "0123456789abcdef": return false
	return true
