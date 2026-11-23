extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const API = preload("res://developer_test_api.gd")
const SaveValidation = preload("res://save_store.gd")
const GameStore = preload("res://game_store.gd")
const Slots = preload("res://save_slots.gd")
const StoreManager = preload("res://store_manager.gd")
const Finance = preload("res://finance_management.gd")
const CEOProfile = preload("res://ceo_profile.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	if not OS.is_debug_build():
		push_error("This suite must run in a debug test build.")
		quit(1)
		return
	var app := MainScene.instantiate()
	root.size = Vector2i(1280, 720)
	root.add_child(app)
	await process_frame
	var created_game := GameStore.create_game("Active CEO", "Active Career")
	expect(created_game.get("error", "") == "", "An existing player profile is created for the active game fixture")
	var game_id := str(created_game.get("game", {}).get("game_id", "active-game"))
	var normal: Dictionary = Sim.register("Active CEO", "Active Company", "Active Brand", 0, 0, 0, 1101)
	var profile: Dictionary = CEOProfile.register_company(created_game.profile, normal)
	app.sim = Sim.new(normal)
	app.ceo_profile = profile.duplicate(true)
	app.active_game_id = game_id
	app.screen = "Game"
	app.page = "Dashboard"
	app.developer_mode_unlocked = false
	var initial_cash: int = int(app.sim.state.cash)
	expect(Slots.write_for_game(game_id, Slots.AUTOSAVE, normal, profile) == OK,
		"The active player autosave fixture is written before Developer Mode opens")
	var autosave_path := Slots.path_for_game(game_id, Slots.AUTOSAVE)
	var original_autosave := FileAccess.get_file_as_bytes(autosave_path)
	var original_profile: Dictionary = app.ceo_profile.duplicate(true)
	var api := API.new()
	var denied := api.execute("set_cash", {"amount": -999999}, app)
	expect(not denied.ok and int(app.sim.state.cash) == int(normal.cash),
		"Developer actions are rejected until URTN unlocks the current session")
	app.open_developer_mode()
	var active_snapshot: Dictionary = app.sim.state.duplicate(true)
	var active_id: String = app.active_game_id
	expect(app.developer_mode_unlocked and app.screen == "Developer Mode" and app.page == "Dashboard",
		"Unlock opens the dedicated Developer Mode page while retaining the previous gameplay route")
	expect(app.sim.state == active_snapshot and app.active_game_id == active_id and app.ceo_profile == original_profile,
		"Unlock preserves the active company, save identity, simulation, and CEO profile")
	expect(app.developer_mode_unlocked and app.active_game_id == active_id,
		"Unlock stays attached to the selected active player game")
	var set_cash := api.execute("set_cash", {"amount": 1234500}, app)
	expect(set_cash.ok and int(app.sim.state.cash) == 1234500 and app.developer_changes_active,
		"Finance cheat changes the current company's live balance")
	var cash_assert := api.execute("assert_state", {"check_cash_ledger": true, "check_balance_sheet": true, "validate_save": true}, app)
	expect(cash_assert.ok, "Finance changes preserve ledger, balance-sheet, and save invariants")
	expect(FileAccess.get_file_as_bytes(autosave_path) == original_autosave,
		"Developer changes do not silently overwrite the existing autosave")
	var backup: Dictionary = app.create_developer_backup()
	expect(backup.ok and FileAccess.file_exists(str(backup.path)), "Current active game can be backed up without replacing a save")
	if backup.ok and FileAccess.file_exists(str(backup.path)):
		var backup_file := FileAccess.open(str(backup.path), FileAccess.READ)
		var backup_data: Dictionary = backup_file.get_var(false)
		backup_file.close()
		expect(backup_data.get("game_id", "") == game_id and backup_data.state == app.sim.state
			and backup_data.ceo_profile == app.ceo_profile and backup_data.slots.has(str(Slots.AUTOSAVE)),
			"Backup contains the active session, CEO profile, and current save-slot bytes")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(backup.path)))
	var add_money := api.execute("add_money", {"amount": 500}, app)
	expect(add_money.ok and int(app.sim.state.cash) == 1235000, "Add Money applies to the active company")
	var add_stock := api.execute("add_inventory", {"product": 0, "quantity": 4}, app)
	expect(add_stock.ok and app.sim.stock(0) == 4, "Inventory cheat adds stock to the active company")
	expect(SaveValidation.valid(app.sim.state), "Developer inventory passes save validation")
	var store_error := StoreManager.create(app.sim.state, "Existing Store", 0, "Active Brand", "", 0)
	expect(store_error.is_empty(), "The functional fixture creates an ordinary active marketplace store")
	var store: Dictionary = app.sim.state.stores.back()
	var listing_error := StoreManager.set_listing(app.sim.state, int(store.id), 0, 150000, true)
	expect(listing_error.is_empty(), "The active product is listed for order and campaign tool coverage")
	var add_orders := api.execute("generate_orders", {"count": 10, "product": 0}, app)
	var generated: int = app.sim.state.orders.values().filter(func(order): return order.get("developer_generated", false)).size()
	expect(add_orders.ok and generated == 10, "Sales and Orders tool uses the active store and normal fulfillment service")
	for scenario in ["High ROAS", "Low ROAS", "Budget Exhausted", "Zero Conversions"]:
		var campaign_result: Dictionary = api.execute("apply_marketing_scenario", {"scenario": scenario, "product": 0}, app)
		expect(campaign_result.ok, "Marketing scenario %s applies to the active company's listed product" % scenario)
	expect(app.sim.state.advertising.campaigns.size() == 4, "Marketing tools create campaigns in the active simulation")
	var reputation := api.execute("set_reputation", {"value": 100}, app)
	var expansion := api.execute("unlock_expansion", {}, app)
	expect(reputation.ok and app.sim.state.reputation == 100 and expansion.ok,
		"Company tools modify the active company's profile values")
	var old_day := int(app.sim.state.day)
	var advance := api.execute("advance_days", {"days": 7}, app)
	expect(advance.ok and int(app.sim.state.day) == old_day + 7, "Time tool advances the current simulation")
	var cash_before_safe_scenario := int(app.sim.state.cash)
	var orders_before_safe_scenario: int = app.sim.state.orders.size()
	var day_before_safe_scenario := int(app.sim.state.day)
	var normal_scenario := api.execute("reset_scenario", {"scenario": "Normal Business"}, app)
	expect(normal_scenario.ok and app.sim.state.orders.size() == orders_before_safe_scenario
		and app.sim.state.day == day_before_safe_scenario and app.sim.state.cash == cash_before_safe_scenario,
		"Selecting Normal Business no longer resets the active company")
	var shortage := api.execute("reset_scenario", {"scenario": "Stock Shortage"}, app)
	expect(shortage.ok and app.sim.stock(0) == 0, "Stock Shortage applies only its explicit scenario effect to active inventory")
	var state_assert := api.execute("assert_state", {"check_cash_ledger": true, "check_balance_sheet": true, "validate_save": true}, app)
	expect(state_assert.ok, "All applied active-session cheats retain financial and save invariants")
	var final_cash: int = int(app.sim.state.cash)
	app.developer_console_visible = false
	app.developer_mode_unlocked = false
	expect(app.sim.state.company == "Active Company" and app.active_game_id == active_id
		and final_cash != initial_cash and int(app.sim.state.cash) == final_cash,
		"Lock hides Developer Mode without reverting active-game changes")
	expect(FileAccess.get_file_as_bytes(autosave_path) == original_autosave,
		"Locking does not write changes into the existing autosave")
	var save_result: bool = app.write_progress(1, "Explicit developer test save", true)
	expect(save_result, "Player can explicitly save developer changes through an existing manual slot")
	var saved_slot := Slots.read_for_game(game_id, 1)
	expect(not saved_slot.is_empty() and int(saved_slot.state.cash) == int(app.sim.state.cash)
		and int(saved_slot.state.day) == int(app.sim.state.day), "Explicit save/load path preserves current developer changes")
	expect(app.active_game_id == active_id and app.ceo_profile.ceo_id == original_profile.ceo_id
		and app.ceo_profile.full_name == original_profile.full_name
		and app.ceo_profile.companies[0].company_id == original_profile.companies[0].company_id
		and app.ceo_profile.companies[0].ownership_status == original_profile.companies[0].ownership_status,
		"Explicit save retains the same player game and CEO profile")
	app.enter_game(saved_slot.state)
	expect(app.active_game_id == active_id and int(app.sim.state.cash) == final_cash
		and int(app.sim.state.day) == int(saved_slot.state.day),
		"Reloading the saved company restores the developer changes using the existing save path")
	print("Developer active profile API: %d failures" % failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
