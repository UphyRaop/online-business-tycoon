extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const API = preload("res://developer_test_api.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func button(app: Node, name: String) -> Button:
	return app.find_child(name, true, false) as Button

func tap(app: Node, text: String) -> void:
	for item in app.find_children("*", "Button", true, false):
		var candidate := item as Button
		if candidate != null and candidate.text == text:
			candidate.pressed.emit()
			return
	expect(false, "Expected visible button: " + text)

func run() -> void:
	if not OS.is_debug_build():
		push_error("Developer Console UI test requires a debug build.")
		quit(1)
		return
	var app := MainScene.instantiate()
	root.size = Vector2i(1366, 768)
	root.add_child(app)
	await process_frame
	app.sim = Sim.new(Sim.register("Normal CEO", "Normal Business", "Business Brand", 0, 0, 0, 6402))
	app.active_game_id = "normal-source"
	app.screen = "Game"
	app.page = "Dashboard"
	app.render()
	await process_frame
	var original_state: Dictionary = app.sim.state.duplicate(true)
	var original_profile: Dictionary = app.ceo_profile.duplicate(true)
	expect(button(app, "DeveloperModeButton") != null, "Developer Mode is available in gameplay on desktop")
	for viewport in [Vector2i(390, 844), Vector2i(375, 667), Vector2i(360, 800), Vector2i(844, 390)]:
		app.size = viewport
		app.render()
		await process_frame
		button(app, "DeveloperModeButton").pressed.emit()
		await process_frame
		var dialog := app.find_child("DeveloperAccessDialog", true, false) as Control
		var panel := app.find_child("DeveloperAccessPanel", true, false) as Control
		var input := app.find_child("DeveloperAccessCode", true, false) as LineEdit
		var unlock := button(app, "DeveloperAccessUnlock")
		expect(dialog != null and input != null and input.secret and unlock != null,
			"Access dialog and keyboard-focusable code field exist at %s" % viewport)
		if panel != null:
			var rect := panel.get_global_rect()
			expect(rect.position.x >= -1 and rect.end.x <= viewport.x + 1,
				"Access dialog stays within viewport width %s" % viewport)
			var scroll := app.find_child("DeveloperAccessScroll", true, false) as ScrollContainer
			expect(scroll != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
				"Access dialog supports vertical keyboard-safe scrolling without horizontal overflow at %s" % viewport)
			expect(scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
				"Access dialog can scroll vertically when the mobile keyboard reduces available height at %s" % viewport)
		if input != null:
			input.text = "invalid"
			unlock.pressed.emit()
			var error_label := app.find_child("DeveloperAccessError", true, false) as Label
			expect(error_label != null and error_label.visible and not app.developer_mode_unlocked,
				"Incorrect access code is rejected at %s" % viewport)
			button(app, "DeveloperAccessCancel").pressed.emit()
			await process_frame
		app.size = Vector2i(1366, 768)
		app.render()
		await process_frame
	button(app, "DeveloperModeButton").pressed.emit()
	var code := app.find_child("DeveloperAccessCode", true, false) as LineEdit
	code.text = "URTN"
	button(app, "DeveloperAccessUnlock").pressed.emit()
	await process_frame
	expect(app.developer_mode_unlocked and app.developer_console_visible and app.screen == "Game"
		and app.page == "Dashboard", "URTN opens Developer Mode over the currently active gameplay screen")
	expect(app.sim.state == original_state and app.active_game_id == "normal-source"
		and app.ceo_profile == original_profile,
		"Unlock retains the active game state, company ID, CEO profile, and save path")
	expect(button(app, "DeveloperConsoleClose") != null and button(app, "DeveloperConsoleLock") != null,
		"Console offers separate Close and Lock actions")
	expect(app.find_child("DeveloperConsolePanel", true, false) != null and app.find_child("DeveloperPrimaryTabs", true, false) != null,
		"Compact overlay provides Preview Device and Cheats navigation")
	tap(app, "Preview Device")
	expect(app.developer_console_tab == "Preview Device" and app.find_child("DeveloperPreviewDevicePanel", true, false) != null,
		"Preview Device category is available for the current session")
	var state_before_preview: Dictionary = app.sim.state.duplicate(true)
	tap(app, "Mobile · 390 × 844")
	await process_frame
	expect(not app.developer_console_visible and app.sim.state == state_before_preview
		and app.active_game_id == "normal-source", "Selecting a preview preserves the current page and active simulation")
	app.set_developer_preview("exit")
	app.request_developer_mode_access()
	await process_frame
	expect(app.developer_console_visible, "Unlocked header button reopens the tools without another code or reload")
	tap(app, "Cheats")
	for category in ["Finance", "Inventory", "Sales & Orders", "Marketing", "Company", "Time", "Scenarios"]:
		tap(app, category)
		await process_frame
		expect(app.find_child("DeveloperActiveToolCategory", true, false) != null,
			"Developer category %s opens within the active-game console" % category)
	expect(app.sim.state == original_state and app.active_game_id == "normal-source",
		"Opening and switching tool categories do not change player state")
	var api := API.new()
	var changed := api.execute("set_cash", {"amount": 432100}, app)
	expect(changed.ok and int(app.sim.state.cash) == 432100 and app.developer_changes_active,
		"Finance tool updates the current company and marks the change unsaved")
	app.close_developer_console()
	expect(not app.developer_console_visible and int(app.sim.state.cash) == 432100
		and app.active_game_id == "normal-source", "Close hides tools without rolling back the active game's change")
	app.request_developer_mode_access()
	var lock := button(app, "DeveloperConsoleLock")
	lock.pressed.emit()
	expect(not app.developer_mode_unlocked and app.screen == "Game"
		and int(app.sim.state.cash) == 432100 and app.active_game_id == "normal-source",
		"Lock hides the console but leaves the changed active game and route intact")
	app.developer_mode_unlocked = true
	app.developer_console_visible = true
	app.render()
	await process_frame
	for viewport in [Vector2i(390, 844), Vector2i(375, 667), Vector2i(360, 800), Vector2i(844, 390)]:
		app.size = viewport
		app.render()
		await process_frame
		var console_panel := app.find_child("DeveloperConsolePanel", true, false) as Control
		expect(console_panel != null and console_panel.get_global_rect().size.x <= viewport.x + 1,
			"Developer console avoids horizontal overflow at %s" % viewport)
		if console_panel != null:
			expect(console_panel.get_global_rect().position.y >= -1,
				"Developer console top edge stays inside the viewport at %s" % viewport)
		var console_scroll := app.find_child("DeveloperConsoleScroll", true, false) as ScrollContainer
		expect(console_scroll != null and console_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"Developer tools use vertical scrolling at %s" % viewport)
		if viewport.x < 600 or (viewport.x > viewport.y and viewport.y < 600):
			var title := app.find_child("DeveloperConsoleTitle", true, false) as Label
			expect(title != null and title.autowrap_mode == TextServer.AUTOWRAP_OFF,
				"Mobile Developer Mode title remains on one line at %s" % viewport)
	app.queue_free()
	await process_frame
	print("Developer active-profile UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
