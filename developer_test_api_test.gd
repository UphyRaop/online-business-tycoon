extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const API = preload("res://developer_test_api.gd")
const DevStore = preload("res://developer_test_store.gd")
const SaveValidation = preload("res://save_store.gd")
const Finance = preload("res://finance_management.gd")

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
	var api := API.new()
	var normal := Sim.register("Normal Owner", "Normal Company", "", 0, 0, 0, 1101)
	app.sim = Sim.new(normal)
	app.active_game_id = "normal-game-must-not-be-used"
	app.screen = "Game"
	app.page = "Dashboard"
	var denied_before_sandbox := api.execute("set_cash", {"amount": -999999}, app)
	expect(not denied_before_sandbox.ok and denied_before_sandbox.get("code", "") == "dev_save_required"
		and int(app.sim.state.cash) == int(normal.cash),
		"Finance cheats are rejected until an isolated DEV save is active")
	expect(DevStore.ROOT != SaveValidation.PATH and DevStore.ROOT != SaveValidation.PROTOTYPE,
		"Production Developer Mode writes to a namespace separate from normal and legacy save files")
	expect(SaveValidation.save(normal) == OK, "Normal save fixture is written before sandbox isolation checks")
	var normal_save_bytes := FileAccess.get_file_as_bytes(SaveValidation.PATH)
	var created := api.execute("create_dev_company", {"source": true, "name": "DEV Isolation Test", "seed": 1102}, app)
	expect(created.ok and app.developer_save_active, "Developer command creates and activates a separate DEV save")
	expect(app.active_game_id.is_empty(), "Activating DEV data clears the normal-save target")
	expect(app.normal_state_snapshot.cash == normal.cash and app.sim.state.cash == normal.cash,
		"Starting the DEV copy preserves the original normal company state")
	var normal_cash := int(app.normal_state_snapshot.cash)
	for value in [0, 12345, 987654321, -4321]:
		var changed := api.execute("set_cash", {"amount": value}, app)
		expect(changed.ok and int(app.sim.state.cash) == value, "Set Bank Balance accepts test amount %d" % value)
		expect(SaveValidation.valid(app.sim.state), "Cash adjustment %d preserves save validation" % value)
		var assertions := api.execute("assert_state", {"check_cash_ledger": true, "check_balance_sheet": true, "validate_save": true}, app)
		expect(assertions.ok, "Cash adjustment %d preserves cash ledger and balance-sheet invariants" % value)
	expect(int(app.normal_state_snapshot.cash) == normal_cash, "Developer balance cheats do not change the normal save copy")
	api.execute("set_cash", {"amount": 100000000}, app)
	var add_stock := api.execute("add_inventory", {"product": 0, "quantity": 4}, app)
	expect(add_stock.ok and app.sim.stock(0) == 4, "Inventory cheat adds real warehouse stock lots")
	expect(SaveValidation.valid(app.sim.state), "Developer-added inventory remains covered by save validation")
	var inventory_assert := api.execute("assert_state", {"check_cash_ledger": true, "check_balance_sheet": true}, app)
	expect(inventory_assert.ok, "Inventory adjustment reconciles assets, equity, and cash")
	var empty := api.execute("empty_stock", {"product": 0}, app)
	expect(empty.ok and app.sim.stock(0) == 0 and SaveValidation.valid(app.sim.state), "Empty Stock removes warehouse lots with a matching inventory adjustment")
	var orders := api.execute("generate_orders", {"count": 10, "product": 0}, app)
	var generated := 0
	for order in app.sim.state.orders.values():
		if order.get("developer_generated", false): generated += 1
	expect(orders.ok and generated == 10, "Order cheat creates ten actual, developer-labelled order records")
	var hundred_orders := api.execute("generate_orders", {"count": 100, "product": 0}, app)
	var generated_ids: Dictionary = {}
	generated = 0
	for order in app.sim.state.orders.values():
		if order.get("developer_generated", false):
			generated += 1
			generated_ids[int(order.id)] = true
	expect(hundred_orders.ok and generated == 110 and generated_ids.size() == 110,
		"Order cheat creates 100 additional real orders with unique IDs")
	expect(SaveValidation.valid(app.sim.state), "Generated orders pass full save validation")
	var state_assert := api.execute("assert_state", {"check_cash_ledger": true, "check_balance_sheet": true, "validate_save": true}, app)
	expect(state_assert.ok, "Generated test orders preserve financial and save invariants")
	for scenario in ["High ROAS", "Low ROAS", "Budget Exhausted", "Zero Conversions"]:
		var marketing: Dictionary = api.execute("apply_marketing_scenario", {"scenario": scenario, "product": 0}, app)
		expect(marketing.ok, "Marketing cheat creates the %s scenario with the real advertising service" % scenario)
		expect(SaveValidation.valid(app.sim.state), "%s campaign passes save validation" % scenario)
	expect(app.sim.state.advertising.campaigns.size() == 4, "All four marketing test scenarios are independently addressable campaigns")
	var reputation := api.execute("set_reputation", {"value": 100}, app)
	var expansion := api.execute("unlock_expansion", {}, app)
	expect(reputation.ok and app.sim.state.reputation == 100 and expansion.ok and app.sim.state.dev_expansion_unlocked,
		"Company cheats update reputation and explicit DEV expansion state")
	var advance := api.execute("advance_days", {"days": 7}, app)
	expect(advance.ok and int(app.sim.state.day) == 8, "Time cheat runs seven actual simulation days")
	for campaign in app.sim.state.advertising.campaigns.values():
		var related: Array = app.sim.state.advertising.history.filter(func(record): return int(record.get("campaign_id", 0)) == int(campaign.id))
		var spend := 0; var revenue := 0; var conversions := 0
		for record in related:
			spend += int(record.get("spend", 0)); revenue += int(record.get("attributed_revenue", 0)); conversions += int(record.get("purchases", 0)) + int(record.get("preorders", 0))
		match str(campaign.get("developer_scenario", "")):
			"High ROAS": expect(spend > 0 and float(revenue) / spend > 1.0, "High ROAS scenario generates profitable actual advertising history")
			"Low ROAS": expect(spend > 0 and float(revenue) / spend < 1.0, "Low ROAS scenario generates underperforming actual advertising history")
			"Budget Exhausted": expect(spend > 0 and campaign.status == "completed", "Budget Exhausted scenario spends its capped daily budget and completes on schedule")
			"Zero Conversions": expect(spend > 0 and conversions == 0, "Zero Conversions scenario spends while recording zero attributed conversions")
	expect(SaveValidation.valid(app.sim.state), "Seven-day simulated DEV company passes save validation")
	var totals: Dictionary = app.sim.report_completed(7)
	var cash_lines: Dictionary = Finance.cash_flow_lines(totals)
	expect(int(cash_lines.total) == Sim.cash_change(totals), "Cash flow includes developer adjustments without treating them as profit")
	var advance_month := api.execute("advance_days", {"days": 30}, app)
	expect(advance_month.ok and int(app.sim.state.day) == 38, "Time cheat runs 30 additional real simulation days")
	var advance_year := api.execute("advance_days", {"days": 365}, app)
	expect(advance_year.ok and int(app.sim.state.day) == 403 and SaveValidation.valid(app.sim.state),
		"Time cheat processes a full 365-day simulation and retains a valid save")
	var long_run_assert := api.execute("assert_state", {"check_cash_ledger": true, "check_balance_sheet": true, "validate_save": true}, app)
	expect(long_run_assert.ok, "365-day simulation preserves cash, balance-sheet, and save invariants")
	var reset := api.execute("reset_dev", {"id": app.dev_record.id}, app)
	expect(reset.ok and int(app.sim.state.day) == 1 and app.sim.state.orders.is_empty(), "Reset DEV save returns to a fresh isolated baseline")
	var load := api.execute("load_dev", {"id": app.dev_record.id}, app)
	expect(load.ok and int(app.sim.state.day) == 1, "Saved DEV test company can be loaded independently")
	expect(int(app.normal_state_snapshot.cash) == normal_cash and app.active_game_id.is_empty(), "DEV reset/load leaves the normal save and target untouched")
	expect(FileAccess.get_file_as_bytes(SaveValidation.PATH) == normal_save_bytes,
		"Developer cheats and DEV reset/load never modify the normal save file")
	var crisis := api.execute("reset_scenario", {"scenario": "Financial Crisis"}, app)
	expect(crisis.ok and int(app.sim.state.cash) < 0 and app.dev_record.active_scenario == "Financial Crisis",
		"Financial Crisis scenario sets a negative bank balance and identifies the active scenario")
	var shortage := api.execute("reset_scenario", {"scenario": "Stock Shortage"}, app)
	expect(shortage.ok and app.sim.stock(0) == 0 and app.dev_record.active_scenario == "Stock Shortage",
		"Stock Shortage scenario clears warehouse stock and identifies the active scenario")
	var growth := api.execute("reset_scenario", {"scenario": "Rapid Growth"}, app)
	generated = 0
	for order in app.sim.state.orders.values():
		if order.get("developer_generated", false): generated += 1
	expect(growth.ok and generated == 100 and app.dev_record.active_scenario == "Rapid Growth",
		"Rapid Growth scenario creates 100 actual orders and identifies the active scenario (ok=%s, generated=%d, active=%s, message=%s)" % [str(growth.get("ok", false)), generated, str(app.dev_record.active_scenario), str(growth.get("message", ""))])
	var normal_scenario := api.execute("reset_scenario", {"scenario": "Normal Business"}, app)
	expect(normal_scenario.ok and int(app.sim.state.day) == 1 and app.sim.state.orders.is_empty()
		and app.dev_record.active_scenario == "Normal Business",
		"Normal Business restores the baseline and updates the active scenario marker")
	var protected_id := str(app.dev_record.id)
	var active_delete := api.execute("delete_dev", {"id": protected_id}, app)
	expect(not active_delete.ok and active_delete.get("code", "") == "active_dev_save"
		and FileAccess.file_exists(DevStore.ROOT.path_join(protected_id + ".dev")),
		"The active DEV test company cannot be deleted")
	var second_dev := api.execute("create_dev_company", {"source": true, "name": "DEV Deletion Target", "seed": 1103}, app)
	var delete_old := api.execute("delete_dev", {"id": protected_id}, app)
	expect(second_dev.ok and delete_old.ok and not FileAccess.file_exists(DevStore.ROOT.path_join(protected_id + ".dev")),
		"An inactive isolated DEV test company can be deleted without touching normal saves")
	var api_result := api.execute("nonsense", {}, app)
	var audit_events := DevStore.audit_events()
	var audit_last: Dictionary = audit_events.back() if not audit_events.is_empty() else {}
	expect(not api_result.ok and api_result.has("code") and api_result.has("message") and api_result.get("audit_persisted", false)
		and audit_last.get("action", "") == "nonsense" and audit_last.get("result", "") == "error",
		"Failed automation operations return structured errors and persist a separate developer audit entry")
	var delete_logged := audit_events.any(func(event: Dictionary): return event.get("action", "") == "delete_dev" and event.get("result", "") == "success")
	expect(delete_logged, "DEV save deletion is retained in the isolated JSONL audit log")
	print("Developer test API: %d failures" % failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
