extends PanelContainer

## Decorative frame for a finalized 3:4 CEO portrait. It only changes
## presentation; the existing CEO profile continues to own image persistence.
const Style = preload("res://corporate_theme.gd")
const FRAME_BORDER := 2.0
const INNER_PADDING := 6.0
const DISPLAY_PHOTO_SIZE := Vector2i(300, 400)
const DISPLAY_CORNER_RADIUS := 24

var portrait: TextureRect
var portrait_padding: MarginContainer

func _init() -> void:
	name = "CEOAvatarFrame"
	var frame_style := Style.box(Style.SURFACE, Style.GOLD, 12, 0)
	frame_style.set_border_width_all(int(FRAME_BORDER))
	add_theme_stylebox_override("panel", frame_style)
	portrait_padding = MarginContainer.new()
	portrait_padding.name = "CEOAvatarPadding"
	portrait_padding.add_theme_constant_override("margin_left", int(INNER_PADDING))
	portrait_padding.add_theme_constant_override("margin_right", int(INNER_PADDING))
	portrait_padding.add_theme_constant_override("margin_top", int(INNER_PADDING))
	portrait_padding.add_theme_constant_override("margin_bottom", int(INNER_PADDING))
	portrait_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(portrait_padding)
	portrait = TextureRect.new()
	portrait.name = "CEOAvatar"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_padding.add_child(portrait)

func set_portrait(texture: Texture2D, width: float) -> void:
	var safe_width := maxf(64.0, width)
	var content_width := maxf(48.0, safe_width - (FRAME_BORDER + INNER_PADDING) * 2.0)
	var content_height := content_width * 4.0 / 3.0
	var frame_height := safe_width * 4.0 / 3.0
	custom_minimum_size = Vector2(safe_width, frame_height)
	portrait.texture = _center_crop_to_portrait(texture)
	portrait.custom_minimum_size = Vector2(content_width, content_height)

func _center_crop_to_portrait(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var source := texture.get_image()
	if source == null or source.is_empty():
		return texture
	var image := source.duplicate()
	var target_ratio := 3.0 / 4.0
	var source_ratio := float(image.get_width()) / float(image.get_height())
	if source_ratio > target_ratio:
		var crop_width := maxi(1, floori(float(image.get_height()) * target_ratio))
		var offset_x: int = (image.get_width() - crop_width) / 2
		image = image.get_region(Rect2i(offset_x, 0, crop_width, image.get_height()))
	elif source_ratio < target_ratio:
		var crop_height := maxi(1, floori(float(image.get_width()) / target_ratio))
		var offset_y: int = (image.get_height() - crop_height) / 2
		image = image.get_region(Rect2i(0, offset_y, image.get_width(), crop_height))
	# CEO photos are already finalized as 300×400 in current saves. Resizing a
	# display-only copy also keeps legacy square/landscape photos inexpensive to
	# mask without changing the bytes stored in the CEO profile.
	if image.get_width() != DISPLAY_PHOTO_SIZE.x or image.get_height() != DISPLAY_PHOTO_SIZE.y:
		image.resize(DISPLAY_PHOTO_SIZE.x, DISPLAY_PHOTO_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	_mask_portrait_corners(image)
	return ImageTexture.create_from_image(image)

func _mask_portrait_corners(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var radius := float(mini(DISPLAY_CORNER_RADIUS, mini(width, height) / 2))
	var radius_pixels := int(ceil(radius))
	for y in radius_pixels:
		for x in radius_pixels:
			_mask_corner_pixel(image, x, y, radius, radius)
			_mask_corner_pixel(image, width - 1 - x, y, width - radius, radius)
			_mask_corner_pixel(image, x, height - 1 - y, radius, height - radius)
			_mask_corner_pixel(image, width - 1 - x, height - 1 - y, width - radius, height - radius)

func _mask_corner_pixel(image: Image, x: int, y: int, center_x: float, center_y: float) -> void:
	var dx := float(x) + 0.5 - center_x
	var dy := float(y) + 0.5 - center_y
	var distance := sqrt(dx * dx + dy * dy)
	var coverage := clampf(DISPLAY_CORNER_RADIUS + 0.5 - distance, 0.0, 1.0)
	if coverage >= 1.0:
		return
	var pixel := image.get_pixel(x, y)
	pixel.a *= coverage
	image.set_pixel(x, y, pixel)
