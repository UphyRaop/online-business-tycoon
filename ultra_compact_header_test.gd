extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const Calendar = preload("res://game_calendar.gd")
const Catalog = preload("res://catalog.gd")
const Style = preload("res://corporate_theme.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func overlaps(first: Control, second: Control) -> bool:
	return first.get_global_rect().intersects(second.get_global_rect())

func run() -> void:
	var app := MainScene.instantiate()
	root.size = Vector2i(1366, 768)
	root.add_child(app)
	await process_frame
	app.sim = Sim.new(Sim.register("Header CEO", "UR Trade Network", "", 0, 0, 0, 58921))
	app.screen = "Game"
	app.page = "Dashboard"
	app.sim.state.cash = 987654321
	app._open_developer_mode_now()
	app.screen = "Game"
	app.page = "Dashboard"
	app.render()
	var date: Label
	var bank_value: Label
	var viewports := [
		Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(768, 1024),
		Vector2i(1024, 768), Vector2i(390, 844), Vector2i(375, 667), Vector2i(844, 390)
	]
	for viewport in viewports:
		root.size = viewport
		root.content_scale_size = viewport
		await process_frame
		app.render()
		await process_frame
		await process_frame
		var header := app.find_child("UltraCompactGlobalHeader", true, false) as PanelContainer
		var primary := app.find_child("GameHeaderPrimaryRow", true, false) as HBoxContainer
		var menu := app.find_child("NavigationMenuButton", true, false) as Button
		var title := app.find_child("HeaderGameTitle", true, false) as Label
		var company := app.find_child("HeaderCompanyName", true, false) as Label
		date = app.find_child("GameDate", true, false) as Label
		var bank_title := app.find_child("HeaderBankBalanceLabel", true, false) as Label
		bank_value = app.find_child("HeaderBankBalanceValue", true, false) as Label
		var advance := app.find_child("GlobalAdvanceDayControls", true, false) as HBoxContainer
		expect(header != null and primary != null, "Shared compact header exists at %s" % viewport)
		expect(primary != null and primary.get_child_count() > 0 and primary.get_child(0) == menu,
			"Hamburger menu is the first, far-left header control at %s" % viewport)
		expect(title != null and title.text == "ONLINE BUSINESS TYCOON", "Full game title is present at %s" % viewport)
		expect(company != null and company.text == "UR Trade Network" and company.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
			"Full company name is shown without truncation at %s" % viewport)
		expect(date != null and date.text == "Day 1 · %s · Malaysia" % Calendar.format(1) and not date.text.contains("\n"),
			"Day, full simulation date, and country are dynamically displayed at %s" % viewport)
		expect(bank_title != null and bank_title.text == "Bank Balance" and bank_value != null
			and bank_value.text == app.money(987654321), "Actual formatted bank balance is visible at %s" % viewport)
		expect(advance != null and advance.find_child("AdvanceDayLabel", true, false) != null,
			"Advance Day label and controls are visible at %s" % viewport)
		for days in [1, 2, 7, 30]:
			expect(advance != null and advance.find_child("AdvanceDays%d" % days, true, false) is Button,
				"Advance Day +%d is present at %s" % [days, viewport])
		expect(app.find_child("DeveloperModeButton", true, false) is Button,
			"Developer Mode entry point is available in debug testing at %s" % viewport)
		if primary != null:
			for left_index in primary.get_child_count():
				for right_index in range(left_index + 1, primary.get_child_count()):
					var left_control := primary.get_child(left_index) as Control
					var right_control := primary.get_child(right_index) as Control
					if left_control != null and right_control != null:
						expect(not overlaps(left_control, right_control),
							"Top-row controls %s and %s do not overlap at %s" % [left_control.name, right_control.name, viewport])
		if viewport.x < 600:
			var mobile_advance: VBoxContainer = app.find_child("MobileAdvanceDayGroup", true, false)
			var balance_and_advance: HBoxContainer = app.find_child("MobileBalanceAndAdvanceRow", true, false)
			expect(date.get_parent().name == "GameHeaderSecondaryRow"
				and balance_and_advance != null and mobile_advance != null
				and mobile_advance.get_child(0).name == "AdvanceDayGroupLabel"
				and mobile_advance.get_child(1).name == "GlobalAdvanceDayControls",
				"Mobile header puts full date on row two and bank/advance information on row three at %s" % viewport)
			if balance_and_advance != null and balance_and_advance.get_child_count() >= 2:
				expect(not overlaps(balance_and_advance.get_child(0) as Control, balance_and_advance.get_child(1) as Control),
					"Mobile bank balance and Advance Day controls do not overlap at %s" % viewport)
		else:
			expect(app.find_child("CompanyBankBalance", true, false) != null,
				"Desktop and tablet keep bank balance beside company information at %s" % viewport)
			if viewport.x >= 760 and advance != null:
				expect(not overlaps(date, advance), "Date and Advance Day stay separate on row two at %s" % viewport)
		var content_width: float = app.get_viewport_rect().size.x
		expect(header != null and header.get_global_rect().position.x >= 0
			and header.get_global_rect().end.x <= content_width + 1,
			"Header remains within the viewport at %s" % viewport)
		expect(header != null and header.size.y <= (160 if viewport.x < 600 else 130),
			"Header remains compact in logical layout at %s" % viewport)
		var action_buttons := [menu, app.find_child("DeveloperModeButton", true, false),
			advance.find_child("AdvanceDays1", true, false) if advance != null else null,
			advance.find_child("AdvanceDays2", true, false) if advance != null else null,
			advance.find_child("AdvanceDays7", true, false) if advance != null else null,
			advance.find_child("AdvanceDays30", true, false) if advance != null else null]
		for candidate in action_buttons:
			if candidate is Control:
				var rect := (candidate as Control).get_global_rect()
				expect(rect.position.x >= 0 and rect.end.x <= content_width + 1,
					"Header control %s is not clipped at %s" % [(candidate as Control).name, viewport])
		if menu != null:
			menu.pressed.emit()
			expect(app.navigation_open, "Hamburger opens the existing navigation drawer at %s" % viewport)
			menu.pressed.emit()
			expect(not app.navigation_open, "Hamburger closes the existing navigation drawer at %s" % viewport)
		# Header controls stay shared when the user opens non-game gameplay screens.
		app.screen = "Settings"
		app.render()
		await process_frame
		expect(app.find_child("UltraCompactGlobalHeader", true, false) != null,
			"Shared global header remains visible on Settings at %s" % viewport)
		app.screen = "Game"
		app.render()
		await process_frame
		# Exercise very long saved names and large negative balances without mutating save files.
		app.sim.state.company = "UR Trade Network International Holdings and Global Commerce Group"
		app.sim.state.cash = -987654321
		app._update_header_text()
		company = app.find_child("HeaderCompanyName", true, false) as Label
		bank_value = app.find_child("HeaderBankBalanceValue", true, false) as Label
		expect(company != null and company.text == app.sim.state.company
			and company.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
			"Long company name remains complete without ellipsis at %s" % viewport)
		expect(bank_value != null and bank_value.text == app.money(-987654321),
			"Large negative balance retains its full sign, currency, and precision at %s" % viewport)
		expect(bank_value != null and bank_value.get_theme_color("font_color") == Style.RED,
			"Negative balance uses the warning color at %s" % viewport)
		app.sim.state.company = "UR Trade Network"
		app.sim.state.cash = 987654321
		app.screen = "Game"
		app.page = "Dashboard"
		app._update_header_text()
	app.sim.advance(364)
	app.sim.state.country = 2
	app._update_header_text()
	date = app.find_child("GameDate", true, false) as Label
	expect(date != null and date.text == "Day 365 · %s · United Kingdom" % Calendar.format(365),
		"Long country labels and year-end dates are calculated from active simulation state")
	for days in [1, 2, 7, 30]:
		var current_day: int = app.sim.state.day
		var day_button := app.find_child("AdvanceDays%d" % days, true, false) as Button
		expect(day_button != null, "Advance Day +%d remains available before execution" % days)
		if day_button == null: continue
		day_button.pressed.emit()
		var confirmation: ConfirmationDialog = app.confirmation
		expect(confirmation != null and app.day_advance_pending
			and confirmation.dialog_text.contains("Current day: Day %d" % current_day)
			and confirmation.dialog_text.contains("Destination: Day %d" % (current_day + days)),
			"Advance Day +%d confirms the actual simulation destination" % days)
		if confirmation != null: confirmation.confirmed.emit()
		await process_frame
		date = app.find_child("GameDate", true, false) as Label
		bank_value = app.find_child("HeaderBankBalanceValue", true, false) as Label
		expect(app.sim.state.day == current_day + days
			and date != null and date.text == "Day %d · %s · United Kingdom" % [app.sim.state.day, Calendar.format(app.sim.state.day)],
			"Advance Day +%d updates the actual day and date label" % days)
		expect(bank_value != null and bank_value.text == app.money(app.sim.state.cash),
			"Advance Day +%d refreshes the balance from active simulation state" % days)
	app.queue_free()
	await process_frame
	print("Ultra Compact V3 Header: %d failures" % failures)
	quit(0 if failures == 0 else 1)
