extends SceneTree

const Calendar = preload("res://game_calendar.gd")
const Catalog = preload("res://catalog.gd")
const Sim = preload("res://simulation.gd")
const Saves = preload("res://save_store.gd")
const Slots = preload("res://save_slots.gd")
const Storefront = preload("res://storefront.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Supply = preload("res://supply.gd")
const Summary = preload("res://product_summary.gd")

var failures := 0

func _initialize() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run with a fresh isolated save profile.")
		quit(1)
		return
	test_calendar()
	test_freight_and_statements()
	test_offer_compatibility()
	test_correct_offer_mechanics()
	test_brand_migration()
	test_slot_deletion()
	print("Phase 2 corrective simulation: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func game() -> Sim:
	return Sim.new(Sim.register("Mira", "Aster Labs", "Aster", 0, 1, 2, 153, true))

func test_calendar() -> void:
	var sim := game()
	expect(Calendar.format(sim.state.day) == "Thu, 1 Jan 2026", "Day one has a fixed weekday and date")
	for days in [1, 2, 7, 30]:
		sim.advance(days)
	expect(Calendar.format(sim.state.day) == "Tue, 10 Feb 2026", "All time controls advance the fixed calendar")
	expect(Calendar.bounds(1, 1) == Vector2i(-2, 4), "The first Monday-to-Sunday week crosses the start of the game")
	var week := sim.calendar_report(1, 1)
	expect(week.start == 1 and week.end == 4, "The first week excludes dates before the company opened")
	var january := sim.calendar_report(2, 30)
	var february := sim.calendar_report(2, 32)
	expect(january.start == 1 and january.end == 31 and february.start == 32 and february.end == 41, "Monthly reports clip to the actual month and transactions to date")
	expect(january.closing_cash == february.opening_cash, "Adjacent months share the same closing and opening cash")
	var year: Vector2i = Calendar.bounds(3, 365)
	expect(Calendar.format(year.y) == "Thu, 31 Dec 2026" and Calendar.format(year.y + 1) == "Fri, 1 Jan 2027", "Year rollover uses the real calendar")
	var leap := Calendar.day_at(2028, 2, 29)
	expect(Calendar.format(leap) == "Tue, 29 Feb 2028" and Calendar.bounds(2, leap).y == leap, "Leap years use February 29")
	for kind in Calendar.PERIODS.size():
		var report := sim.calendar_report(kind, sim.state.day)
		expect(report.opening_cash + Sim.cash_change(report) == report.closing_cash, "Cash flow reconciles across every calendar period")

func test_freight_and_statements() -> void:
	var sim := game()
	sim.state.auto_dispatch = false
	var cost := sim.unit_cost(4, 1)
	expect(cost.goods == 1200 and cost.freight == 200 and cost.landed == 1400, "Quote splits goods and inbound freight")
	expect(sim.buy(4, 1, 3) == "", "Buy stock at landed cost")
	var purchased := sim.calendar_report(0, 1)
	expect(purchased.purchases == 4200 and purchased.inbound_freight == 600 and purchased.inventory == 4200, "Inbound freight is capitalized once")
	expect(purchased.cogs == 0 and purchased.shipping == 0 and Sim.net(purchased) == 0, "Inbound freight has no early expense")
	expect(sim.unit_cost(4, 1).source == "Next inbound unit", "Inbound stock retains the actual booked cost")
	sim.advance(7)
	Fulfillment.place(sim, 0, [4], 3300, "")
	expect(Fulfillment.ship(sim.state, 1, 2) == "", "Dispatch a paid order")
	var dispatch := sim.calendar_report(0, sim.state.day)
	expect(dispatch.shipping == 1100 and dispatch.customer_deposits == 3300 and dispatch.inventory == 4200, "Outbound shipping and deposits remain separate")
	sim.advance(5)
	var delivered := sim.calendar_report(2, sim.state.day)
	expect(delivered.sales == 3300 and delivered.cogs == 1400 and delivered.inventory == 2800, "Delivery expenses landed cost once")
	sim.state.orders[1].restockable = true
	expect(Service.refund(sim, 1) == "", "Refund the delivered unit")
	var refunded := sim.calendar_report(3, sim.state.day)
	expect(refunded.sales == refunded.refunds and refunded.cogs == 0 and refunded.inventory == 4200 and refunded.shipping == 1100, "Return reverses landed COGS without reversing outbound freight")
	expect(refunded.assets == refunded.overdraft + refunded.customer_deposits + refunded.equity_capital + refunded.retained, "Balance sheet reconciles")
	expect(refunded.closing_cash == sim.state.cash and Saves.valid(sim.state), "Inventory, cash, and saved subledgers reconcile")
	var old := game()
	old.add_stock(4, {"units": 1, "cost": 1200, "quality": 1.0})
	expect(old.unit_cost(4, 1).freight == 0 and old.unit_cost(4, 1).landed == 1200, "Legacy stock keeps its booked cost")

func test_offer_compatibility() -> void:
	var sim := game()
	var legacy := {"mode": 1, "add_on": 4, "discount": 20}
	sim.state.offers[0] = legacy
	expect(Saves.valid(sim.state) and Storefront.offers_for(sim.state, 0)[1].enabled and Storefront.offers_for(sim.state, 0)[1].quantity == 2, "Legacy bundle loads enabled as a same-product two-unit offer")
	sim.state.offers[1] = {"mode": 1, "quantity": 14, "discount": 10}
	Sim.upgrade(sim.state)
	expect(sim.state.offers[1][1].quantity == 10, "Oversized legacy bundle normalizes to ten units without editing any order")
	expect(Storefront.set_offer(sim.state, 0, 2, 3, 15) == "", "Add a second offer to the same primary product")
	expect(Storefront.set_enabled(sim.state, 0, 1, false) == "", "Disable the bundle without deleting it")
	expect(Storefront.set_offer(sim.state, 0, 1, 2, 25) == "", "Edit the disabled bundle")
	var offers := Storefront.offers_for(sim.state, 0)
	expect(not offers[1].enabled and offers[1].quantity == 2 and offers[2].enabled and offers[2].items == [3], "Offer types and enabled state are independent")
	for product in [0, 2, 3]:
		sim.buy(product, 2, 35)
		sim.list_product(product, 7500 if product == 0 else 3500)
	sim.advance(20)
	var report := sim.report(20, 20)
	expect(report.channels[0].bundles + report.channels[1].bundles == 0, "Disabled bundle stays out of checkout")
	expect(report.channels[0].upsells + report.channels[1].upsells > 0, "Enabled upsell still appears")
	expect(Storefront.set_enabled(sim.state, 0, 1, true) == "" and Storefront.offers_for(sim.state, 0)[1].enabled, "Enable the same saved offer again")
	expect(Saves.valid(sim.state), "Both offers can be saved")

func stock(sim: Sim, product: int, units: int) -> void:
	if units > 0:
		var result := sim.buy(product, 2, units)
		if result.is_empty():
			for batch in sim.state.inbound:
				if batch.product == product:
					batch.eta = sim.state.day
					batch.arrival = sim.state.day
			Supply.receive(sim)
	sim.list_product(product, 10000)

func checkout(sim: Sim, product: int, offer: Dictionary, mode: int, seed: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if rng.randf() >= Storefront.offer_uptake(mode, int(offer.get("discount", 0))):
		return false
	rng.seed = seed
	var before: int = sim.state.orders.size()
	Storefront.complete_checkout(sim, product, sim.product_state(product).price, 0, {mode: offer}, rng)
	return sim.state.orders.size() > before

func test_correct_offer_mechanics() -> void:
	var bundle_sim := game()
	stock(bundle_sim, 0, 4)
	expect(Storefront.set_bundle(bundle_sim.state, 0, 3, 20, 0) == "", "Configure a discounted three-unit same-product bundle")
	var bundle: Dictionary = Storefront.offers_for(bundle_sim.state, 0)[1]
	var bundle_sold := false
	for seed in 100:
		if checkout(bundle_sim, 0, bundle, 1, seed):
			bundle_sold = true
			break
	expect(bundle_sold, "Bundle checkout accepts a customer")
	if bundle_sold:
		var order: Dictionary = bundle_sim.state.orders[1]
		expect(order.items.size() == 3 and order.items.all(func(line): return line.product == 0), "Bundle contains only selected SKU units")
		expect(bundle_sim.stock(0) == 1 and order.total == 24000 and order.items.map(func(line): return line.revenue).reduce(func(a, b): return a + b, 0) == order.total, "Bundle deducts full quantity and allocates discounted revenue exactly")
		bundle_sim.state.auto_dispatch = false
		for managed in bundle_sim.state.products:
			bundle_sim.state.products[managed].listed = false
		expect(Fulfillment.ship(bundle_sim.state, 1, 2) == "", "Discounted bundle dispatches through the normal fulfillment ledger")
		order.arrival = bundle_sim.state.day + 1
		bundle_sim.advance(2)
		var bundle_report := bundle_sim.report(bundle_sim.state.day)
		var product_metrics: Dictionary = Summary.collect(bundle_sim.state)
		expect(product_metrics[0].units == 3 and product_metrics[0].revenue == 24000, "Bundle history attributes all units and revenue to the selected SKU")
		expect(bundle_report.sales == 24000 and bundle_report.cogs == order.items.map(func(line): return line.cost).reduce(func(a, b): return a + b, 0), "Delivered bundle recognizes revenue and landed COGS once")
		var allocated_profit := 0
		for metric in product_metrics.values(): allocated_profit += metric.profit
		expect(allocated_profit == bundle_report.sales - bundle_report.cogs - bundle_report.fees - bundle_report.shipping, "Per-product bundle profit allocates fees and outbound shipping once")
		expect(bundle_report.closing_cash == bundle_sim.state.cash and bundle_report.assets == bundle_report.overdraft + bundle_report.customer_deposits + bundle_report.equity_capital + bundle_report.retained and Saves.valid(bundle_sim.state), "Bundle delivery reconciles cash, inventory, and statements")
		expect(Saves.valid(bundle_sim.state), "Quantity bundle remains save-valid")
	var fixed := game()
	stock(fixed, 0, 4)
	Storefront.set_bundle(fixed.state, 0, 2, 40, 15000)
	var fixed_offer: Dictionary = Storefront.offers_for(fixed.state, 0)[1]
	var fixed_sold := false
	for seed in 100:
		if checkout(fixed, 0, fixed_offer, 1, seed):
			fixed_sold = true
			break
	expect(fixed_sold and fixed.state.orders[1].total == 15000, "Bundle fixed price overrides its percentage discount")
	var fixed_upsell := game()
	stock(fixed_upsell, 0, 2)
	stock(fixed_upsell, 1, 2)
	stock(fixed_upsell, 2, 2)
	Storefront.set_upsell(fixed_upsell.state, 0, [1, 2], 10, 20000)
	var fixed_upsell_sold := false
	for seed in 100:
		if checkout(fixed_upsell, 0, Storefront.offers_for(fixed_upsell.state, 0)[2], 2, seed):
			fixed_upsell_sold = true
			break
	expect(fixed_upsell_sold and fixed_upsell.state.orders[1].total == 20000, "Upsell fixed price independently overrides its basket discount")
	var shortage := game()
	stock(shortage, 0, 9)
	var no_stock_sale := false
	for seed in 100:
		if checkout(shortage, 0, {"mode": 1, "quantity": 10, "discount": 0, "price": 0, "enabled": true}, 1, seed):
			no_stock_sale = true
	expect(not no_stock_sale and shortage.stock(0) == 9, "Bundle shortage creates no order and reserves no partial stock")
	var combinations: Array = [[1], [1, 2], [1, 1]]
	for combination in combinations:
		var sim := game()
		stock(sim, 0, 3)
		stock(sim, 1, 3)
		stock(sim, 2, 3)
		expect(Storefront.set_upsell(sim.state, 0, combination, 15) == "", "Configure upsell composition %s" % str(combination))
		var saved: Dictionary = Storefront.offers_for(sim.state, 0)[2]
		var sold := false
		for seed in 100:
			if checkout(sim, 0, saved, 2, seed):
				sold = true
				break
		expect(sold, "Upsell composition %s completes checkout" % str(combination))
		if sold:
			var order: Dictionary = sim.state.orders[1]
			var expected: Array = [0]
			expected.append_array(combination)
			var actual: Array = order.items.map(func(line): return line.product)
			expect(actual == expected and order.total == roundi(10000 * expected.size() * 0.85), "Upsell composition %s uses correct SKUs and discount" % str(combination))
			expect(order.items.map(func(line): return line.revenue).reduce(func(a, b): return a + b, 0) == order.total, "Upsell revenues sum to basket total")
			if combination == [1, 2]:
				sim.state.auto_dispatch = false
				for managed in sim.state.products:
					sim.state.products[managed].listed = false
				Fulfillment.ship(sim.state, 1, 2)
				order.arrival = sim.state.day + 1
				sim.advance(2)
				var metrics: Dictionary = Summary.collect(sim.state)
				expect(metrics[0].units == 1 and metrics[1].units == 1 and metrics[2].units == 1, "Two-different-product upsell assigns unit sales to every SKU")
				var report := sim.report(sim.state.day)
				var allocated := 0
				for metric in metrics.values(): allocated += metric.profit
				expect(report.sales == order.total and report.closing_cash == sim.state.cash and allocated == report.sales - report.cogs - report.fees - report.shipping and Saves.valid(sim.state), "Upsell delivery reconciles cash, recognized sales, costs, and per-SKU profit")
			expect(Saves.valid(sim.state), "Upsell composition %s is save-valid" % str(combination))
	expect(Storefront.set_upsell(bundle_sim.state, 0, [0], 10) != "", "Main product cannot upsell itself")
	var stockout := game()
	stock(stockout, 0, 10)
	stock(stockout, 1, 0)
	Storefront.set_upsell(stockout.state, 0, [1], 0)
	var stockout_sale := false
	for seed in 100:
		if checkout(stockout, 0, Storefront.offers_for(stockout.state, 0)[2], 2, seed): stockout_sale = true
	expect(not stockout_sale and stockout.stock(0) == 10, "Missing upsell stock rejects the full basket without deduction")

func test_brand_migration() -> void:
	var old := game()
	var history: Array = old.state.ledger.duplicate(true)
	old.state.erase("brand")
	old.state.erase("website_domain")
	old.state.erase("website_active")
	Sim.upgrade(old.state)
	expect(old.state.brand == old.state.company and old.state.website_domain == "aster-labs.shop", "Old save gets sensible identity defaults")
	expect(old.state.website_active and old.state.ledger == history, "Identity migration preserves website availability and historical ledger")
	expect(Saves.valid(old.state), "Migrated identity save validates")
	expect(Storefront.set_bundle(old.state, 0, 4, 5, 12000) == "", "Fixed-price quantity bundle saves")
	var migrated := old.state.duplicate(true)
	migrated.erase("brand")
	migrated.erase("website_domain")
	migrated.erase("website_active")
	var legacy_file := FileAccess.open("user://identity_migration.save", FileAccess.WRITE)
	legacy_file.store_var(migrated)
	legacy_file.close()
	var loaded := Saves.load_state("user://identity_migration.save", "user://absent.json")
	expect(loaded.brand == migrated.company and Saves.valid(loaded) and loaded.offers == migrated.offers, "Save loading backfills identity and retains offers")

func test_slot_deletion() -> void:
	var sim := game()
	expect(Saves.save(sim.state) == OK, "Write the pre-slot save")
	expect(Slots.write(0, sim.state, 10) == OK and Slots.write(1, sim.state, 20) == OK, "Autosave and a manual slot write separately")
	sim.advance(2)
	expect(Slots.write(1, sim.state, 30) == OK, "Manual slot overwrites with new game date")
	var corrupt := sim.state.duplicate(true)
	corrupt.cash += 1
	expect(Slots.write(1, corrupt, 40) == ERR_INVALID_DATA and Slots.read(1).saved_at == 30, "A bad state cannot overwrite a valid snapshot")
	expect(Slots.delete_slot(1) == OK and not Slots.occupied(1) and Slots.read(1).is_empty(), "Delete removes manual primary and backup")
	expect(Slots.latest().slot == 0, "Continue falls back to autosave")
	expect(Slots.delete_slot(0) == OK and Slots.latest().is_empty() and not Slots.occupied(0), "Deleting autosave suppresses legacy fallback")
	expect(not Saves.read_file(Saves.PATH).is_empty(), "Original pre-slot file remains untouched")
	expect(Slots.write(0, sim.state, 50) == OK and Slots.latest().state.day == 3, "Autosave can write again after deletion")
	expect(Calendar.format(Slots.latest().state.day) == "Sat, 3 Jan 2026", "Saved elapsed days retain their game date")
