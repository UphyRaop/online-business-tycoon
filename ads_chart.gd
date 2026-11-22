extends Control

const Style = preload("res://corporate_theme.gd")

var chart_labels: Array[String] = []
var series: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size.y = 170
	queue_redraw()

func configure(labels: Array[String], values: Array[Dictionary]) -> void:
	chart_labels = labels.duplicate()
	series = values.duplicate(true)
	custom_minimum_size.y = 170 if _has_data() else 52
	queue_redraw()

func _has_data() -> bool:
	for item in series:
		for value in item.get("values", []):
			if absf(float(value)) > 0.000001: return true
	return false

func effective_draw_text_sizes() -> Array[int]:
	var active_theme := get_theme()
	var large_text := active_theme != null and active_theme.default_font_size > Style.FONT_BODY
	return [
		Style.normalized_font_size(Style.FONT_BODY, large_text),
		Style.normalized_font_size(Style.FONT_CAPTION, large_text),
	]

func _draw() -> void:
	var text_sizes := effective_draw_text_sizes()
	if not _has_data():
		draw_string(ThemeDB.fallback_font, Vector2(4, maxf(20.0, size.y * 0.68)), "No recorded activity for this period", HORIZONTAL_ALIGNMENT_LEFT, maxf(120.0, size.x - 8.0), text_sizes[0], Color("#a6b5c8"))
		return
	var bounds := Rect2(Vector2(34, 8), Vector2(maxf(80, size.x - 44), maxf(80, size.y - 38)))
	for line in range(0, 4):
		var y := bounds.position.y + bounds.size.y * float(line) / 3.0
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color("#29384d"), 1.0)
	var minimum := 0.0
	var maximum := 0.0
	for item in series:
		for value in item.get("values", []):
			minimum = minf(minimum, float(value))
			maximum = maxf(maximum, float(value))
	var span := maximum - minimum
	if span <= 0.0: span = 1.0
	if minimum < 0.0 and maximum > 0.0:
		var zero_y := bounds.end.y - bounds.size.y * (0.0 - minimum) / span
		draw_line(Vector2(bounds.position.x, zero_y), Vector2(bounds.end.x, zero_y), Color("#52637a"), 1.0)
	for item in series:
		var values: Array = item.get("values", [])
		var points := PackedVector2Array()
		for index in values.size():
			var x := bounds.position.x + (bounds.size.x * 0.5 if values.size() == 1 else bounds.size.x * float(index) / float(values.size() - 1))
			var y := bounds.end.y - bounds.size.y * (float(values[index]) - minimum) / span
			points.append(Vector2(x, y))
		if points.size() > 1: draw_polyline(points, item.get("color", Color.WHITE), 2.5, true)
		for point in points: draw_circle(point, 3.0, item.get("color", Color.WHITE))
	for index in chart_labels.size():
		if chart_labels.size() <= 6 or index == 0 or index == chart_labels.size() - 1 or index % maxi(1, chart_labels.size() / 5) == 0:
			var x := bounds.position.x + (bounds.size.x * 0.5 if chart_labels.size() == 1 else bounds.size.x * float(index) / float(chart_labels.size() - 1))
			draw_string(ThemeDB.fallback_font, Vector2(x - 20, size.y - 4), chart_labels[index], HORIZONTAL_ALIGNMENT_CENTER, 40, text_sizes[1], Color("#a6b5c8"))
