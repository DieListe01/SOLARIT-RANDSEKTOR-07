extends SceneTree

const OnlineStatsScript := preload("res://scripts/online_stats.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("ONLINE STATS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test_path := "user://online_stats_test_queue.json"
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var service := OnlineStatsScript.new()
	service.outbox_path = test_path
	service.base_url = "http://127.0.0.1:1"
	root.add_child(service)
	await process_frame
	service.configure({"profile_id":"profile-12345678","nickname":"Dirk"}, false, "0.36.6")
	service.submit_highscore({"run_id":"test-run","mission":"veyra-01","score":1800,"time":320})
	check(service.pending_results.is_empty(), "Disabled service does not upload or queue scores")
	service.set_enabled(true)
	service.submit_highscore({"run_id":"test-run","mission":"veyra-01","score":1800,"time":320})
	check(service.pending_results.size() == 1, "Enabled service persists a pending result")
	check(FileAccess.file_exists(test_path), "Offline score queue is written locally")
	check(str(service.pending_results[0].get("profile_id", "")) == "profile-12345678", "Score queue keeps the existing profile identity")
	service.request.cancel_request()
	service.queue_free()
	await process_frame
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("ONLINE STATS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
