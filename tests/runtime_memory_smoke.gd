extends SceneTree

const MATCH_CYCLES := 5
const SETTLE_FRAMES := 20

func _initialize() -> void:
	call_deferred("run")

func metrics() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0),
	}

func settle() -> void:
	for _frame in SETTLE_FRAMES:
		await process_frame

func run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro()
	game.set_display_mode(2)
	game.show_main_menu()
	await settle()
	print("RUNTIME MEMORY BASELINE ", JSON.stringify(metrics()))
	var readings: Array[Dictionary] = []
	for cycle in range(MATCH_CYCLES):
		await game.start_game()
		game.paused=true
		for _frame in 45:
			await process_frame
		game.show_main_menu()
		await settle()
		var sample:=metrics()
		readings.append(sample)
		print("RUNTIME MEMORY CYCLE %d "% (cycle+1), JSON.stringify(sample))
	var stable_readings:=readings.slice(1)
	var first: Dictionary=stable_readings[0]
	var last: Dictionary=stable_readings[-1]
	print("RUNTIME MEMORY STEADY DELTA ", JSON.stringify({
		"objects": int(last.objects)-int(first.objects),
		"nodes": int(last.nodes)-int(first.nodes),
		"resources": int(last.resources)-int(first.resources),
		"static_mb": snappedf(float(last.static_mb)-float(first.static_mb),0.01),
	}))
	game.queue_free()
	await process_frame
	call_deferred("quit",0)
