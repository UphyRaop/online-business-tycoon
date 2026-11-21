extends ScrollContainer

## ScrollContainer handles wheel events natively, but Godot Web can deliver a
## touchscreen drag as InputEventScreenDrag without a corresponding mouse drag.
## Keep this gesture scoped to the Buy Inventory content viewport.

const DRAG_DEADZONE := 10.0

var _touch_index := -1
var _touch_origin := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _touch_dragging := false
var _mouse_drag_origin := Vector2.ZERO
var _mouse_last := Vector2.ZERO
var _mouse_dragging := false

func _input(event: InputEvent) -> void:
	# Some Web/browser combinations expose touch as emulated mouse input rather
	# than screen events. Support that path too; the deadzone keeps ordinary taps
	# and button presses unchanged.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			if not get_global_rect().has_point(mouse_button.position):
				return
			_mouse_drag_origin = mouse_button.position
			_mouse_last = mouse_button.position
			_mouse_dragging = false
		else:
			_mouse_dragging = false
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_motion := event as InputEventMouseMotion
		if not _mouse_dragging and mouse_motion.position.distance_to(_mouse_drag_origin) >= DRAG_DEADZONE:
			_mouse_dragging = true
		if _mouse_dragging:
			_scroll_by_pointer_delta(mouse_motion.position.y - _mouse_last.y)
			_mouse_last = mouse_motion.position
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not get_global_rect().has_point(touch.position):
				return
			_touch_index = touch.index
			_touch_origin = touch.position
			_touch_last = touch.position
			_touch_dragging = false
		elif touch.index == _touch_index:
			_touch_index = -1
			_touch_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		if not _touch_dragging and drag.position.distance_to(_touch_origin) >= DRAG_DEADZONE:
			_touch_dragging = true
		if _touch_dragging:
			var delta_y := drag.position.y - _touch_last.y
			_scroll_by_pointer_delta(delta_y)
			_touch_last = drag.position
			get_viewport().set_input_as_handled()

func _scroll_by_pointer_delta(delta_y: float) -> void:
	var bar := get_v_scroll_bar()
	bar.value = clampf(bar.value - delta_y, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
