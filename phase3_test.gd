extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Ads = preload("res://advertising.gd")
const Stores = preload("res://store_manager.gd")
const Storefront = preload("res://storefront.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Saves = preload("res://save_store.gd")

var failures := 0

func _initialize() -> void:
	test_stores()
	test_campaign_controls_and_simulation()
	test_campaign_attribution_refunds_and_save()
	test_bundle_limits()
	test_supplier_progression()
	test_supplier_direct_fulfillment()
	test_campaign_lifecycle()
	test_save_migration()
	print("Phase 3 simulation: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func game(country: int = 0, seed_value: int = 153) -> Sim:
	return Sim.new(Sim.register("Mira", "Aster Labs", "Aster Market", country, 0, 2, seed_value))

func add_delivered_stock(sim: Sim, product: int, units: int) -> void:
	var result := sim.buy(product, 2, units)
	expect(result == "", "Supplier accepts a stock purchase for product %d" % product)
	for batch in sim.state.inbound:
		batch.eta = sim.state.day
		batch.arrival = sim.state.day
	Supply.receive(sim)

func campaign_config(store_id: int, product: int, platform: int = 0, budget: int = 5000) -> Dictionary:
	return {"name": "Test campaign", "store_id": store_id, "product": product, "platform": platform,
		"objective": 3, "daily_budget": budget, "start_day": 1, "end_day": 0,
		"audience": 0, "bid_strategy": 0, "bid": 0, "creative": 0}

func reconcile(sim: Sim, context: String) -> void:
	var report := sim.report(sim.state.day)
	expect(report.closing_cash == sim.state.cash, context + " cash matches ledger")
	expect(report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained,
		context + " balance sheet reconciles")
	expect(Saves.valid(sim.state), context + " remains save-valid")

func test_stores() -> void:
	var sim := game()
	var state := sim.state
	expect(Stores.setup_cost(0, 0) == 0 and Stores.setup_cost(1, 0) == 0 and Stores.setup_cost(0, 1) != Stores.setup_cost(1, 1) and Stores.daily_cost(0, 1) != Stores.daily_cost(1, 1),
		"Marketplace registration is free and website costs scale by country")
	var marketplace_cost := Stores.setup_cost(state.country, 0)
	var before: int = state.cash
	expect(Stores.create(state, "Extra Market", 0, "Aster") == "", "Create an additional marketplace store")
	var extra_id: int = state.next_store - 1
	expect(state.cash == before - marketplace_cost and state.ledger[0].store_setup == marketplace_cost,
		"Store setup charge is recorded exactly once")
	expect(Stores.create(state, "Aster Direct", 1, "Aster", "direct.aster.shop") == "", "Create a website store")
	var site_id: int = state.next_store - 1
	var website := Stores.get_store(state, site_id)
	expect(website.domain == "direct.aster.shop" and website.active, "Website store keeps its configured domain and active status")
	expect(Stores.create(state, "", 0, "Aster") != "", "Reject invalid store setup")
	var cash_before_day: int = state.cash
	sim.advance(1)
	expect(state.ledger[0].store_expenses == Stores.daily_cost(state.country, 0) + Stores.daily_cost(state.country, 1),
		"New active stores incur their type-specific daily recurring costs once")
	expect(state.cash < cash_before_day, "Recurring store costs reduce company cash")
	expect(Stores.set_active(state, site_id, false) == "", "Deactivate a website store")
	var second_day_cost: int = state.ledger[1].store_expenses
	sim.advance(1)
	expect(state.ledger[1].store_expenses == Stores.daily_cost(state.country, 0) and second_day_cost == 0,
		"Inactive stores stop accruing recurring costs")

	add_delivered_stock(sim, 0, 12)
	expect(Stores.set_listing(state, 0, 0, 8100, true) == "", "Publish product in the legacy marketplace")
	expect(Stores.set_listing(state, extra_id, 0, 8600, true) == "", "Publish an independent listing in the second marketplace")
	expect(Stores.listing(state, 0, 0).price != Stores.listing(state, extra_id, 0).price,
		"Same product has independent store-specific pricing")
	var order_id := Fulfillment.place(sim, 0, [0], 8600, "", [], extra_id)
	expect(order_id > 0 and state.orders[order_id].store_id == extra_id and sim.stock(0) == 11,
		"Store order reserves one shared inventory unit and records its store")
	sim.advance(12)
	var store_report := Stores.report(state, extra_id)
	expect(state.orders[order_id].status == "delivered" and store_report.sales >= 8600 and store_report.orders >= 1 and store_report.advertising == 0,
		"Store-specific performance reflects the delivered order and organic sales")
	expect(state.ledger[0].store_activity[extra_id].setup == marketplace_cost,
		"Store management attributes setup spending to the correct store")
	reconcile(sim, "Multiple stores")

func test_campaign_controls_and_simulation() -> void:
	var sim := game(0, 811)
	var state := sim.state
	add_delivered_stock(sim, 0, 250)
	expect(Stores.set_listing(state, 0, 0, 9500, true) == "", "Publish the promoted product")
	var blocked := campaign_config(0, 0)
	blocked.audience = 3
	expect(Ads.create(state, blocked) != "", "Retargeting requires accumulated store visits")
	var unpublished := campaign_config(0, 1)
	expect(Ads.create(state, unpublished) != "", "Unlisted products cannot be promoted")
	var unavailable := campaign_config(1, 0, 3)
	expect(Ads.create(state, unavailable) != "", "Marketplace Sponsored Ads require a marketplace store")
	var shopee := int(state.next_store)
	expect(Stores.create(state, "Shopee Campaign Store", 0, "Aster", "", 0).is_empty(), "Create Shopee destination")
	Stores.set_listing(state, shopee, 0, 9500, true)
	var shopee_campaign := campaign_config(shopee, 0, 4)
	shopee_campaign.draft = true
	expect(Ads.create(state, shopee_campaign).is_empty(), "Shopee Sponsored Ads can target a Shopee listing")
	var lazada := int(state.next_store)
	expect(Stores.create(state, "Lazada Campaign Store", 0, "Aster", "", 2).is_empty(), "Create Lazada destination")
	Stores.set_listing(state, lazada, 0, 9500, true)
	var lazada_campaign := campaign_config(lazada, 0, 5)
	lazada_campaign.draft = true
	expect(Ads.create(state, lazada_campaign).is_empty(), "Lazada Sponsored Ads can target a Lazada listing")
	var incompatible := campaign_config(shopee, 0, 5)
	incompatible.draft = true
	expect(Ads.create(state, incompatible) != "", "Lazada Sponsored Ads reject an incompatible Shopee destination")
	var zero_budget := campaign_config(0, 0, 0, 0)
	expect(Ads.create(state, zero_budget) != "", "Campaign rejects a zero daily budget")
	var excess_budget := campaign_config(0, 0, 0, Catalog.local_cents(state.country, 10001.0))
	expect(Ads.create(state, excess_budget) != "", "Campaign rejects a budget above the supported cap")
	var config := campaign_config(0, 0, 0, 5000)
	expect(Ads.create(state, config) == "", "Create a valid Meta campaign")
	var first := int(state.advertising.next_campaign) - 1
	var other := campaign_config(0, 0, 1, 3000)
	other.name = "Search campaign"
	expect(Ads.create(state, other) == "", "Run multiple campaigns on the same product")
	var second := int(state.advertising.next_campaign) - 1
	expect(Ads.edit(state, first, {"daily_budget": 6500, "audience": 1, "creative": 1}) == "",
		"Edit a campaign budget, audience, and creative for future days")
	expect(state.advertising.campaigns[first].daily_budget == 6500 and state.advertising.campaigns[first].audience == 1,
		"Campaign edits persist")
	expect(Ads.set_status(state, first, "paused") == "", "Pause a campaign")
	var history_before: int = state.advertising.history.size()
	sim.advance(1)
	expect(state.advertising.history.size() == history_before + 1 and state.advertising.history.back().campaign_id == second,
		"Paused campaign does not spend while another campaign remains active")
	expect(Ads.set_status(state, first, "active") == "", "Resume a campaign")
	sim.advance(7)
	var first_metrics := Ads.aggregate(state, first, 3, state.day - 1)
	var second_metrics := Ads.aggregate(state, second, 3, state.day - 1)
	for metrics in [first_metrics, second_metrics]:
		expect(metrics.spend <= (6500 * 7 if metrics.campaign_id == first else 3000 * 8),
			"Campaign spend respects its daily budget")
		expect(metrics.ctr == (100.0 * metrics.clicks / metrics.impressions if metrics.impressions else 0.0), "CTR uses clicks divided by impressions")
		expect(metrics.cpc == (float(metrics.spend) / metrics.clicks if metrics.clicks else 0.0), "CPC handles zero clicks")
		expect(metrics.cpm == (float(metrics.spend) / metrics.impressions * 1000.0 if metrics.impressions else 0.0), "CPM handles zero impressions")
		expect(metrics.cpa == (float(metrics.spend) / metrics.purchases if metrics.purchases else 0.0), "CPA handles zero purchases")
		expect(metrics.roas == (float(metrics.attributed_revenue - metrics.attributed_refunds) / metrics.spend if metrics.spend else 0.0), "ROAS uses net attributed revenue")
	expect(first_metrics.spend > 0 and second_metrics.spend > 0, "Active campaign budgets fund ad delivery")
	expect(int(state.advertising.visitors.get(0, 0)) >= 15, "Campaign clicks accumulate retargeting activity")
	var retarget := campaign_config(0, 0)
	retarget.name = "Warm audience"
	retarget.audience = 3
	retarget.start_day = state.day
	expect(Ads.create(state, retarget) == "", "Retargeting becomes available after enough visits")
	expect(Ads.set_status(state, second, "stopped") == "", "Stop a campaign independently")
	expect(Ads.set_status(state, second, "active") != "", "Stopped campaigns cannot be restarted")
	reconcile(sim, "Campaign simulation")
	var cash_limited := game(0, 999)
	cash_limited.state.cash = 500
	cash_limited.state.ledger[0].capital = 500
	Stores.set_active(cash_limited.state, 1, false)
	Stores.set_listing(cash_limited.state, 0, 0, 9500, true)
	expect(Ads.create(cash_limited.state, campaign_config(0, 0, 0, 10000)) == "", "Create a campaign for the cash-cap test")
	cash_limited.advance(1)
	expect(cash_limited.state.advertising.history[0].spend == 100 and cash_limited.state.cash == 0,
		"Daily advertising spend is capped by cash remaining after operating expenses")
	reconcile(cash_limited, "Cash-limited advertising")

func test_campaign_attribution_refunds_and_save() -> void:
	var sim := game(0, 440)
	var state := sim.state
	add_delivered_stock(sim, 0, 300)
	Stores.set_listing(state, 0, 0, 10000, true)
	expect(Ads.create(state, campaign_config(0, 0, 0, 8000)) == "", "Create an attribution test campaign")
	var campaign_id: int = state.advertising.next_campaign - 1
	sim.advance(10)
	var attributed_orders := 0
	var attributed_total := 0
	for order in state.orders.values():
		if order.campaign_id == campaign_id:
			attributed_orders += 1
			attributed_total += order.total
	var metrics := Ads.aggregate(state, campaign_id, 3, state.day - 1)
	expect(metrics.purchases == attributed_orders and metrics.attributed_revenue == attributed_total,
		"Advertising purchases and attributed revenue match the actual campaign-linked orders exactly")
	var seen_orders := {}
	for order in state.orders.values():
		if order.campaign_id > 0:
			seen_orders[order.id] = true
	expect(seen_orders.size() == attributed_orders, "Each paid order is attributed to at most one campaign")
	expect(metrics.purchases > 0, "Seeded campaign creates at least one attributed order")
	if attributed_orders > 0:
		var order_id: int = state.orders.keys()[0]
		for id in state.orders:
			if state.orders[id].campaign_id == campaign_id and state.orders[id].status == "delivered":
				order_id = id
				break
		var selected: Dictionary = state.orders[order_id]
		if selected.status == "delivered":
			expect(Service.refund(sim, order_id) == "", "Refund a delivered attributed order")
			var adjusted := Ads.aggregate(state, campaign_id, 0, state.day)
			expect(adjusted.attributed_refunds == selected.total and adjusted.net_attributed_revenue == adjusted.attributed_revenue - selected.total,
				"Refund is separately subtracted from attributed revenue")
			expect(adjusted.estimated_costs_reversed >= 0, "Refund reversals do not create negative estimated direct costs")
	var report := sim.report(sim.state.day)
	expect(report.advertising > 0, "Campaign spend is posted to the consolidated income statement")
	# Advertising is recognized in the ledger once, independently from attribution metrics.
	expect(report.advertising == state.ledger.map(func(row): return row.advertising).reduce(func(a, b): return a + b, 0),
		"Income statement aggregates campaign spend once")
	expect(report.closing_cash == state.cash and report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained,
		"Ads, delivery, and refunds reconcile across the three statements")
	var path := "user://phase3_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(state, path) == OK, "Save campaign and store data")
	var loaded := Saves.load_state(path)
	expect(not loaded.is_empty() and loaded.advertising.campaigns == state.advertising.campaigns and loaded.stores == state.stores,
		"Campaigns, metrics, and store listings survive save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_bundle_limits() -> void:
	var sim := game()
	var state := sim.state
	expect(Storefront.set_bundle(state, 0, 1, 10) != "", "Bundle rejects fewer than two units")
	expect(Storefront.set_bundle(state, 0, 11, 10) != "", "Bundle rejects more than ten units")
	for quantity in [2, 10]:
		expect(Storefront.set_bundle(state, 0, quantity, 15) == "", "Bundle accepts quantity %d" % quantity)
		expect(Storefront.offers_for(state, 0)[1].quantity == quantity, "Bundle quantity %d is saved" % quantity)
	var full := game()
	add_delivered_stock(full, 0, 10)
	full.list_product(0, 10000)
	expect(Storefront.set_bundle(full.state, 0, 10, 15) == "", "Configure a maximum-size bundle")
	var offer: Dictionary = Storefront.offers_for(full.state, 0)[1]
	var selected_seed := 0
	for seed_value in 100:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < Storefront.offer_uptake(1, 15):
			selected_seed = seed_value
			break
	var buyer := RandomNumberGenerator.new()
	buyer.seed = selected_seed
	var bundle_order: int = Storefront.complete_checkout(full, 0, 10000, 0, {1: offer}, buyer, 0)
	expect(bundle_order > 0 and full.state.orders[bundle_order].items.size() == 10 and full.stock(0) == 0,
		"Ten-unit bundle validates, deducts, and reserves the full inventory quantity")
	expect(full.state.orders[bundle_order].total == 85000 and Saves.valid(full.state),
		"Bundle discount allocates revenue and inventory consistently")
	var history_before: int = state.orders.size()
	state.offers[0][1].quantity = 11
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	Storefront.complete_checkout(sim, 0, 10000, 0, {1: state.offers[0][1]}, rng, 0)
	expect(state.orders.size() == history_before, "Raw oversized offer cannot create a malformed historical order")
	state.offers[0][1].quantity = 10
	expect(Saves.valid(state), "Valid bundle settings keep the save valid")

func test_save_migration() -> void:
	var state := game().state
	var historic_ledger: Array = state.ledger.duplicate(true)
	state.version = 2
	state.erase("advertising")
	state.erase("stores")
	state.erase("next_store")
	state.offers[0] = {"mode": 1, "quantity": 14, "discount": 10, "enabled": true}
	Sim.upgrade(state)
	expect(state.version == Sim.VERSION and state.stores.size() == 2 and state.advertising.campaigns.is_empty(),
		"Phase 2 save receives legacy stores and an empty advertising profile")
	expect(state.offers[0][1].quantity == 10 and state.ledger == historic_ledger,
		"Oversized bundle normalizes without changing historical ledger entries")
	expect(Saves.valid(state), "Migrated Phase 2 data passes save validation")
	var legacy_identity := game().state
	legacy_identity.owner = ""
	Stores.set_listing(legacy_identity, 0, 0, 9000, true)
	legacy_identity.quotes[0] = {1: {"cost": 2400, "minimum": 3, "expires": 7, "discount": 8}}
	expect(Ads.create(legacy_identity, campaign_config(0, 0)).is_empty(), "Legacy campaign fixture is valid")
	var legacy_campaign_id: int = legacy_identity.advertising.next_campaign - 1
	Ads.set_status(legacy_identity, legacy_campaign_id, "paused")
	var stores_before: Array = legacy_identity.stores.duplicate(true)
	var contracts_before: Dictionary = legacy_identity.quotes.duplicate(true)
	var campaigns_before: Dictionary = legacy_identity.advertising.campaigns.duplicate(true)
	Sim.upgrade(legacy_identity)
	expect(legacy_identity.owner.is_empty() and legacy_identity.stores == stores_before and legacy_identity.quotes == contracts_before,
		"Legacy save keeps blank entrepreneur identity and retains stores and supplier contracts for the identity prompt")
	expect(legacy_identity.advertising.campaigns == campaigns_before and legacy_identity.products == game().state.products,
		"Legacy save migration preserves campaigns and product inventory state")
	expect(Saves.valid(legacy_identity), "Legacy save with missing CEO name remains loadable")

func test_supplier_progression() -> void:
	var sim := game(1)
	var state := sim.state
	expect(Supply.supplier_unlocked(state, 0), "Legacy supplier index zero remains available")
	expect(not Supply.supplier_unlocked(state, 7), "Level 2 supplier starts locked")
	state.supplier_thresholds_usd = [0, 10, 100, 1000]
	var earned := Catalog.local_cents(state.country, 40.0)
	state.ledger.back().sales += earned
	state.cash += earned
	Supply.ensure_progress(state)
	expect(state.supplier_level == 2 and Supply.supplier_unlocked(state, 7), "USD equivalent sales unlock Level 2")
	state.ledger[0].sales = 0
	state.cash -= earned
	Supply.ensure_progress(state)
	expect(state.supplier_level == 2, "Supplier levels remain permanently unlocked after sales totals change")
	var hundred_usd := Catalog.local_cents(state.country, 100.0 / Catalog.SCALE[1])
	state.ledger[0].sales = hundred_usd
	state.cash += hundred_usd
	Supply.ensure_progress(state)
	expect(state.supplier_level == 3 and Supply.supplier_unlocked(state, 12), "Cumulative USD sales unlock Level 3")
	var million_usd := Catalog.local_cents(state.country, 1000000.0 / Catalog.SCALE[1])
	state.ledger[0].sales = million_usd
	state.cash += million_usd - hundred_usd
	Supply.ensure_progress(state)
	expect(state.supplier_level == 4 and Supply.supplier_unlocked(state, 17), "Cumulative USD sales unlock Level 4")
	expect(Supply.negotiate(state, 0, 7, 100) == "", "Unlocked wholesale supplier can negotiate")
	expect(Catalog.SUPPLIERS[7].minimum > Catalog.SUPPLIERS[0].minimum and Catalog.SUPPLIERS[7].lead > Catalog.SUPPLIERS[0].lead, "Wholesale MOQ and lead differ from legacy retail contracts")
	expect(Saves.valid(state), "Supplier unlock and negotiated contract remain save-valid")
	var progress_path := "user://phase3_supplier_progress.save"
	expect(Saves.save(state, progress_path, 1.0) == OK, "Save supplier progress and existing contract")
	var loaded := Saves.load_state(progress_path)
	expect(loaded.get("supplier_level", 0) == 4 and loaded.get("supplier_unlocks", []) == state.get("supplier_unlocks", []),
		"Supplier level and permanent unlock history survive Save and Load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))

func test_campaign_lifecycle() -> void:
	var sim := game()
	var state := sim.state
	add_delivered_stock(sim, 0, 5)
	expect(Stores.set_listing(state, 0, 0, 9000, true).is_empty(), "Campaign fixture listing is eligible")
	var config := campaign_config(0, 0, 0)
	config.draft = true
	expect(Ads.create(state, config).is_empty(), "Save a campaign draft")
	var id: int = state.advertising.next_campaign - 1
	var before: int = state.cash
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	Ads.simulate_day(sim, rng)
	expect(state.cash == before and state.advertising.history.is_empty(), "Draft campaign does not spend")
	expect(Ads.set_status(state, id, "active").is_empty(), "Launch draft campaign")
	expect(Ads.set_status(state, id, "paused").is_empty(), "Pause active campaign")
	before = state.cash
	Ads.simulate_day(sim, rng)
	expect(state.cash == before, "Paused campaign does not spend")
	expect(Ads.set_status(state, id, "active").is_empty(), "Resume paused campaign")
	expect(Ads.set_status(state, id, "stopped").is_empty(), "Stop campaign")
	expect(Ads.duplicate_stopped(state, id).is_empty(), "Stopped campaign can be duplicated")
	expect(state.advertising.campaigns[state.advertising.next_campaign - 1].status == "draft", "Duplicate starts as a draft")
	expect(Saves.valid(state), "Campaign lifecycle state remains valid after transitions")

func test_supplier_direct_fulfillment() -> void:
	var sim := game(0, 721)
	var state := sim.state
	sim.select_supplier(0, 4)
	var cash_before: int = state.cash
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var order_id: int = Storefront.complete_checkout(sim, 0, 12000, 0, {}, rng, 0)
	expect(order_id > 0 and sim.stock(0) == 0, "Unlocked dropship supplier fulfills without reserving warehouse stock")
	var order: Dictionary = state.orders.get(order_id, {})
	expect(order.get("items", []).size() == 1 and order.items[0].get("direct_supplier", -1) == 4,
		"Direct order records its supplier and landed cost")
	expect(state.ledger.back().purchases > 0 and state.cash < cash_before + 12000,
		"Direct supplier cost and freight are paid exactly once")
	expect(Saves.valid(state), "Direct supplier order remains compatible with save validation")
	sim.advance(8)
	order = state.orders[order_id]
	expect(order.status == "delivered" and sim.stock(0) == 0,
		"Supplier lead time controls delivery without deducting or replenishing warehouse stock")
	reconcile(sim, "Supplier direct fulfillment")
