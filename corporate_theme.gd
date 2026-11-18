extends RefCounted

const BG := Color("#0c121c")
const SURFACE := Color("#141e2d")
const INPUT := Color("#101927")
const LINE := Color("#29384d")
const TEXT := Color("#eef3fa")
const MUTED := Color("#a6b5c8")
const GOLD := Color("#e8c58b")
const INK := Color("#22190f")
const GREEN := Color("#7cdbb1")
const RED := Color("#ff9d9c")
const SUCCESS_INK := Color("#10251d")
const DANGER_INK := Color("#341514")

static func box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	for type in ["Button", "OptionButton", "LineEdit", "PopupMenu"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_pressed_color", type, GOLD)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, MUTED.darkened(0.25))
		theme.set_stylebox("normal", type, box(INPUT, LINE, 9, 10))
		theme.set_stylebox("hover", type, box(SURFACE.lightened(0.08), LINE.lightened(0.18), 9, 10))
		theme.set_stylebox("pressed", type, box(SURFACE, GOLD, 9, 10))
		var focus := box(Color.TRANSPARENT, GOLD, 9, 10)
		focus.draw_center = false
		theme.set_stylebox("focus", type, focus)
		theme.set_stylebox("disabled", type, box(BG, LINE, 9, 10))
	theme.set_stylebox("panel", "PopupMenu", box(SURFACE, LINE, 9, 8))
	theme.set_stylebox("panel", "AcceptDialog", box(SURFACE, LINE, 8, 14))
	for border_name in ["embedded_border", "embedded_unfocused_border"]:
		var frame := ThemeDB.get_default_theme().get_stylebox(border_name, "Window").duplicate() as StyleBoxFlat
		if frame != null:
			frame.bg_color = SURFACE
			frame.border_color = LINE
			theme.set_stylebox(border_name, "Window", frame)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_constant("v_separation", "PopupMenu", 15)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color("#44536b"))
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_stylebox("separator", "HSeparator", box(LINE, LINE, 0, 0))
	theme.set_stylebox("scroll", "VScrollBar", box(BG, BG, 3, 2))
	theme.set_stylebox("grabber", "VScrollBar", box(LINE.lightened(0.22), LINE, 3, 2))
	return theme

static func primary(control: Button) -> void:
	role(control, GOLD, INK)

static func secondary(control: Button) -> void:
	role(control, SURFACE, TEXT)

static func success(control: Button) -> void:
	role(control, GREEN, SUCCESS_INK)

static func danger(control: Button) -> void:
	role(control, RED, DANGER_INK)

static func role(control: Button, fill: Color, ink: Color) -> void:
	control.add_theme_stylebox_override("normal", box(fill, fill, 9, 10))
	control.add_theme_stylebox_override("hover", box(fill.lightened(0.15), fill.lightened(0.18), 9, 10))
	control.add_theme_stylebox_override("pressed", box(fill.darkened(0.13), fill.darkened(0.1), 9, 10))
	var focus := box(fill, GOLD, 9, 10)
	control.add_theme_stylebox_override("focus", focus)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(color, ink)
