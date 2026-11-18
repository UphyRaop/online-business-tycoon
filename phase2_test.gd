extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Storefront = preload("res://storefront.gd")
const Saves = preload("res://save_store.gd")
const Stores = preload("res://store_manager.gd")

var failures := 0

func _initialize() -> void:
	test_supply()
	test_dispatch_and_refund()
	test_offers_and_checkout()
	test_reputation_and_repeatability()
	test_phase1_save()
	print("Phase 2 simulation: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func game() -> Sim:
	var state := Sim.register("Mira", "Aster Labs", "Aster Shop", 0, 1, 2, 153)
	state.website_active = true
	state.stores = Stores.migration_defaults(state) # Explicit legacy fixture stores for Phase 2 regression coverage.
	return Sim.new(state)

func balances(sim: Sim, context: String) -> void:
	var report := sim.report(sim.state.day)
	expect(report.closing_cash == sim.state.cash, context + ": ledger reconciles to cash")
	expect(report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained, context + ": balance sheet balances")
	expect(Saves.valid(sim.state), context + ": inventory and deposit subledgers reconcile")

func seed_for_roll(minimum: float) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 1000):
		rng.seed = seed_value
		var initial := rng.state
		if rng.randf() >= minimum:
			return initial
	return rng.state

func test_supply() -> void:
	var sim := game()
	var state := sim.state
	var supplier := 3 # AliExpress is the retained Level 1 warehouse sourcing option.
	var base := Catalog.quote(0, 0, supplier)
	var opening: int = state.cash
	var forecast := Supply.forecast(sim, 0, supplier)
	expect(forecast.suggested > 0 and forecast.days == 0, "Forecast starts with a catalog estimate")
	expect(Supply.negotiate(state, 0, supplier, 5) != "", "Negotiation rejects undersized volume")
	expect(Supply.negotiate(state, 0, supplier, 20) == "", "Supplier returns a volume quote")
	var quote := Supply.quote(state, 0, supplier)
	expect(quote.cost < base and quote.minimum == 20 and quote.expires == 7, "Quote has price, quantity, and validity")
	expect(Supply.negotiate(state, 0, supplier, 40) != "", "Firm quote cannot be rerolled")
	state.seed = seed_for_roll(Catalog.SUPPLIERS[supplier].reliability)
	expect(sim.buy(0, supplier, 20) == "", "Place a negotiated purchase")
	expect(sim.buy(0, supplier, 5) == "", "Base terms remain available below negotiated minimum")
	expect(state.cash == opening - quote.cost * 20 - base * 5 - Catalog.inbound_freight(0, supplier) * 25, "Inventory is paid at the applicable quote plus inbound freight")
	var first: Dictionary = state.inbound[0]
	expect(first.eta == 1 + Catalog.SUPPLIERS[supplier].lead and first.arrival > first.eta and sim.stock(0) == 0, "Reliability creates an inbound delay")
	expect(Supply.incoming(state, 0) == 25 and Supply.forecast(sim, 0, supplier).suggested < forecast.suggested, "Inbound stock reduces forecast restock")
	balances(sim, "In transit")
	sim.advance(first.eta)
	expect(first.delayed and first in state.inbound, "A missed supplier ETA is visible")
	sim.advance(3)
	expect(sim.stock(0) == 25 and state.inbound.is_empty(), "Both purchase orders arrive exactly once")
	expect(Supply.quote(state, 0, supplier).cost == base, "Expired quote restores base price")
	sim.list_product(0, 8600)
	sim.advance(3)
	expect(Supply.forecast(sim, 0, supplier).days == 3, "Forecast uses completed demand history")
	balances(sim, "Purchased stock")

func test_dispatch_and_refund() -> void:
	var sim := game()
	var state := sim.state
	state.auto_dispatch = false
	sim.buy(4, 3, 5)
	sim.advance(sim.state.inbound[0].arrival - sim.state.day + 1)
	var cost := Catalog.quote(0, 4, 3) + Catalog.inbound_freight(0, 3)
	Fulfillment.place(sim, 1, [4], 3300, "")
	var queued: Dictionary = sim.report(1)
	expect(state.orders[1].status == "queued" and sim.stock(4) == 4, "Checkout reserves exactly one unit")
	expect(queued.sales == 0 and queued.customer_deposits == 3300 and queued.inventory == 5 * cost, "Paid unfulfilled order is a deposit and reserved stock remains inventory")
	expect(queued.sales + queued.deposits == 3300, "Cash flow records the receipt at checkout")
	balances(sim, "Queued")
	sim.advance(4)
	expect(state.orders[1].status == "queued", "Manual mode leaves the order awaiting dispatch")
	state.seed = seed_for_roll(Catalog.SHIPPING[0].reliability)
	var ship_day: int = state.day
	expect(Fulfillment.ship(state, 1, 0) == "", "Manual dispatch can select a different carrier")
	expect(Fulfillment.ship(state, 1, 0) != "", "Duplicate dispatch is rejected")
	var order: Dictionary = state.orders[1]
	expect(order.eta == ship_day + 4 and order.arrival > order.eta, "Method determines ETA and can run late")
	expect(sim.report(1).shipping == Catalog.local_cents(0, 3), "Shipping is expensed once on dispatch")
	sim.advance(order.eta - state.day + 1)
	expect(order.status == "shipped" and order.delayed, "Tracking exposes a missed carrier ETA")
	sim.advance(order.arrival - state.day + 1)
	var delivery := sim.report(1, state.day - 1)
	expect(order.status == "delivered" and order.case_status == "open" and state.reputation < 70, "Late delivery generates a complaint and harms reputation")
	expect(delivery.sales == 3300 and delivery.customer_deposits == 0 and delivery.cogs == cost, "Delivery recognizes the sale and reserved stock cost")
	expect(delivery.sales + delivery.deposits == 0, "Delivery does not collect the customer payment twice")
	expect(delivery.fees == Catalog.fee(1, 3300) and delivery.channels[1].on_time == 0, "Actual channel fee and late delivery are recorded")
	balances(sim, "Delivered")
	var old_cash: int = state.cash
	var old_stock := sim.stock(4)
	var restockable: bool = order.restockable
	expect(Service.refund(sim, 1) == "" and Service.refund(sim, 1) != "", "Refund pays exactly once")
	expect(state.cash == old_cash - 3300 and sim.stock(4) == old_stock + (1 if restockable else 0), "Refund pays cash and restores sellable stock only")
	var returned := sim.report(1)
	expect(returned.refunds == 3300 and returned.cogs == (-cost if restockable else 0), "Refund and inventory reversal enter the ledger")
	balances(sim, "Refunded")

	Fulfillment.place(sim, 0, [4], 3200, "")
	Fulfillment.ship(state, 2, 2)
	sim.advance(5)
	var defective: Dictionary = state.orders[2]
	open_case(state, defective, true, false)
	expect(Service.refund(sim, 2) == "" and sim.report(1).cogs == 0, "Defective return remains expensed")
	balances(sim, "Defective return")

	Fulfillment.place(sim, 0, [4], 3200, "")
	Fulfillment.ship(state, 3, 2)
	sim.advance(5)
	var complaint: Dictionary = state.orders[3]
	open_case(state, complaint, false, true)
	var before: int = state.reputation
	sim.advance(8)
	expect(complaint.escalated and state.reputation == before - 3, "Unanswered case escalates once")
	expect(Service.respond(state, 3) == "" and Service.respond(state, 3) != "", "Complaint resolution closes the case")
	expect(state.reputation == before - 1, "Responding recovers some reputation")

	Fulfillment.place(sim, 0, [4], 3200, "")
	Fulfillment.ship(state, 4, 2)
	sim.advance(5)
	open_case(state, state.orders[4], true, true)
	expect(Service.reject_return(state, 4) == "" and state.orders[4].case_status == "declined", "Return rejection closes the case")
	sim.advance(15)
	expect(Service.refund(sim, 4) != "", "Closed orders cannot be refunded outside the return window")
	balances(sim, "Closed cases")

func open_case(state: Dictionary, order: Dictionary, wants_return: bool, resellable: bool) -> void:
	order.case_status = "open"
	order.case_day = state.day
	order.return_requested = wants_return
	order.restockable = resellable
	order.reason = "Return request" if wants_return else "Delivery complaint"
	if order.id not in state.open_cases:
		state.open_cases.append(order.id)

func test_offers_and_checkout() -> void:
	for mode in [1, 2]:
		var sim := game()
		var state := sim.state
		state.shipping = 2
		if mode == 1:
			expect(Storefront.set_offer(state, 0, mode, 0, 20) == "", "Same-product bundle uses the selected SKU")
		else:
			expect(Storefront.set_offer(state, 0, mode, 0, 20) != "", "Upsell cannot include the primary SKU")
		expect(Storefront.set_offer(state, 0, mode, 4, 20) == "", "Save a valid offer")
		sim.buy(0, 3, 40)
		sim.buy(4, 3, 60)
		sim.list_product(0, 8000)
		sim.list_product(4, 3000)
		sim.advance(30)
		var paired := 0
		for order in state.orders.values():
			if order.items.size() == 2:
				paired += 1
				expect(order.total == (12800 if mode == 1 else 8800), "Bundle and upsell discount the correct basket")
		var report := sim.report(30, 30)
		var kind := "bundles" if mode == 1 else "upsells"
		expect(paired > 0 and paired == report.channels[0][kind] + report.channels[1][kind], "Accepted offers are tracked with their correct SKU lines")
		var abandoned := 0
		for channel in [0, 1]:
			var metrics: Dictionary = report.channels[channel]
			abandoned += metrics.abandoned
			expect(metrics.checkouts == metrics.placed + metrics.abandoned + metrics.stockouts, "Checkout funnel reconciles per channel")
			expect(metrics.tracked_deliveries <= metrics.placed and metrics.on_time <= metrics.tracked_deliveries, "Fulfillment metrics reconcile")
		expect(abandoned > 0, "Abandoned checkouts are simulated")
		expect(Storefront.set_offer(state, 0, 0, 4, 20) == "" and state.offers.is_empty(), "Offer can be removed")
		balances(sim, "Offer sales")

func test_reputation_and_repeatability() -> void:
	var low := game()
	var high := game()
	low.state.reputation = 15
	high.state.reputation = 95
	for sim in [low, high]:
		sim.list_product(0, 9000)
		sim.advance(60)
	var low_funnel := low.report(60, 60)
	var high_funnel := high.report(60, 60)
	expect(high_funnel.channels[0].checkouts > low_funnel.channels[0].checkouts, "Higher reputation raises future traffic")
	expect(high_funnel.channels[0].stockouts > low_funnel.channels[0].stockouts, "Higher reputation increases converting demand with identical price")
	var sim := game()
	Supply.negotiate(sim.state, 1, 3, 30)
	sim.buy(1, 3, 30)
	sim.list_product(1, 6500)
	sim.advance(5)
	var snapshot := sim.state.duplicate(true)
	var path := "user://phase2_test_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(snapshot, path) == OK and Saves.load_state(path) == snapshot, "New order, quote, and inventory state round-trips")
	var copy := Sim.new(Saves.load_state(path))
	sim.advance(30)
	for i in range(30):
		copy.advance(1)
	expect(copy.state == sim.state, "Single-day and batch advancement produce the same result after load")
	balances(sim, "Batch advancement")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_phase1_save() -> void:
	var state := game().state
	state.version = 1
	state.day = 2
	state.products[0] = {"supplier": 0, "listed": true, "price": 6300, "lots": [{"units": 2, "cost": 2800, "quality": 0.85}]}
	var row: Dictionary = state.ledger[0]
	row.sales = 6300
	row.cogs = 2800
	row.fees = 756
	row.purchases = 8400
	row.channels[0].sales = 6300
	row.channels[0].orders = 1
	row.channels[0].cogs = 2800
	row.channels[0].fees = 756
	state.cash = row.capital + 6300 - 756 - 8400
	state.ledger.append(Sim.entry())
	for field in ["inbound", "quotes", "orders", "active_orders", "open_cases", "shipping", "auto_dispatch", "satisfaction", "reputation", "offers", "next_order", "next_purchase"]:
		state.erase(field)
	for old in state.ledger:
		for field in ["shipping", "refunds", "deposits", "demand"]:
			old.erase(field)
		for channel in old.channels:
			for field in Sim.CHANNEL_FIELDS:
				if field not in ["orders", "sales", "cogs", "fees", "hosting"]:
					channel.erase(field)
	var path := "user://phase1_fixture_%d.save" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(state)
	file.close()
	var imported := Saves.load_state(path)
	expect(imported.get("version") == Sim.VERSION, "Original binary Phase 1 save upgrades on read")
	if not imported.is_empty():
		var sim := Sim.new(imported)
		expect(sim.stock(0) == 2 and sim.product_state(0).price == 6300 and imported.cash == state.cash and imported.seed == state.seed, "Migration retains FIFO stock, pricing, cash, and RNG")
		expect(sim.report(1, 1).sales == 6300 and sim.report(1, 1).channels[0].orders == 1 and sim.report(1, 1).channels[0].tracked_deliveries == 0, "Historical sales retained without fabricated tracking data")
		sim.advance(7)
		balances(sim, "Migrated and advanced")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
