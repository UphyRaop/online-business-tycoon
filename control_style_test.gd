extends SceneTree

const ThemeStyle = preload("res://corporate_theme.gd")

var failures := 0

func _initialize() -> void:
	test_semantic_button_roles()
	test_action_semantics()
	test_safe_text_formatting()
	test_global_v4_tokens()
	print("Shared control styling: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func test_semantic_button_roles() -> void:
	var roles := ["primary", "navigation", "edit", "success", "warning", "destructive", "secondary"]
	var colors: Array[Color] = []
	for role_name in roles:
		var button := Button.new()
		ThemeStyle.apply_button_role(button, role_name)
		var box := button.get_theme_stylebox("normal") as StyleBoxFlat
		var ink := button.get_theme_color("font_color")
		expect(button.custom_minimum_size.y >= ThemeStyle.BUTTON_TOUCH_HEIGHT,
			"The %s button role meets the shared touch height" % role_name)
		expect(button.custom_minimum_size.x >= ThemeStyle.BUTTON_TOUCH_WIDTH,
			"The %s button role meets the shared touch width" % role_name)
		expect(button.focus_mode == Control.FOCUS_ALL, "The %s button role remains keyboard focusable" % role_name)
		expect(contrast_ratio(box.bg_color, ink) >= 4.5, "The %s button role has readable text contrast" % role_name)
		colors.append(box.bg_color)
		button.free()
	var selected := Button.new()
	ThemeStyle.navigation(selected, true)
	var selected_box := selected.get_theme_stylebox("normal") as StyleBoxFlat
	expect(selected_box.bg_color == ThemeStyle.GOLD, "Selected navigation has a visible highlight")
	selected.free()
	var disabled_button := Button.new()
	ThemeStyle.disabled(disabled_button)
	expect(disabled_button.disabled and disabled_button.get_theme_color("font_disabled_color") == ThemeStyle.DISABLED_TEXT,
		"Disabled role blocks activation and retains legible text")
	disabled_button.free()

func test_action_semantics() -> void:
	expect(ThemeStyle.button_role_for_action("Create Campaign") == "primary", "Creation actions map to Primary")
	expect(ThemeStyle.button_role_for_action("Save Changes") == "success", "Save actions map to Positive Success")
	expect(ThemeStyle.button_role_for_action("Edit Profile") == "edit", "Editing actions map to Edit")
	expect(ThemeStyle.button_role_for_action("Pause Campaign") == "warning", "Pause actions map to Warning")
	expect(ThemeStyle.button_role_for_action("Delete Campaign") == "destructive", "Deletion actions map to Destructive")
	expect(ThemeStyle.button_role_for_action("Confirm Sale") == "success", "Confirmation actions map to Success")
	expect(ThemeStyle.button_role_for_action("Open Finance") == "navigation", "Screen navigation maps to Navigation")
	expect(ThemeStyle.button_role_for_action("Manage Campaign") == "navigation", "Record-management actions map to Navigation")
	expect(ThemeStyle.button_role_for_action("Sell Company") == "destructive", "Ownership transfer maps to Destructive")
	expect(ThemeStyle.button_role_for_action("Refresh Report") == "secondary", "Unclassified actions retain a neutral Secondary role")

func test_safe_text_formatting() -> void:
	expect(ThemeStyle.heading_text("product catalogue for WooCommerce and eBay") == "Product Catalogue for WooCommerce and eBay",
		"Heading formatting capitalizes generic words and preserves branded casing")
	expect(ThemeStyle.heading_text("CEO profile at TikTok and SHEIN") == "CEO Profile at TikTok and SHEIN",
		"Heading formatting preserves acronyms and official proper-name casing")
	expect(ThemeStyle.heading_text("units per bundle") == "Units per Bundle",
		"Heading formatting keeps short prepositions lowercase in Title Case field labels")
	expect(ThemeStyle.sentence_text("  update the store before launch.  ") == "Update the store before launch.",
		"Sentence formatting trims spacing and uppercases only the sentence start")
	expect(ThemeStyle.sentence_text("iPhone listings use WooCommerce.") == "iPhone listings use WooCommerce.",
		"Sentence formatting does not alter proper names")

func test_global_v4_tokens() -> void:
	var standard := ThemeStyle.build()
	var large := ThemeStyle.build(true)
	expect(ThemeStyle.FONT_CAPTION == 11 and ThemeStyle.FONT_BUTTON == 12
		and ThemeStyle.FONT_BODY == 13 and ThemeStyle.FONT_HEADING == 14,
		"V4 typography tokens use the approved 11, 12, 13, and 14 px hierarchy")
	expect(ThemeStyle.normalized_font_size(26) == 14 and ThemeStyle.normalized_font_size(10) == 11,
		"Standard typography clamps oversized headings and undersized captions to V4 tokens")
	expect(ThemeStyle.normalized_font_size(11) == 11 and ThemeStyle.normalized_font_size(12) == 12
		and ThemeStyle.normalized_font_size(13) == 13 and ThemeStyle.normalized_font_size(14) == 14,
		"Standard caption, button, body, and heading sizes match their approved tokens")
	expect(ThemeStyle.normalized_font_size(11, true) == 13
		and ThemeStyle.normalized_font_size(12, true) == 14
		and ThemeStyle.normalized_font_size(13, true) == 14
		and ThemeStyle.normalized_font_size(14, true) == 14
		and ThemeStyle.normalized_font_size(26, true) == 14,
		"Large Text maps captions to 13 px and caps buttons, body text, headings, and values at 14 px")
	expect(standard.default_font_size == 13 and large.default_font_size == 14,
		"Theme body size follows standard and Large Text settings")
	expect(ThemeStyle.ICON_INDICATOR == 14 and ThemeStyle.ICON_CONTROL == 16
		and ThemeStyle.ICON_NAVIGATION == 18 and ThemeStyle.ICON_HEADER == 20
		and ThemeStyle.icon_size(24) == 20,
		"V4 icon tokens define the approved size ladder and maximum")
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var resized := ThemeStyle.icon_texture(ImageTexture.create_from_image(image), ThemeStyle.ICON_CONTROL)
	expect(resized != null and resized.get_width() == ThemeStyle.ICON_CONTROL
		and resized.get_height() == ThemeStyle.ICON_CONTROL,
		"Oversized source icons are resampled to their declared V4 control size")

func contrast_ratio(background: Color, foreground: Color) -> float:
	var lighter := maxf(background.get_luminance(), foreground.get_luminance())
	var darker := minf(background.get_luminance(), foreground.get_luminance())
	return (lighter + 0.05) / (darker + 0.05)
