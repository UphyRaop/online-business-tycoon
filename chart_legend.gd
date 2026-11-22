extends RefCounted

const Style = preload("res://corporate_theme.gd")

class DotMarker extends Control:
	var marker_color: Color = Color.WHITE

	func _draw() -> void:
		var diameter := minf(size.x, size.y)
		draw_circle(size / 2.0, diameter * 0.28, marker_color)

static func build(series: Array[Dictionary]) -> FlowContainer:
	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in series:
		var name := str(item.get("name", ""))
		var chip := HBoxContainer.new()
		chip.custom_minimum_size = Vector2(maxf(90.0, 30.0 + float(name.length()) * 7.5), 26)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.add_theme_constant_override("separation", 5)
		var marker := DotMarker.new()
		marker.name = "LegendColorMarker"
		marker.marker_color = item.get("color", Color.WHITE)
		marker.custom_minimum_size = Vector2(Style.ICON_CONTROL, Style.ICON_CONTROL)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(marker)
		var caption := Label.new()
		caption.text = name
		caption.custom_minimum_size.x = maxf(60.0, float(name.length()) * 7.5)
		caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.clip_text = false
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color("#a6b5c8"))
		chip.add_child(caption)
		flow.add_child(chip)
	return flow
