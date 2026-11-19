extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Saves = preload("res://save_store.gd")
const Stores = preload("res://store_manager.gd")
const Ads = preload("res://advertising.gd")
const Storefront = preload("res://storefront.gd")
const AdvertisingView = preload("res://advertising_view.gd")

var failures := 0

func _initialize() -> void:
	test_supplier_returns()
	test_preorder_fifo_and_dispatch()
	test_store_specific_offers()
	test_ad_rates()
	test_ad_reporting_excludes_unfinished_day()
	print("Phase 4 inventory and ads: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func new_game() -> Sim:
	var state := Sim.register("Mira", "Aster Labs", "Aster", 0, 1, 0, 882)
	state.stores = Stores.migration_defaults(state)
	return Sim.new(state)

func seed_warehouse(sim: Sim, product: int, units: int, cost: int, freight: int = 0, supplier: int = 0) -> void:
	sim.add_stock(product, {"units": units, "cost": cost, "freight": freight, "quality": 0.9,
		"supplier": supplier, "supplier_id": Catalog.supplier_id(supplier), "supplier_name": Catalog.SUPPLIERS[supplier].name})
	sim.state.cash -= cost * units
	sim.state.ledger.back().purchases += cost * units
	sim.state.ledger.back().inbound_freight += freight * units

func test_supplier_returns() -> void:
	var sim := new_game()
	seed_warehouse(sim, 0, 2, 10000, 2000, 3)
	var before: int = sim.state.cash
	var preview := Supply.preview_return(sim.state, 0, 3, 1)
	expect(preview.get("error", "") == "" and preview.original_purchase_cost == 8000 and preview.landed_cost == 10000 and preview.refund == 4000,
		"Supplier return preview uses the lot's original goods cost, excludes freight, and refunds exactly 50%")
	var result := sim.return_stock(0, 3, 1)
	expect(result.get("error", "") == "" and sim.stock(0) == 1 and sim.state.cash == before + 4000,
		"A confirmed return permanently removes stock and records the refund in cash")
	expect(sim.state.supplier_returns.size() == 1 and sim.state.supplier_returns[0].units == 1
		and sim.state.supplier_returns[0].original_purchase_cost == 8000 and sim.state.supplier_returns[0].refund == 4000,
		"Supplier return history records product, supplier, units, original cost, refund, and date")
	var report := sim.report(sim.state.day)
	expect(report.inventory == 10000 and report.closing_cash == sim.state.cash
		and report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained,
		"Supplier return reconciles remaining inventory, cash flow, and balance sheet")
	expect(Saves.valid(sim.state), "Supplier return is accepted by save validation")
	var path := "user://phase4_return_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(sim.state, path) == OK and Saves.load_state(path) == sim.state,
		"Supplier return and its accounting persist through save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	expect(not str(sim.return_stock(0, 3, 2).get("error", "")).is_empty() and sim.stock(0) == 1,
		"Return quantity cannot exceed available unreserved supplier stock")
	var fallback_state := sim.state.duplicate(true)
	fallback_state.products[0].lots[0].erase("cost")
	var fallback := Supply.preview_return(fallback_state, 0, 3, 1)
	expect(fallback.get("error", "") == "" and fallback.allocations[0].cost_fallback
		and fallback.original_purchase_cost == Catalog.local_cents(fallback_state.country, Catalog.PRODUCTS[0].cost),
		"Missing historical lot cost uses the documented deterministic catalog cost fallback, not a live quote")

func test_preorder_fifo_and_dispatch() -> void:
	var sim := new_game()
	sim.state.auto_dispatch = false
	var first := Fulfillment.place(sim, 0, [0], 12000, "", [12000], 0, 0, true)
	var second := Fulfillment.place(sim, 0, [0], 12000, "", [12000], 0, 0, true)
	expect(first > 0 and second > first and sim.state.orders[first].preorder_status == "awaiting_stock",
		"Two customers can create queued pre-orders while warehouse stock is zero")
	seed_warehouse(sim, 0, 1, 10000, 1000)
	Fulfillment.allocate_preorders(sim)
	expect(not sim.state.orders[first].items[0].get("awaiting_stock", false)
		and sim.state.orders[first].preorder_status == "ready_for_fulfillment"
		and sim.state.orders[second].items[0].get("awaiting_stock", false),
		"Partial receipt allocates the oldest eligible pre-order first")
	expect(sim.stock(0) == 0 and Fulfillment.ship(sim.state, second, sim.state.shipping) != "",
		"Reserved stock cannot be taken by a newer pre-order or dispatched out of sequence")
	var ordinary := Fulfillment.place(sim, 0, [0], 12000, "", [12000], 0, 0, false)
	expect(ordinary == 0 and sim.stock(0) == 0,
		"A regular warehouse order cannot bypass an older waiting pre-order")
	seed_warehouse(sim, 0, 1, 10000, 1000)
	Fulfillment.allocate_preorders(sim)
	expect(sim.state.orders[second].preorder_status == "ready_for_fulfillment" and sim.stock(0) == 0,
		"A later partial arrival is allocated to the next pre-order without duplicate stock reservation")
	var path := "user://phase4_preorder_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(sim.state, path) == OK and Saves.load_state(path) == sim.state,
		"Allocated pre-order status, reserved units, and FIFO order persist through save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	expect(Fulfillment.ship(sim.state, first, sim.state.shipping) == "" and Fulfillment.ship(sim.state, second, sim.state.shipping) == "",
		"Manual dispatch accepts both pre-orders once their own stock is allocated")
	expect(sim.stock(0) == 0 and Saves.valid(sim.state),
		"Dispatch does not deduct the already-reserved warehouse units a second time")
	sim.advance(10)
	var preorder_cogs := 0
	var preorder_sales := 0
	for row in sim.state.ledger:
		preorder_cogs += int(row.cogs)
		preorder_sales += int(row.sales)
	expect(sim.state.orders[first].status == "delivered" and sim.state.orders[second].status == "delivered"
		and preorder_cogs == 20000 and preorder_sales == 24000,
		"Delivered pre-orders record sales and each allocated unit's COGS exactly once")
	var report := sim.report(sim.state.day)
	expect(report.closing_cash == sim.state.cash and report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained,
		"Pre-order dispatch and settlement reconcile cash flow and the balance sheet")
	expect(Saves.valid(sim.state), "Delivered pre-orders remain save compatible")

func test_ad_rates() -> void:
	var sim := new_game()
	var state: Dictionary = sim.state
	var first := Ads.empty_metrics()
	first.campaign_id = 7
	first.day = 1
	first.clicks = 12
	first.impressions = 400
	first.spend = 1200
	var second := Ads.empty_metrics()
	second.campaign_id = 7
	second.day = 1
	second.clicks = 18
	second.impressions = 600
	second.spend = 1800
	state.advertising.history.append_array([first, second])
	var totals := Ads.aggregate_range(state, 7, 1, 1)
	expect(is_equal_approx(float(totals.ctr), 3.0) and is_equal_approx(float(totals.cpm), 3000.0),
		"CTR and CPM derive from aggregate clicks, impressions, and spend rather than average campaign rates")
	expect(Ads.ctr_percent(0, 0) == 0.0 and Ads.cpm_cents(0, 0) == 0.0,
		"CTR and CPM safely return zero when there are no impressions")

func test_ad_reporting_excludes_unfinished_day() -> void:
	var empty := AdvertisingView._analytics_buckets({"day": 1}, 0)
	expect(empty.is_empty(), "Ads Analytics reports no completed days on a new Day 1 company")
	var buckets := AdvertisingView._analytics_buckets({"day": 10}, 0)
	expect(not buckets.is_empty() and int(buckets.back().end) == 9
		and int(buckets.front().start) >= 1,
		"Daily Ads Analytics ends on Day 9 while Day 10 is still in progress")
	var weekly := AdvertisingView._analytics_buckets({"day": 10}, 1)
	expect(not weekly.is_empty() and int(weekly.back().end) <= 9,
		"Weekly Ads Analytics does not include the unfinished simulation day")

func test_store_specific_offers() -> void:
	var sim := new_game()
	var state: Dictionary = sim.state
	expect(Storefront.set_bundle_for_store(state, 0, 0, 3, 10) == ""
		and Storefront.set_upsell_for_store(state, 1, 0, [1], 15) == "",
		"Separate stores can configure different offer types for the same product")
	expect(Storefront.offers_for_store(state, 0, 0).has(1) and not Storefront.offers_for_store(state, 0, 0).has(2)
		and Storefront.offers_for_store(state, 1, 0).has(2) and not Storefront.offers_for_store(state, 1, 0).has(1),
		"Offer settings stay scoped to their store and product while preserving Bundle/Upsell exclusivity")
	var path := "user://phase4_store_offers_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(state, path) == OK and Saves.load_state(path) == state,
		"Store-specific offer settings persist through save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
