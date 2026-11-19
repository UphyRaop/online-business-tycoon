extends SceneTree

const Legend = preload("res://chart_legend.gd")

var failures := 0

func _initialize() -> void:
	var accent := Color("#e6bf7b")
	var view := Legend.build([{"name": "Revenue", "color": accent}])
	root.add_child(view)
	await process_frame
	var marker := view.find_child("LegendColorMarker", true, false)
	expect(marker is Control and not marker is Label,
		"Financial chart legends use a drawn vector marker instead of a Unicode glyph")
	if marker is Control:
		expect(marker.custom_minimum_size == Vector2(16, 16) and marker.get("marker_color") == accent,
			"The chart marker keeps its intended size and series color")
	print("Chart legend icons: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
