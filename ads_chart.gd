extends Control

var chart_labels: Array[String] = []
var series: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size.y = 170
	queue_redraw()

func configure(labels: Array[String], values: Array[Dictionary]) -> void:
	chart_labels = labels.duplicate()
	series = values.duplicate(true)
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2(34, 8), Vector2(maxf(80, size.x - 44), maxf(80, size.y - 38)))
	for line in range(0, 4):
		var y := bounds.position.y + bounds.size.y * float(line) / 3.0
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color("#29384d"), 1.0)
	if chart_labels.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(40, 28), "No recorded activity for this period", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6b5c8"))
		return
	var peak := 0.0
	for item in series:
		for value in item.get("values", []): peak = maxf(peak, float(value))
	if peak <= 0.0: peak = 1.0
	for item in series:
		var values: Array = item.get("values", [])
		var points := PackedVector2Array()
		for index in values.size():
			var x := bounds.position.x + (bounds.size.x * 0.5 if values.size() == 1 else bounds.size.x * float(index) / float(values.size() - 1))
			var y := bounds.end.y - bounds.size.y * float(values[index]) / peak
			points.append(Vector2(x, y))
		if points.size() > 1: draw_polyline(points, item.get("color", Color.WHITE), 2.5, true)
		for point in points: draw_circle(point, 3.0, item.get("color", Color.WHITE))
	for index in chart_labels.size():
		if chart_labels.size() <= 6 or index == 0 or index == chart_labels.size() - 1 or index % maxi(1, chart_labels.size() / 5) == 0:
			var x := bounds.position.x + (bounds.size.x * 0.5 if chart_labels.size() == 1 else bounds.size.x * float(index) / float(chart_labels.size() - 1))
			draw_string(ThemeDB.fallback_font, Vector2(x - 20, size.y - 4), chart_labels[index], HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color("#a6b5c8"))
