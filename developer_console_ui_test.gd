extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const API = preload("res://developer_test_api.gd")
const Style = preload("res://corporate_theme.gd")

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
		push_error("Developer Console UI test requires a debug build."); quit(1); return
	var app := MainScene.instantiate()
	root.size = Vector2i(1366, 768)
	root.add_child(app)
	await process_frame
	app.sim = Sim.new(Sim.register("Normal CEO", "Normal Business", "", 0, 0, 0, 6402))
	app.active_game_id = "normal-source"
	app.screen = "Game"; app.page = "Dashboard"; app.render()
	var normal_copy: Dictionary = app.sim.state.duplicate(true)
	expect(button(app, "DeveloperModeButton") != null, "Developer Mode is visible in gameplay on desktop")
	button(app, "DeveloperModeButton").pressed.emit()
	var access_dialog := app.find_child("DeveloperAccessDialog", true, false) as ColorRect
	var access_code := app.find_child("DeveloperAccessCode", true, false) as LineEdit
	expect(access_dialog != null and access_code != null,
		"Developer Mode button opens an access-code dialog instead of granting access directly")
	if access_dialog != null and access_code != null:
		access_code.text = "invalid"
		var unlock := button(app, "DeveloperAccessUnlock")
		if unlock != null: unlock.pressed.emit()
		expect((app.find_child("DeveloperAccessError", true, false) as Label).visible,
			"Unrecognized developer access code is rejected and shown in the dialog")
		access_code.text = "URTN"
		if unlock != null: unlock.pressed.emit()
	expect(app.developer_save_active and app.screen == "Developer Mode" and app.active_game_id.is_empty(),
		"Opening Developer Mode starts an isolated DEV save instead of using the normal game path")
	expect(app.normal_state_snapshot.company_id == normal_copy.company_id and app.normal_state_snapshot.cash == normal_copy.cash,
		"Opening the console preserves a recoverable normal-game snapshot")
	var isolated_state: Dictionary = app.sim.state.duplicate(true)
	app.switch_company(str(normal_copy.company_id))
	app.enter_game(normal_copy)
	expect(app.sim.state == isolated_state and app.active_game_id.is_empty(),
		"Company switching and normal company loading are blocked while DEV isolation is active")
	expect(button(app, "DeveloperModeButton") != null and app.find_child("DeveloperConsoleChoices", true, false) != null,
		"Developer console preserves the global access button and presents independent Preview Device and Cheats paths")
	tap(app, "Preview Device")
	expect(app.screen == "Developer Mode" and app.find_child("DeveloperPreviewDevicePanel", true, false) != null,
		"Preview Device selector is independently accessible")
	var before_preview: Dictionary = app.sim.state.duplicate(true)
	tap(app, "Mobile · 390 × 844")
	expect(app.screen == "Game" and app.sim.state == before_preview,
		"Selecting a portrait preview preserves simulation state and returns to gameplay")
	expect(button(app, "DeveloperModeButton") != null and app.find_child("HeaderBankBalanceValue", true, false) != null,
		"Previewed gameplay retains the Developer Mode button and global Bank Balance")
	var api := API.new()
	var negative_balance: Dictionary = api.execute("set_cash", {"amount": -4321}, app)
	var displayed_balance: Label = app.find_child("HeaderBankBalanceValue", true, false) as Label
	expect(negative_balance.ok and displayed_balance != null and displayed_balance.text == app.money(-4321)
		and displayed_balance.get_theme_color("font_color") == Style.RED,
		"Global Bank Balance updates immediately and warns for a negative balance")
	for page in ["Dashboard", "Market", "My Products", "Orders", "Pre-orders", "Business", "Finance",
		"Finance Statements", "Expense Management", "Profile", "Advertising", "Campaign Manager",
		"Advertising Analytics", "Management", "Store Profitability", "Store Listings", "Inbound Stock",
		"Supplier Relationships", "Supplier Returns"]:
		app.navigate(page)
		expect(button(app, "DeveloperModeButton") != null and app.find_child("HeaderBankBalanceValue", true, false) != null,
			"Developer Mode and Bank Balance stay available on %s" % page)
		displayed_balance = app.find_child("HeaderBankBalanceValue", true, false) as Label
		expect(displayed_balance != null and displayed_balance.text == app.money(-4321),
			"Current Bank Balance is consistent on %s" % page)
	app.open_developer_mode()
	tap(app, "Open Cheats")
	expect(app.screen == "Developer Cheats" and app.find_child("DeveloperCheatTabs", true, false) != null,
		"Cheats open independently from the preview selector")
	for tab in ["Finance", "Inventory", "Orders", "Marketing", "Company", "Time", "Scenarios"]:
		tap(app, tab)
		expect(app.screen == "Developer Cheats", "Developer cheat category %s opens" % tab)
	app.screen = "Game"; app.page = "Market"; app.render()
	var title_result: Dictionary = api.execute("navigate", {"screen": "Title"}, app)
	var has_dev_continue := false
	for candidate in app.find_children("*", "Button", true, false):
		if (candidate as Button).text == "Continue DEV Company · Normal Business": has_dev_continue = true
	expect(title_result.ok and app.screen == "Title" and has_dev_continue
		and app.find_child("SavedGameCards", true, false) == null,
		"Main Menu test navigation shows only DEV saves while a DEV save is active")
	expect(app.normal_state_snapshot.company_id == normal_copy.company_id and app.normal_state_snapshot.cash == normal_copy.cash,
		"Navigating test screens never changes the normal company snapshot")
	var response: Dictionary = api.execute("capture_screenshot", {"name": "dev-console-test"}, app)
	expect(response.has("ok") and (response.ok == false or str(response.get("path", "")).contains("obt_dev_tests/screenshots")),
		"Automation screenshot command returns a structured result for viewport capture")
	print("Developer Console UI: %d failures" % failures)
	app.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)
