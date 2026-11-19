extends PanelContainer

## Decorative frame for a finalized 3:4 CEO portrait. It only changes
## presentation; the existing CEO profile continues to own image persistence.
const Style = preload("res://corporate_theme.gd")

var portrait: TextureRect

func _init() -> void:
	name = "CEOAvatarFrame"
	var frame_style := Style.box(Style.SURFACE, Style.GOLD, 12, 4)
	frame_style.set_border_width_all(2)
	add_theme_stylebox_override("panel", frame_style)
	portrait = TextureRect.new()
	portrait.name = "CEOAvatar"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(portrait)

func set_portrait(texture: Texture2D, width: float) -> void:
	var safe_width := maxf(64.0, width)
	custom_minimum_size = Vector2(safe_width, safe_width * 4.0 / 3.0)
	portrait.texture = texture
	portrait.custom_minimum_size = Vector2(safe_width - 12.0, (safe_width - 12.0) * 4.0 / 3.0)
