extends Control
class_name MatchChart

var samples: Array = []
var metric := "units"
var title := ""
var side_names: Array[String] = ["Spieler 1", "Spieler 2"]
var colors: Array[Color] = [Color("79d9bd"), Color("f47878")]

func configure(data: Array, metric_key: String, heading: String, names: Array[String], side_colors: Array[Color]) -> void:
	samples = data
	metric = metric_key
	title = heading
	side_names = names
	colors = side_colors
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color("172120"), true)
	draw_rect(area, Color("66513a"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(14, 23), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e7bd78"))
	var plot := Rect2(52, 34, maxf(1.0, size.x - 70), maxf(1.0, size.y - 66))
	for i in 5:
		var y := plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.55, 0.62, 0.58, 0.20), 1.0)
	if samples.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, plot.position.y + 34), "Keine Zeitreihe vorhanden", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b4a58d"))
		return
	var maximum := 1.0
	for sample in samples:
		var sides: Array = sample.get("sides", [])
		for owner in mini(2, sides.size()): maximum = maxf(maximum, _value(sides[owner]))
	for owner in 2:
		var points := PackedVector2Array()
		for index in samples.size():
			var sides: Array = samples[index].get("sides", [])
			if owner >= sides.size(): continue
			var x := plot.position.x + plot.size.x * float(index) / float(maxi(1, samples.size() - 1))
			var y := plot.end.y - plot.size.y * _value(sides[owner]) / maximum
			points.append(Vector2(x, y))
		if points.size() > 1: draw_polyline(points, colors[owner], 2.5, true)
		if not side_names[owner].is_empty():
			var legend_x := size.x - 170 + owner * 80
			draw_rect(Rect2(legend_x, 12, 9, 9), colors[owner], true)
			draw_string(ThemeDB.fallback_font, Vector2(legend_x + 13, 21), side_names[owner].left(12), HORIZONTAL_ALIGNMENT_LEFT, 72, 11, Color("d4ddd5"))
	var first_time := int(float(samples.front().get("time", 0.0)))
	var last_time := int(float(samples.back().get("time", 0.0)))
	draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, size.y - 9), _format_time(first_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b4a58d"))
	draw_string(ThemeDB.fallback_font, Vector2(plot.end.x - 65, size.y - 9), _format_time(last_time), HORIZONTAL_ALIGNMENT_RIGHT, 65, 11, Color("b4a58d"))

func _value(side: Dictionary) -> float:
	return maxf(0.0, float(side.get(metric, 0.0)))

func _format_time(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]
