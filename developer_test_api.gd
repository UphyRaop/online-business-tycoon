extends RefCounted

## Developer commands mutate only the active local game session. The web automation
## bridge remains debug-only; the player-facing console is available in release builds.
const Catalog = preload("res://catalog.gd")
const Sim = preload("res://simulation.gd")
const StoreManager = preload("res://store_manager.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Advertising = preload("res://advertising.gd")
const SaveValidation = preload("res://save_store.gd")

func execute(command: String, args: Dictionary, app: Node) -> Dictionary:
	if app == null: return _result(false, "missing_app", "The game instance is unavailable.")
	var result := _dispatch(command, args, app)
	return result

func _dispatch(command: String, args: Dictionary, app: Node) -> Dictionary:
	match command:
		"create_dev_company", "load_dev", "reset_dev", "restore_dev_snapshot", "delete_dev":
			return _result(false, "unsupported", "Developer Mode works with the active company; separate DEV saves are disabled.")
		"read_state": return _read_state(app)
		"assert_state": return _assert_state(args, app)
		"navigate": return _navigate(args, app)
		"select_preview": return app.set_developer_preview(str(args.get("device", "")))
		"capture_screenshot": return _capture_screenshot(args, app)
		"set_cash": return _set_cash(args, app)
		"add_money": return _add_money(args, app)
		"add_inventory": return _add_inventory(args, app)
		"empty_stock": return _empty_stock(args, app)
		"generate_orders": return _generate_orders(args, app)
		"apply_marketing_scenario": return _marketing(args, app)
		"set_reputation": return _set_reputation(args, app)
		"unlock_expansion": return _unlock_expansion(app)
		"advance_days": return _advance_days(args, app)
		"reset_scenario": return _scenario(str(args.get("scenario", "Normal Business")), app)
		_: return _result(false, "unknown_command", "Unsupported Developer Mode command: " + command)

func _read_state(app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode before reading game state.")
	var state: Dictionary = app.sim.state
	return _result(true, "ok", "Current active game state.", {
		"developer_mode": true, "game_id": str(app.active_game_id), "day": int(state.day), "cash": int(state.cash), "currency": Catalog.CURRENCIES[int(state.country)],
		"company": str(state.company), "owner": str(state.owner), "reputation": int(state.reputation),
		"products": state.products.duplicate(true), "stores": state.stores.duplicate(true),
		"orders": state.orders.duplicate(true), "ledger": state.ledger.duplicate(true),
		"campaigns": state.advertising.campaigns.duplicate(true), "supplier_level": int(state.supplier_level),
		"expansion_unlocked": bool(state.get("dev_expansion_unlocked", false)),
		"financial_report": app.sim.report_completed(maxi(1, int(state.day) - 1))})

func _assert_state(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode before assertions.")
	var state: Dictionary = app.sim.state
	var failures: Array[String] = []
	for key in args.get("equals", {}):
		var expected: Variant = args.equals[key]
		var actual: Variant = state.get(str(key), null)
		if actual != expected: failures.append("%s expected %s, got %s" % [key, expected, actual])
	if bool(args.get("validate_save", false)) and not SaveValidation.valid(state): failures.append("Save validation failed")
	if bool(args.get("check_cash_ledger", false)):
		var computed := 0
		for row in state.ledger: computed += Sim.cash_change(row)
		if computed != int(state.cash): failures.append("cash ledger %d does not equal cash %d" % [computed, state.cash])
	if bool(args.get("check_balance_sheet", false)):
		var report: Dictionary = app.sim.report_completed(maxi(1, int(state.day) - 1))
		if int(report.assets) != int(report.liabilities) + int(report.equity_capital) + int(report.retained):
			failures.append("assets do not equal liabilities plus equity")
	if not failures.is_empty(): return _result(false, "assertion_failed", "; ".join(failures), {"failures": failures})
	return _result(true, "assertions_passed", "Requested state invariants passed.")

func _navigate(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode before navigating.")
	var target := str(args.get("page", args.get("screen", "Dashboard")))
	if target in ["Title", "Main Menu", "New Game", "Setup", "Company Selection", "Load", "Save", "Settings"]:
		app.show_screen("Title" if target == "Main Menu" else target)
	else:
		app.navigate(target)
	return _result(true, "navigated", "Navigated to %s." % target)

func _capture_screenshot(args: Dictionary, app: Node) -> Dictionary:
	if DisplayServer.get_name() in ["headless", "dummy"]:
		return _result(false, "screenshot_unavailable", "This renderer does not expose viewport pixels; capture the browser using Playwright or Chromium.")
	var directory := "user://developer_captures"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK: return _result(false, "screenshot_error", "Could not create screenshot folder: " + error_string(error))
	var name := str(args.get("name", "developer-test"))
	name = name.validate_filename().substr(0, 60)
	if name.is_empty(): name = "developer-test"
	var path := directory.path_join("%s-%d.png" % [name, Time.get_unix_time_from_system()])
	var texture: ViewportTexture = app.get_viewport().get_texture()
	if texture == null: return _result(false, "screenshot_unavailable", "This renderer does not expose a viewport texture; use Playwright or Chromium screenshot capture.")
	var capture: Image = texture.get_image()
	if capture == null or capture.is_empty(): return _result(false, "screenshot_error", "The current Godot viewport did not provide an image.")
	error = capture.save_png(path)
	if error != OK: return _result(false, "screenshot_error", "Could not save screenshot: " + error_string(error))
	return _result(true, "screenshot_saved", "Viewport screenshot saved locally.", {"path": path, "width": capture.get_width(), "height": capture.get_height()})

func _set_cash(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var value: Variant = args.get("amount", null)
	if not (value is int or value is float or (value is String and str(value).is_valid_int())): return _result(false, "invalid_amount", "Enter a whole number of minor currency units.")
	var desired := int(value)
	if app.sim.state.ledger.is_empty(): return _result(false, "ledger_required", "The active game has no ledger entry for a balanced developer adjustment.")
	var row: Dictionary = app.sim.state.ledger.back()
	var previous := int(app.sim.state.cash)
	var delta := desired - previous
	row.dev_cash_adjustment += delta
	app.sim.state.cash = desired
	return _record(app, "set_bank_balance", "finance", previous, desired, {"cash": desired})

func _add_money(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var value: Variant = args.get("amount", null)
	if not (value is int or value is float or (value is String and str(value).is_valid_int())) or int(value) <= 0:
		return _result(false, "invalid_amount", "Enter a positive whole number of minor currency units.")
	return _set_cash({"amount": int(app.sim.state.cash) + int(value)}, app)

func _add_inventory(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var product := int(args.get("product", -1)); var units := int(args.get("quantity", 0))
	if product not in range(Catalog.PRODUCTS.size()) or units < 1 or units > 100000: return _result(false, "invalid_inventory", "Choose an existing product and a quantity from 1 to 100,000.")
	var supplier := int(args.get("supplier", app.sim.product_state(product).get("supplier", Catalog.DEFAULT_SUPPLIER)))
	if supplier not in range(Catalog.SUPPLIERS.size()): return _result(false, "invalid_supplier", "Choose an existing supplier index.")
	var goods := Catalog.quote(int(app.sim.state.country), product, supplier)
	var freight_total := Catalog.inbound_freight(int(app.sim.state.country), supplier)
	var freight := mini(goods - 1, ceili(float(freight_total) / units))
	var unit_cost := goods + freight
	var previous: int = app.sim.stock(product)
	app.sim.add_stock(product, {"units": units, "cost": unit_cost, "freight": freight, "quality": float(Catalog.SUPPLIERS[supplier].quality), "dev_added": true})
	var row: Dictionary = app.sim.state.ledger.back()
	row.dev_inventory_adjustment += units * unit_cost
	var saved := _save(app)
	if not saved.get("ok", false): return saved
	app.refresh_view()
	return _result(true, "inventory_added", "Added %d units of %s to the active company." % [units, Catalog.PRODUCTS[product].name], {"stock": previous + units, "unit_cost": unit_cost})

func _empty_stock(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var product := int(args.get("product", -1))
	if product not in range(Catalog.PRODUCTS.size()): return _result(false, "invalid_product", "Choose an existing product.")
	var item: Dictionary = app.sim.product_state(product)
	var removed_value := 0
	var previous := 0
	for lot in item.lots:
		removed_value += int(lot.get("units", 0)) * int(lot.get("cost", 0)); previous += int(lot.get("units", 0))
	item.lots.clear(); app.sim.state.products[product] = item
	app.sim.state.ledger.back().dev_inventory_adjustment -= removed_value
	var saved := _save(app)
	if not saved.get("ok", false): return saved
	app.refresh_view()
	return _result(true, "stock_emptied", "Removed all warehouse lots for %s." % Catalog.PRODUCTS[product].name, {"stock": 0, "inventory_value_removed": removed_value})

func _generate_orders(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var count := int(args.get("count", 10)); var product := int(args.get("product", 0))
	if count not in [10, 100] or product not in range(Catalog.PRODUCTS.size()): return _result(false, "invalid_order_request", "Choose 10 or 100 orders and a valid product.")
	var store: Dictionary = {}
	for candidate in app.sim.state.stores:
		if candidate.active and int(candidate.type) == 0: store = candidate; break
	if store.is_empty(): return _result(false, "store_required", "Create an active marketplace store before generating test orders.")
	var listing := StoreManager.listing(app.sim.state, int(store.id), product)
	if not listing.get("listed", false): return _result(false, "listing_required", "List the selected product in an active store before generating orders.")
	var initial_order := int(app.sim.state.next_order)
	var generated := 0
	var needed_stock := maxi(0, count - app.sim.stock(product))
	if needed_stock > 0:
		var stock_result := _add_inventory({"product": product, "quantity": needed_stock}, app)
		if not stock_result.get("ok", false): return stock_result
	for i in count:
		var channel := StoreManager.channel(store)
		var order_id := Fulfillment.place(app.sim, channel, [product], int(listing.price), "", [], int(store.id), 0, false)
		if order_id <= 0: return _result(false, "order_generation_failed", "The real order service rejected order %d." % (i + 1), {"generated": generated})
		app.sim.state.orders[order_id].developer_generated = true
		app.sim.state.orders[order_id].developer_scenario = str(args.get("scenario", "test"))
		generated += 1
	var saved := _save(app)
	if not saved.get("ok", false): return saved
	app.refresh_view()
	return _result(true, "orders_generated", "Generated %d valid orders through the normal order service." % generated, {"first_order_id": initial_order, "last_order_id": int(app.sim.state.next_order) - 1})

func _marketing(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var scenario := str(args.get("scenario", ""))
	if scenario not in ["High ROAS", "Low ROAS", "Budget Exhausted", "Zero Conversions"]: return _result(false, "invalid_scenario", "Choose one of the four supported marketing scenarios.")
	var store: Dictionary = {}
	for candidate in app.sim.state.stores:
		if candidate.active and candidate.type == 0: store = candidate; break
	if store.is_empty(): return _result(false, "store_required", "Create an active marketplace store before creating a campaign scenario.")
	var product := int(args.get("product", 0))
	if product not in range(Catalog.PRODUCTS.size()): return _result(false, "invalid_product", "Choose an existing product.")
	if not StoreManager.listing(app.sim.state, int(store.id), product).get("listed", false):
		return _result(false, "listing_required", "List the selected product in an active store before creating a campaign scenario.")
	if scenario != "Zero Conversions" and app.sim.stock(product) < 20:
		var stock_result := _add_inventory({"product": product, "quantity": 20 - app.sim.stock(product)}, app)
		if not stock_result.get("ok", false): return stock_result
	var budget := Catalog.local_cents(int(app.sim.state.country), 250.0)
	if scenario == "Low ROAS": budget = Catalog.local_cents(int(app.sim.state.country), 1000.0)
	if scenario == "Budget Exhausted": budget = maxi(1, Catalog.local_cents(int(app.sim.state.country), 1.0))
	if scenario == "Zero Conversions": budget = 1
	var config := {"name": "Developer Test · %s" % scenario, "store_id": int(store.id), "platform": 4, "product": product,
		"daily_budget": maxi(1, budget), "audience": 0, "objective": 3, "bid_strategy": 0, "creative": 0, "start_day": int(app.sim.state.day)}
	if scenario == "Budget Exhausted": config.end_day = int(app.sim.state.day)
	if scenario == "High ROAS":
		config.objective = 3
		config.audience = 1
		config.creative = 4
	if scenario == "Low ROAS": config.objective = 0
	if scenario == "Zero Conversions": config.objective = 0
	if not Advertising.platform_available(int(app.sim.state.country), int(config.platform), store): config.platform = 3
	var error := Advertising.create(app.sim.state, config)
	if not error.is_empty(): return _result(false, "campaign_create_failed", error)
	var id := int(app.sim.state.advertising.next_campaign) - 1
	app.sim.state.advertising.campaigns[id].developer_scenario = scenario
	app.developer_scenario = scenario
	var saved := _save(app)
	if not saved.get("ok", false): return saved
	app.refresh_view()
	return _result(true, "marketing_scenario_applied", "%s test campaign created with the real advertising service. Advance simulation days to generate actual performance." % scenario,
		{"campaign_id": id, "status": app.sim.state.advertising.campaigns[id].status, "daily_budget": int(app.sim.state.advertising.campaigns[id].daily_budget), "end_day": int(app.sim.state.advertising.campaigns[id].end_day)})

func _set_reputation(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var value := int(args.get("value", 100))
	if value not in range(101): return _result(false, "invalid_reputation", "Reputation must be between 0 and 100.")
	var previous := int(app.sim.state.reputation); app.sim.state.reputation = value
	return _record(app, "set_reputation", "company", previous, value, {"reputation": value})

func _unlock_expansion(app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var previous := bool(app.sim.state.get("dev_expansion_unlocked", false))
	app.sim.state.dev_expansion_unlocked = true
	return _record(app, "unlock_expansion", "company", previous, true, {"expansion_unlocked": true})

func _advance_days(args: Dictionary, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	var days := int(args.get("days", 0))
	if days not in [7, 30, 365]: return _result(false, "invalid_duration", "Choose 7, 30, or 365 simulation days.")
	var previous := int(app.sim.state.day)
	app.sim.advance(days)
	var checked := _save(app)
	if not checked.get("ok", false): return checked
	app.report_end = 0; app.refresh_view()
	return _result(true, "time_advanced", "Advanced the simulation by %d days." % days, {"from_day": previous, "to_day": int(app.sim.state.day)})

func _scenario(name: String, app: Node) -> Dictionary:
	if not _require_dev(app): return _result(false, "active_game_required", "Load a company and unlock Developer Mode first.")
	if name not in ["Normal Business", "Financial Crisis", "Rapid Growth", "Stock Shortage"]: return _result(false, "invalid_scenario", "Choose a supported company scenario.")
	if name == "Normal Business":
		app.developer_scenario = name
		return _result(true, "scenario_applied", "Normal Business selected. The active game was not reset.", {"scenario": name})
	var result: Dictionary
	match name:
		"Financial Crisis": result = _set_cash({"amount": -Catalog.local_cents(int(app.sim.state.country), 500.0)}, app)
		"Rapid Growth":
			result = _set_cash({"amount": Catalog.local_cents(int(app.sim.state.country), 50000.0)}, app)
			if result.ok: result = _generate_orders({"count": 100, "product": 0, "scenario": name}, app)
		"Stock Shortage": result = _empty_stock({"product": 0}, app)
	if result.get("ok", false):
		app.developer_scenario = name
		_save(app); app.refresh_view()
	return result

func _preview_result(app: Node) -> void:
	if app.has_method("refresh_view"): app.refresh_view()

func _record(app: Node, name: String, system: String, previous: Variant, value: Variant, data: Dictionary = {}) -> Dictionary:
	var result := _save(app)
	if not result.get("ok", false): return result
	_preview_result(app)
	return _result(true, "updated", "Developer test state updated.", data)

func _save(app: Node) -> Dictionary:
	if app.sim == null or not app.developer_mode_unlocked or str(app.active_game_id).is_empty():
		return _result(false, "active_game_required", "Developer Mode is no longer attached to an active company.")
	app.developer_changes_active = true
	app.dirty = true
	return _result(true, "in_memory", "Developer change applied to the active company. Save explicitly to keep it.")

func _require_dev(app: Node) -> bool:
	return app != null and app.developer_mode_unlocked == true and app.sim != null and not str(app.active_game_id).is_empty()

func _result(ok: bool, code: String, message: String, data: Dictionary = {}) -> Dictionary:
	var result := {"ok": ok, "code": code, "message": message}
	result.merge(data, true)
	return result
