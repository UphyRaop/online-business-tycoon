extends "res://phase1_ui_test.gd"

const Style = preload("res://corporate_theme.gd")
const AdsChart = preload("res://ads_chart.gd")

const GAME_PAGES := [
	"Dashboard", "Market", "My Products", "Orders", "Pre-orders", "Business", "Finance",
	"Finance Statements", "Expense Management", "Profile", "Advertising", "Campaign Manager",
	"Campaign Details", "Advertising Analytics", "Management", "Store Profitability", "Store Listings",
	"Inbound Stock", "Supplier Relationships", "Supplier Returns",
]
const MENU_SCREENS := ["Title", "New Game", "Setup", "Company Selection", "Load", "Save", "Settings"]
const VIEWPORTS := [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390)]
var max_font_seen := 0

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run typography validation with a fresh isolated profile.")
		quit(1)
		return
	root.size = VIEWPORTS[0]
	app = Main.instantiate()
	root.add_child(app)
	create_new_game_for_test("Typography QA CEO", "Typography QA Company")
	await process_frame
	var screen_checks := 0
	var standard_max := 0
	var large_text_max := 0
	for large_text in [false, true]:
		max_font_seen = 0
		app.large_text = large_text
		app.theme = Style.build(large_text)
		var limit := Style.FONT_HEADING
		expect(app.theme.default_font_size <= limit
			and app.theme.get_font_size("font_size", "PopupMenu") <= limit
			and app.theme.get_font_size("font_size", "AcceptDialog") <= limit,
			"Standard/Large Text theme defaults and popup/dialog fonts stay within the %d px limit" % limit)
		for screen_name in MENU_SCREENS:
			app.screen = screen_name
			app.render()
			await process_frame
			_check_visible_typography("%s / %s" % ["Large Text" if large_text else "Standard", screen_name], limit)
			screen_checks += 1
		# Open a real dropdown popup; its item font is supplied by the app theme.
		app.screen = "Setup"
		app.render()
		await process_frame
		var setup_options := controls(app, "OptionButton")
		if not setup_options.is_empty():
			var option := setup_options.front() as OptionButton
			option.show_popup()
			await process_frame
			_check_visible_typography("%s / open dropdown popup" % ["Large Text" if large_text else "Standard"], limit)
			expect(option.get_popup().visible and app.theme.get_font_size("font_size", "PopupMenu") <= limit,
				"Dynamically opened dropdown popup uses the bounded theme font")
			option.hide()
			await process_frame
		app.screen = "Game"
		for page_name in GAME_PAGES:
			app.page = page_name
			app.render()
			await process_frame
			_check_visible_typography("%s / %s" % ["Large Text" if large_text else "Standard", page_name], limit)
			screen_checks += 1
		# Check representative screens at each requested viewport in both modes.
		for viewport in VIEWPORTS:
			root.size = viewport
			app.size = Vector2(viewport)
			app._update_responsive_layout()
			for page_name in ["Dashboard", "Market", "Finance", "Advertising Analytics"]:
				app.page = page_name
				app.screen = "Game"
				app.render()
				await process_frame
				_check_visible_typography("%s / %s / %dx%d" % ["Large Text" if large_text else "Standard", page_name, viewport.x, viewport.y], limit)
				screen_checks += 1
			# Dynamic access dialog is created after the render pass.
			app.page = "Dashboard"
			app.render()
			await process_frame
			app.request_developer_mode_access()
			await process_frame
			_check_visible_typography("%s / Developer Mode access / %dx%d" % ["Large Text" if large_text else "Standard", viewport.x, viewport.y], limit)
			var cancel := app.find_child("DeveloperAccessCancel", true, false) as Button
			if cancel != null: cancel.pressed.emit()
			await process_frame
			app.developer_mode_unlocked = true
			app.developer_console_visible = true
			app.developer_return_screen = "Game"
			app.developer_return_page = "Dashboard"
			app.developer_console_tab = "Preview Device"
			app.screen = "Developer Preview"
			app.render()
			await process_frame
			_check_visible_typography("%s / Developer Mode preview / %dx%d" % ["Large Text" if large_text else "Standard", viewport.x, viewport.y], limit)
			app.developer_console_tab = "Cheats"
			app.screen = "Developer Cheats"
			for category in ["Finance", "Inventory", "Sales & Orders", "Marketing", "Company", "Time", "Scenarios"]:
				app.developer_cheat_category = category
				app.render()
				await process_frame
				_check_visible_typography("%s / Developer Mode / %s / %dx%d" % ["Large Text" if large_text else "Standard", category, viewport.x, viewport.y], limit)
				screen_checks += 1
			app.developer_console_visible = false
			app.developer_mode_unlocked = false
			app.screen = "Game"
			app.render()
			await process_frame
		# ConfirmationDialog contains engine-created labels/buttons and is opened dynamically.
		app.confirm_action("Typography test", "Verify dynamically opened confirmation text and actions.", "Confirm", func(): pass)
		await process_frame
		_check_visible_typography("%s / confirmation dialog" % ["Large Text" if large_text else "Standard"], limit)
		if is_instance_valid(app.confirmation):
			app.confirmation.get_cancel_button().pressed.emit()
		await process_frame
		# Text drawn directly onto a Control is verified through the same sizes used by _draw().
		var chart := AdsChart.new() as Control
		chart.theme = Style.build(large_text)
		root.add_child(chart)
		var draw_sizes: Array = chart.call("effective_draw_text_sizes")
		expect(draw_sizes.size() == 2 and draw_sizes.all(func(value): return int(value) <= limit),
			"Custom-drawn marketing chart text stays within the %d px limit in both accessibility modes" % limit)
		for draw_size in draw_sizes: max_font_seen = maxi(max_font_seen, int(draw_size))
		chart.queue_free()
		await process_frame
		if large_text: large_text_max = max_font_seen
		else: standard_max = max_font_seen
	expect(standard_max == Style.FONT_HEADING,
		"Standard runtime scan reaches the 14 px heading/financial token maximum")
	expect(large_text_max == Style.FONT_HEADING,
		"Large Text runtime scan reaches, but never exceeds, the 14 px maximum")
	print("Runtime typography validation: %d visible screen/layout checks, max standard=%d px, max Large Text=%d px, %d failures" % [screen_checks, standard_max, large_text_max, failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check_visible_typography(context: String, limit: int) -> void:
	_check_node(root, context, limit)

func _check_node(node: Node, context: String, limit: int) -> void:
	if node is Control and (node as Control).is_visible_in_tree() and _has_rendered_text(node):
		var size := (node as Control).get_theme_font_size("font_size")
		max_font_seen = maxi(max_font_seen, size)
		expect(size <= limit, "%s: %s renders at %d px (maximum %d px)" % [context, node.get_path(), size, limit])
	for child in node.get_children(true):
		_check_node(child, context, limit)

func _has_rendered_text(node: Node) -> bool:
	if node is Label:
		return not (node as Label).text.is_empty()
	if node is Button:
		return not (node as Button).text.is_empty()
	if node is LineEdit:
		return not (node as LineEdit).text.is_empty() or not (node as LineEdit).placeholder_text.is_empty()
	if node is TextEdit:
		return not (node as TextEdit).text.is_empty() or not (node as TextEdit).placeholder_text.is_empty()
	if node is RichTextLabel:
		return not (node as RichTextLabel).text.is_empty()
	return false
