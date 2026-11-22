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
const EDIT_FILL := Color("#83b7ff")
const EDIT_INK := Color("#071321")
const WARNING_FILL := Color("#ffd166")
const WARNING_INK := Color("#0c121c")
const DISABLED_FILL := Color("#252f3d")
const DISABLED_TEXT := Color("#c1cad6")
const FONT_CAPTION := 11
const FONT_BUTTON := 12
const FONT_BODY := 13
const FONT_HEADING := 14
const FONT_NAVIGATION := 13
const ICON_INDICATOR := 14
const ICON_CONTROL := 16
const ICON_NAVIGATION := 18
const ICON_HEADER := 20
const SPACE_TIGHT := 4
const SPACE_SMALL := 6
const SPACE_CONTROL := 8
const SPACE_SECTION := 12
## Shared compact-layout scale. Keep touch target dimensions separate from visual spacing.
const PAGE_MARGIN_VERTICAL := 10
const PAGE_CONTENT_GAP := 6
const PAGE_SECTION_GAP := 8
const CARD_GRID_GAP := 10
const CARD_CONTENT_GAP := 6
const INFO_ROW_GAP := 6
const NAVIGATION_TAB_GAP := 4
const BUTTON_GROUP_GAP := 6
const CARD_PADDING := 10
const CARD_INNER_PADDING := 8
const CARD_RADIUS := 10
const BUTTON_PADDING := 8
const BUTTON_TOUCH_HEIGHT := 44
const BUTTON_TOUCH_WIDTH := 44
const ROLE_PRIMARY := "primary"
const ROLE_NAVIGATION := "navigation"
const ROLE_EDIT := "edit"
const ROLE_SUCCESS := "success"
const ROLE_WARNING := "warning"
const ROLE_DESTRUCTIVE := "destructive"
const ROLE_DISABLED := "disabled"
const ROLE_SECONDARY := "secondary"
const PROPER_WORDS := {
	"ceo": "CEO", "cpm": "CPM", "cpc": "CPC", "ctr": "CTR", "cpa": "CPA", "roas": "ROAS", "roi": "ROI", "sku": "SKU", "id": "ID", "ui": "UI",
	"ebay": "eBay", "iphone": "iPhone", "woocommerce": "WooCommerce", "shein": "SHEIN", "tiktok": "TikTok", "shopify": "Shopify", "wix": "Wix", "lazada": "Lazada", "shopee": "Shopee", "godot": "Godot",
}

static func box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func card_box(fill: Color, border: Color, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	return box(fill, border, radius, CARD_PADDING)

static func normalized_font_size(requested: int, large_text: bool = false) -> int:
	var standard_size := clampi(requested, FONT_CAPTION, FONT_HEADING)
	return mini(FONT_HEADING, standard_size + (2 if large_text else 0))

static func icon_size(requested: int) -> int:
	return clampi(requested, ICON_INDICATOR, ICON_HEADER)

static func icon_texture(texture: Texture2D, requested: int) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var maximum := icon_size(requested)
	var longest_side := maxi(image.get_width(), image.get_height())
	if longest_side <= maximum:
		return texture
	var scale := float(maximum) / float(longest_side)
	var width := maxi(1, roundi(float(image.get_width()) * scale))
	var height := maxi(1, roundi(float(image.get_height()) * scale))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

static func build(large_text: bool = false) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = normalized_font_size(FONT_BODY, large_text)
	theme.set_font_size("font_size", "Label", normalized_font_size(FONT_BODY, large_text))
	theme.set_font_size("font_size", "Button", normalized_font_size(FONT_BUTTON, large_text))
	theme.set_font_size("font_size", "OptionButton", normalized_font_size(FONT_BUTTON, large_text))
	theme.set_font_size("font_size", "LineEdit", normalized_font_size(FONT_BODY, large_text))
	theme.set_font_size("font_size", "PopupMenu", normalized_font_size(FONT_BODY, large_text))
	theme.set_font_size("font_size", "AcceptDialog", normalized_font_size(FONT_BODY, large_text))
	theme.set_constant("separation", "BoxContainer", CARD_CONTENT_GAP)
	for type in ["GridContainer", "FlowContainer"]:
		theme.set_constant("h_separation", type, CARD_GRID_GAP)
		theme.set_constant("v_separation", type, CARD_GRID_GAP)
	theme.set_color("font_color", "Label", TEXT)
	for type in ["Button", "OptionButton", "LineEdit", "PopupMenu"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_pressed_color", type, GOLD)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, MUTED.darkened(0.25))
		theme.set_stylebox("normal", type, box(INPUT, LINE, 9, BUTTON_PADDING))
		theme.set_stylebox("hover", type, box(SURFACE.lightened(0.08), LINE.lightened(0.18), 9, BUTTON_PADDING))
		theme.set_stylebox("pressed", type, box(SURFACE, GOLD, 9, BUTTON_PADDING))
		var focus := box(Color.TRANSPARENT, GOLD, 9, BUTTON_PADDING)
		focus.draw_center = false
		theme.set_stylebox("focus", type, focus)
		theme.set_stylebox("disabled", type, box(BG, LINE, 9, BUTTON_PADDING))
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
	apply_button_role(control, ROLE_PRIMARY)

static func secondary(control: Button) -> void:
	apply_button_role(control, ROLE_SECONDARY)

static func success(control: Button) -> void:
	apply_button_role(control, ROLE_SUCCESS)

static func danger(control: Button) -> void:
	apply_button_role(control, ROLE_DESTRUCTIVE)

static func navigation(control: Button, selected: bool = false) -> void:
	apply_button_role(control, ROLE_NAVIGATION, selected)

static func edit(control: Button) -> void:
	apply_button_role(control, ROLE_EDIT)

static func warning(control: Button) -> void:
	apply_button_role(control, ROLE_WARNING)

static func destructive(control: Button) -> void:
	apply_button_role(control, ROLE_DESTRUCTIVE)

static func disabled(control: Button) -> void:
	apply_button_role(control, ROLE_DISABLED)

static func apply_button_role(control: Button, semantic_role: String, selected: bool = false) -> void:
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, BUTTON_TOUCH_WIDTH)
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, BUTTON_TOUCH_HEIGHT)
	control.focus_mode = Control.FOCUS_ALL
	control.disabled = semantic_role == ROLE_DISABLED
	match semantic_role:
		ROLE_PRIMARY:
			role(control, GOLD, INK)
		ROLE_NAVIGATION:
			var fill := GOLD if selected else SURFACE
			var ink := INK if selected else TEXT
			role(control, fill, ink)
			control.add_theme_stylebox_override("normal", box(fill, GOLD if selected else LINE, 9, 10))
			control.add_theme_stylebox_override("hover", box(fill.lightened(0.12), GOLD if selected else LINE.lightened(0.18), 9, 10))
		ROLE_EDIT:
			role(control, EDIT_FILL, EDIT_INK)
		ROLE_SUCCESS:
			role(control, GREEN, SUCCESS_INK)
		ROLE_WARNING:
			role(control, WARNING_FILL, WARNING_INK)
		ROLE_DESTRUCTIVE:
			role(control, RED, DANGER_INK)
		ROLE_DISABLED:
			control.add_theme_stylebox_override("disabled", box(DISABLED_FILL, LINE, 9, 10))
			control.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
		_:
			role(control, SURFACE, TEXT)

static func button_role_for_action(title: String) -> String:
	var name := title.strip_edges().to_lower()
	if name.begins_with("delete") or name.begins_with("remove") or name.begins_with("permanently remove") or name.begins_with("stop") or name.begins_with("deactivate") or name.begins_with("unpublish") or name.begins_with("sell company") or name.begins_with("reset"):
		return ROLE_DESTRUCTIVE
	if name.begins_with("edit") or name.begins_with("change") or name.begins_with("update"):
		return ROLE_EDIT
	if name.begins_with("pause") or name.begins_with("hold"):
		return ROLE_WARNING
	if name.begins_with("save") or name.begins_with("confirm") or name.begins_with("complete") or name.begins_with("approve") or name.contains("refund"):
		return ROLE_SUCCESS
	if name.begins_with("create") or name.begins_with("register") or name.begins_with("continue") or name.begins_with("apply") or name.begins_with("launch") or name.begins_with("publish") or name.begins_with("purchase") or name.begins_with("buy ") or name.begins_with("reactivate"):
		return ROLE_PRIMARY
	if name == "cancel" or name == "back" or name == "close" or name == "menu" or name == "switch" or name.begins_with("discard") or name == "previous" or name == "next" or name.begins_with("open ") or name.begins_with("manage") or name.begins_with("view "):
		return ROLE_NAVIGATION
	return ROLE_SECONDARY

static func role(control: Button, fill: Color, ink: Color) -> void:
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, BUTTON_TOUCH_WIDTH)
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, BUTTON_TOUCH_HEIGHT)
	control.add_theme_stylebox_override("normal", box(fill, fill, 9, BUTTON_PADDING))
	control.add_theme_stylebox_override("hover", box(fill.lightened(0.15), fill.lightened(0.18), 9, BUTTON_PADDING))
	control.add_theme_stylebox_override("pressed", box(fill.darkened(0.13), fill.darkened(0.1), 9, BUTTON_PADDING))
	var focus := box(fill, GOLD, 9, BUTTON_PADDING)
	control.add_theme_stylebox_override("focus", focus)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(color, ink)

static func heading_text(value: String) -> String:
	var words := value.strip_edges().split(" ", false)
	for index in words.size():
		var word: String = words[index]
		var prefix := ""
		while not word.is_empty() and word.substr(0, 1) in ["(", "[", "\"", "'"]:
			prefix += word.substr(0, 1)
			word = word.substr(1)
		var suffix := ""
		while not word.is_empty() and word.substr(word.length() - 1, 1) in [")", "]", "\"", "'", ":", ",", ".", "?", "!"]:
			suffix = word.substr(word.length() - 1, 1) + suffix
			word = word.substr(0, word.length() - 1)
		var key := word.to_lower()
		if PROPER_WORDS.has(key):
			words[index] = prefix + str(PROPER_WORDS[key]) + suffix
		elif word == word.to_upper() or (word != word.to_lower() and word != word.to_upper()):
			continue
		elif index > 0 and word.to_lower() in ["and", "or", "of", "for", "to", "in", "on", "at", "by", "from", "with", "per"]:
			words[index] = prefix + word.to_lower() + suffix
		elif not word.is_empty():
			words[index] = prefix + word.substr(0, 1).to_upper() + word.substr(1) + suffix
	return " ".join(words)

static func sentence_text(value: String) -> String:
	var text := value.strip_edges()
	if text.is_empty(): return text
	var first_space := text.find(" ")
	var first_word := text.substr(0, first_space) if first_space >= 0 else text
	var core := first_word
	var suffix := ""
	while not core.is_empty() and core.substr(core.length() - 1, 1) in [")", "]", "\"", "'", ":", ",", ".", "?", "!"]:
		suffix = core.substr(core.length() - 1, 1) + suffix
		core = core.substr(0, core.length() - 1)
	if core.to_lower() in PROPER_WORDS:
		var corrected := str(PROPER_WORDS[core.to_lower()]) + suffix
		return corrected + (text.substr(first_space) if first_space >= 0 else "")
	if core != core.to_lower() and core != core.to_upper():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)
