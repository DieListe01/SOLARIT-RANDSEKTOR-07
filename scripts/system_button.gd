extends Button

func _make_custom_tooltip(for_text: String) -> Object:
	var clean_text := for_text.strip_edges()
	# Godot may ask a Button for a custom tooltip even when tooltip_text is empty.
	# Returning no control prevents the empty dark tooltip plates seen in menus.
	if clean_text.is_empty():
		return null
	var frame := PanelContainer.new()
	var margins := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+edge,12)
	frame.add_child(margins)
	var copy := Label.new()
	copy.text=clean_text
	copy.custom_minimum_size.x=300
	copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size",13)
	margins.add_child(copy)
	return frame
