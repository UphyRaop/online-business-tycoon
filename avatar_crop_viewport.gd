extends Control

signal preview_changed(image: Image)

const CROP_WIDTH := 3.0
const CROP_HEIGHT := 4.0
const FRAME := Color("#0b1018")
const BORDER := Color("#e8c58b")

var source_image: Image
var source_texture: ImageTexture
var zoom := 1.0
var offset := Vector2.ZERO
var dragging := false
var last_pointer := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)
	queue_redraw()
	call_deferred("_on_resized")

func set_image(image: Image) -> void:
	source_image = image.duplicate()
	source_texture = ImageTexture.create_from_image(source_image)
	reset_crop()

func set_zoom(value: float) -> void:
	zoom = clampf(value, 1.0, 3.0)
	_constrain_offset()
	_update_preview()
	queue_redraw()

func reset_crop() -> void:
	zoom = 1.0
	offset = Vector2.ZERO
	_constrain_offset()
	_update_preview()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		last_pointer = event.position
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_move_image(event.position - last_pointer)
		last_pointer = event.position
		accept_event()
	elif event is InputEventScreenTouch:
		dragging = event.pressed
		last_pointer = event.position
		accept_event()
	elif event is InputEventScreenDrag and dragging:
		_move_image(event.relative)
		last_pointer = event.position
		accept_event()

func _move_image(delta: Vector2) -> void:
	offset += delta
	_constrain_offset()
	_update_preview()
	queue_redraw()

func _on_resized() -> void:
	_constrain_offset()
	_update_preview()
	queue_redraw()

func _scale() -> float:
	if source_image == null or source_image.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return maxf(size.x / source_image.get_width(), size.y / source_image.get_height()) * zoom

func _image_rect() -> Rect2:
	if source_image == null or source_image.is_empty():
		return Rect2()
	var scale_value := _scale()
	var drawn_size := Vector2(source_image.get_size()) * scale_value
	return Rect2(size * 0.5 + offset - drawn_size * 0.5, drawn_size)

func _constrain_offset() -> void:
	if source_image == null or source_image.is_empty():
		offset = Vector2.ZERO
		return
	var drawn_size := Vector2(source_image.get_size()) * _scale()
	var limit := (drawn_size - size) * 0.5
	offset.x = clampf(offset.x, -maxf(limit.x, 0.0), maxf(limit.x, 0.0))
	offset.y = clampf(offset.y, -maxf(limit.y, 0.0), maxf(limit.y, 0.0))

func crop_image(output_size: Vector2i = Vector2i(300, 400)) -> Image:
	if source_image == null or source_image.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return Image.new()
	var scale_value := _scale()
	var displayed := _image_rect()
	var source_size := Vector2(size) / scale_value
	var origin := Vector2(-displayed.position.x, -displayed.position.y) / scale_value
	origin.x = clampf(origin.x, 0.0, source_image.get_width() - source_size.x)
	origin.y = clampf(origin.y, 0.0, source_image.get_height() - source_size.y)
	var source_rect := Rect2i(Vector2i(roundi(origin.x), roundi(origin.y)), Vector2i(roundi(source_size.x), roundi(source_size.y)))
	source_rect.size.x = clampi(source_rect.size.x, 1, source_image.get_width() - source_rect.position.x)
	source_rect.size.y = clampi(source_rect.size.y, 1, source_image.get_height() - source_rect.position.y)
	var result := source_image.get_region(source_rect)
	result.resize(output_size.x, output_size.y, Image.INTERPOLATE_LANCZOS)
	return result

func _update_preview() -> void:
	if is_inside_tree() and source_image != null and not source_image.is_empty() and size.x > 0.0 and size.y > 0.0:
		preview_changed.emit(crop_image())

func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, FRAME)
	if source_texture != null and source_image != null and not source_image.is_empty():
		draw_texture_rect(source_texture, _image_rect(), false)
	draw_rect(frame, BORDER, false, 2.0)
