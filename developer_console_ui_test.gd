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

func button_text(app: Node, text: String) -> Button:
	for item in app.find_children("*", "Button", true, false):
		var candidate := item as Button
		if candidate != null and candidate.text == text and candidate.is_visible_in_tree(): return candidate
	return null

func tap(app: Node, text: String) -> void:
	var candidate := button_text(app, text)
	if candidate != null:
		candidate.pressed.emit()
		return
	expect(false, "Expected visible button: " + text)

func final_tool_button(app: Node) -> Button:
	var tools := app.find_child("DeveloperActiveToolCategory", true, false) as Control
	if tools == null: return null
	var buttons := tools.find_children("*", "Button", true, false)
	return buttons.back() as Button if not buttons.is_empty() else null

func run() -> void:
	if not OS.is_debug_build():
		push_error("Developer Mode UI test requires a debug build.")
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
	for viewport in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1024, 768),
		Vector2i(768, 1024), Vector2i(390, 844), Vector2i(375, 667), Vector2i(360, 800),
		Vector2i(844, 390), Vector2i(667, 375)]:
		root.size = viewport
		app.size = viewport
		app.render()
		await process_frame
		var access_button := button(app, "DeveloperModeButton")
		expect(access_button != null, "Developer Mode entry remains available at %s" % viewport)
		if access_button == null: continue
		access_button.pressed.emit()
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
			var access_scroll := app.find_child("DeveloperAccessScroll", true, false) as ScrollContainer
			expect(access_scroll != null and access_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
				and access_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
				"Access dialog scrolls vertically without horizontal overflow at %s" % viewport)
		if input != null and unlock != null:
			input.grab_focus()
			input.text = "invalid"
			unlock.pressed.emit()
			var error_label := app.find_child("DeveloperAccessError", true, false) as Label
			expect(error_label != null and error_label.visible and not app.developer_mode_unlocked,
				"Incorrect access code is rejected at %s" % viewport)
			var state_before_cancel: Dictionary = app.sim.state.duplicate(true)
			button(app, "DeveloperAccessCancel").pressed.emit()
			await process_frame
			expect(not is_instance_valid(input) or app.get_viewport().gui_get_focus_owner() != input,
				"Cancel releases focus from the access code at %s" % viewport)
			expect(app.screen == "Game" and app.sim.state == state_before_cancel and app.active_game_id == "normal-source",
				"Cancel leaves the active route and game untouched at %s" % viewport)
	app.size = Vector2i(1366, 768)
	root.size = Vector2i(1366, 768)
	app.render()
	await process_frame
	button(app, "DeveloperModeButton").pressed.emit()
	var code := app.find_child("DeveloperAccessCode", true, false) as LineEdit
	code.text = "URTN"
	button(app, "DeveloperAccessUnlock").pressed.emit()
	expect(app.developer_access_unlock_pending and app.developer_access_overlay == null,
		"Successful unlock removes the access dialog before the session handoff")
	app.request_developer_mode_access()
	expect(app.developer_access_unlock_pending and app.developer_access_overlay == null and not app.developer_console_visible,
		"Repeated entry taps during the handoff cannot open a second page or dialog")
	await create_timer(0.4).timeout
	await process_frame
	expect(not app.developer_access_unlock_pending, "Access handoff guard clears after Developer Mode opens")
	expect(app.developer_mode_unlocked and app.developer_console_visible and app.screen == "Developer Mode",
		"URTN opens a dedicated Developer Mode page")
	expect(app.page == "Dashboard" and app.sim.state == original_state and app.active_game_id == "normal-source"
		and app.ceo_profile == original_profile,
		"Opening the page preserves the active game state, current page, save identity, and CEO profile")
	expect(button(app, "DeveloperConsoleClose") != null and button(app, "DeveloperConsoleClose").text == "Back"
		and button(app, "DeveloperConsoleLock") != null,
		"Dedicated page header provides Back and Lock actions")
	expect(app.find_child("DeveloperConsolePanel", true, false) != null
		and app.find_child("DeveloperPrimaryTabs", true, false) != null
		and button(app, "DeveloperOpenPreview") != null and button(app, "DeveloperOpenCheats") != null,
		"Developer Mode page shows the active session and dedicated Preview Device and Cheats navigation")
	for label_text in ["Normal CEO", "Normal Business", "Simulation Day", "Bank Balance", "Save Status", "URTN is a public convenience code"]:
		expect(app.find_children("*", "Label", true, false).any(func(node): return str((node as Label).text).contains(label_text)),
			"Developer Mode page displays %s" % label_text)
	var initial_scroll := app.find_child("DeveloperConsoleScroll", true, false) as ScrollContainer
	expect(initial_scroll != null and initial_scroll.get_parent() != null
		and app.find_children("*", "ScrollContainer", true, false).size() == 1,
		"Developer pages use one normal in-layout scroll region instead of a popup or nested scroll area")

	var state_before_preview: Dictionary = app.sim.state.duplicate(true)
	tap(app, "Preview Device")
	await process_frame
	expect(app.screen == "Developer Preview" and app.find_child("DeveloperPreviewDevicePanel", true, false) != null,
		"Preview Device opens its own full page")
	for device in ["Desktop", "Tablet", "Mobile"]:
		expect(button(app, "DeveloperPreview_%s" % device) != null,
			"%s Preview control is available on the Preview Device page" % device)
	tap(app, "Mobile · 390 × 844")
	await process_frame
	expect(app.screen == "Developer Preview" and app.developer_preview_active
		and app.sim.state == state_before_preview and app.active_game_id == "normal-source",
		"Preview Device works without leaving or changing the active game")
	tap(app, "Restore Original Viewport")
	await process_frame
	expect(not app.developer_preview_active, "Restore Original Viewport clears the active preview")
	button(app, "DeveloperConsoleClose").pressed.emit()
	await process_frame
	expect(app.screen == "Developer Mode", "Back from Preview Device returns to Developer Mode")
	tap(app, "Cheats")
	await process_frame
	expect(app.screen == "Developer Cheats" and app.find_child("DeveloperCheatTabs", true, false) != null,
		"Cheats opens its own page with the existing tool categories")
	for category in ["Finance", "Inventory", "Sales & Orders", "Marketing", "Company", "Time", "Scenarios"]:
		tap(app, category)
		await process_frame
		expect(app.screen == "Developer Cheats" and app.find_child("DeveloperActiveToolCategory", true, false) != null,
			"Developer category %s remains available on the Cheats page" % category)
	expect(app.sim.state == original_state and app.active_game_id == "normal-source",
		"Opening and switching developer pages does not alter player state")
	button(app, "DeveloperConsoleClose").pressed.emit()
	await process_frame
	expect(app.screen == "Developer Mode", "Back from Cheats returns to Developer Mode")
	tap(app, "Cheats")
	await process_frame
	var api := API.new()
	var changed := api.execute("set_cash", {"amount": 432100}, app)
	expect(changed.ok and int(app.sim.state.cash) == 432100 and app.developer_changes_active,
		"Finance cheat updates the current company and marks the change unsaved")
	app.close_developer_console()
	await process_frame
	expect(not app.developer_console_visible and app.screen == "Game" and app.page == "Dashboard"
		and int(app.sim.state.cash) == 432100 and app.active_game_id == "normal-source",
		"Back from Cheats returns to the original gameplay page without reverting active-game changes")
	app.request_developer_mode_access()
	await process_frame
	expect(app.screen == "Developer Mode", "Unlocked header entry returns to the dedicated Developer Mode page")
	button(app, "DeveloperConsoleLock").pressed.emit()
	await process_frame
	expect(not app.developer_mode_unlocked and app.screen == "Game" and app.page == "Dashboard"
		and int(app.sim.state.cash) == 432100 and app.active_game_id == "normal-source",
		"Lock returns to the original route without resetting game state")

	app.developer_mode_unlocked = true
	app.developer_console_visible = true
	app.developer_return_screen = "Game"
	app.developer_return_page = "Dashboard"
	app.screen = "Developer Cheats"
	app.developer_console_tab = "Cheats"
	for viewport in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1024, 768),
		Vector2i(768, 1024), Vector2i(390, 844), Vector2i(375, 667), Vector2i(360, 800),
		Vector2i(844, 390), Vector2i(667, 375)]:
		root.size = viewport
		app.size = viewport
		for category in ["Finance", "Inventory", "Sales & Orders", "Marketing", "Company", "Time", "Scenarios"]:
			app.developer_cheat_category = category
			app.render()
			await process_frame
			await process_frame
			var console_scroll := app.find_child("DeveloperConsoleScroll", true, false) as ScrollContainer
			var tool_panel := app.find_child("DeveloperActiveToolCategory", true, false) as Control
			var last_option := final_tool_button(app)
			expect(console_scroll != null and console_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
				and console_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
				and console_scroll.mouse_force_pass_scroll_events and console_scroll.scroll_deadzone >= 8,
				"Developer content uses one vertical, touch/wheel-capable page scroll at %s" % viewport)
			expect(tool_panel != null and last_option != null and last_option.mouse_filter == Control.MOUSE_FILTER_PASS,
				"%s developer controls and final action remain available at %s" % [category, viewport])
			var header := app.find_child("DeveloperConsoleHeader", true, false) as Control
			var back := button(app, "DeveloperConsoleClose")
			var lock := button(app, "DeveloperConsoleLock")
			expect(header != null and back != null and lock != null and console_scroll != null
				and not console_scroll.is_ancestor_of(header),
				"Back and Lock remain outside the scroll area at %s" % viewport)
			if back != null and lock != null:
				expect(back.get_global_rect().size.x <= 100.0 and lock.get_global_rect().size.x <= 100.0,
					"Developer Mode header actions remain compact at %s" % viewport)
			if console_scroll != null and last_option != null:
				var bar := console_scroll.get_v_scroll_bar()
				var range := maxf(0.0, bar.max_value - bar.page) if bar != null else 0.0
				if viewport == Vector2i(667, 375):
					expect(range > 0.0, "%s tools scroll on short landscape %s" % [category, viewport])
				if range > 0.0:
					console_scroll.scroll_vertical = ceili(range)
					await process_frame
					var visible := console_scroll.get_global_rect()
					var last_rect := last_option.get_global_rect()
					expect(last_rect.position.y >= visible.position.y - 1 and last_rect.end.y <= visible.end.y + 1,
						"%s last control is reachable at the bottom of the page scroll on %s" % [category, viewport])
					var header_rect := header.get_global_rect()
					expect(back.get_global_rect().position.y >= header_rect.position.y - 1
						and lock.get_global_rect().end.y <= header_rect.end.y + 1,
						"Back and Lock stay visible while page content scrolls on %s" % viewport)
				console_scroll.scroll_vertical = 0
				await process_frame
			if category == "Scenarios":
				last_option.pressed.emit()
				await process_frame
				expect(is_instance_valid(app.confirmation), "Scenario action retains its existing confirmation")
				if is_instance_valid(app.confirmation):
					app.confirmation.get_cancel_button().pressed.emit()
					await process_frame
			var title := app.find_child("DeveloperConsoleTitle", true, false) as Label
			if viewport.x < 600 or (viewport.x > viewport.y and viewport.y < 600):
				expect(title != null and title.autowrap_mode == TextServer.AUTOWRAP_OFF,
					"Developer page title remains compact in narrow or landscape viewports at %s" % viewport)

	app.queue_free()
	await process_frame
	print("Developer full-page UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
