extends SceneTree

const Catalog = preload("res://catalog.gd")
const Sim = preload("res://simulation.gd")
const Supply = preload("res://supply.gd")
const Stores = preload("res://store_manager.gd")
const Saves = preload("res://save_store.gd")
const Slots = preload("res://save_slots.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Ads = preload("res://advertising.gd")

var failures := 0

func _initialize() -> void:
	test_product_catalogue_and_stable_indices()
	test_supplier_quantity_limits()
	test_listing_preorder_lifecycle_and_accounting()
	test_preorder_save_lifecycle()
	test_advertising_economics()
	test_advertising_preorder_conversion()
	print("Phase 3.3 focused simulation: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func test_product_catalogue_and_stable_indices() -> void:
	expect(Catalog.PRODUCTS.size() == 100, "Catalogue contains 100 products")
	expect(Catalog.PRODUCTS.slice(0, 5).map(func(item): return item.name) == [
		"Portable Blender", "Wireless Earbuds", "Travel Organizer", "Desk Lamp", "Water Bottle"],
		"Original five numeric product indices remain unchanged")
	var counts := {}
	var stable_ids := {}
	for item in Catalog.PRODUCTS:
		counts[item.category] = int(counts.get(item.category, 0)) + 1
		expect(not stable_ids.has(item.id), "Stable product IDs are unique: %s" % item.id)
		stable_ids[item.id] = true
		expect(Catalog.product_index(item.id) == Catalog.PRODUCTS.find(item), "Stable product ID resolves to the original index")
		expect(item.seasonality.size() == 12 and item.demand > 0 and item.competition > 0, "Product includes seasonality, demand, and competition")
	for category in Catalog.CATEGORIES:
		expect(int(counts.get(category, 0)) == 10, "%s has ten products" % category)
	var state: Dictionary = Sim.register("Founder", "Stable Goods", "", 0, 1, 0, 81)
	state.products[1] = {"supplier": Catalog.DEFAULT_SUPPLIER, "supplier_id": Catalog.supplier_id(Catalog.DEFAULT_SUPPLIER), "price": 7000, "listed": false, "lots": [], "channel_mask": 3}
	Sim.upgrade(state)
	expect(state.products[1].product_id == "obt.electronics.wireless_earbuds", "Legacy numeric product 1 keeps its stable identity")
	expect(Catalog.product_seasonality(0, 1) != Catalog.product_seasonality(0, 182), "Demand has date-based category seasonality")

func test_supplier_quantity_limits() -> void:
	var data: Dictionary = Sim.register("Founder", "Wholesale Lab", "", 1, 0, 0, 812)
	data.supplier_level = 4
	data.supplier_unlocks = Catalog.SUPPLIER_SELECTION_INDICES.duplicate()
	data.supplier_unlock_ids = Catalog.SUPPLIER_SELECTION_INDICES.map(func(index): return Catalog.supplier_id(index))
	expect(Catalog.SUPPLIER_SELECTION_INDICES.size() == 9, "The existing nine supplier identities remain the selectable platforms")
	var sim := Sim.new(data)
	expect(Supply.maximum_order_quantity(3) == 500, "AliExpress has a simulated 500-unit maximum")
	expect(Supply.maximum_order_quantity(17) > 999, "Enterprise supplier supports more than 999 units")
	expect(Supply.purchase(sim.state, 1, 17, 1000001) != "", "Enterprise maximum quantity is enforced")
	var total_per_unit: int = Supply.quote(sim.state, 4, 17).cost + Catalog.inbound_freight(1, 17)
	var order_units := 1001
	var top_up: int = total_per_unit * order_units + 100000
	sim.state.cash += top_up
	sim.state.ledger.back().capital += top_up
	expect(Supply.purchase(sim.state, 4, 17, order_units) == "", "Enterprise purchase above 999 succeeds when affordable")
	expect(sim.state.inbound.back().units == order_units and sim.state.inbound.back().product_id == Catalog.product_id(4), "Large supplier order retains stable product identity")
	expect(Saves.valid(sim.state), "Large supplier order remains save-valid and financially balanced")
	var catalogue_game := Sim.new(Sim.register("Founder", "Hundred Goods", "", 0, 1, 0, 1901))
	Stores.create(catalogue_game.state, "Catalogue Shop", 0, "Catalogue", "", 0)
	var catalogue_store: int = int(catalogue_game.state.stores.back().id)
	for product_id in Catalog.PRODUCTS.size():
		var item: Dictionary = catalogue_game.product_state(product_id)
		var quote := Supply.quote(catalogue_game.state, product_id, Catalog.DEFAULT_SUPPLIER)
		expect(item.get("product_id", "") == Catalog.product_id(product_id) and quote.cost > 0,
			"Product %d has a stable identity and valid supplier quote" % product_id)
		expect(Stores.set_listing(catalogue_game.state, catalogue_store, product_id, 10000, true) == "",
			"Product %d can be listed in a store" % product_id)
	expect(Stores.listing(catalogue_game.state, catalogue_store, 99).product_id == Catalog.product_id(99),
		"Product 100 supports persistent store listing metadata")

func test_listing_preorder_lifecycle_and_accounting() -> void:
	var data: Dictionary = Sim.register("Founder", "Preorder Lab", "", 0, 1, 0, 419)
	var sim := Sim.new(data)
	expect(Stores.create(sim.state, "North Market", 0, "North", "", 0) == "", "Create a marketplace for listing-level pre-orders")
	var first_store: int = int(sim.state.stores.back().id)
	expect(Stores.create(sim.state, "South Market", 0, "South", "", 0) == "", "Create a second store with an independent pre-order setting")
	var second_store: int = int(sim.state.stores.back().id)
	expect(Stores.set_listing(sim.state, first_store, 0, 10000, true, true) == "", "Enable pre-orders on one store listing")
	expect(Stores.set_listing(sim.state, second_store, 0, 10000, true, false) == "", "Disable pre-orders on another listing of the same product")
	expect(Stores.listing(sim.state, first_store, 0).allow_preorders and not Stores.listing(sim.state, second_store, 0).allow_preorders,
		"Pre-order settings are stored independently for each listing")
	var before_cash: int = sim.state.cash
	var blocked: int = Fulfillment.place(sim, 0, [0], 10000, "", [10000], second_store, 0, false)
	expect(blocked == 0 and sim.state.cash == before_cash, "Out-of-stock listing rejects a new order when pre-orders are off")
	var cancelled_id := Fulfillment.place(sim, 0, [0], 10000, "", [10000], first_store, 0, true)
	expect(cancelled_id > 0 and sim.state.orders[cancelled_id].preorder_status == "awaiting_stock", "Out-of-stock listing accepts a pending pre-order")
	expect(sim.stock(0) == 0 and sim.state.orders[cancelled_id].items[0].awaiting_stock, "Pre-order creates no negative or fictional warehouse stock")
	expect(sim.state.ledger.back().sales == 0 and sim.state.ledger.back().deposits == 10000, "Pre-order payment is a customer deposit until delivery")
	expect(Saves.valid(sim.state), "Pending pre-order save validates with customer deposit liability")
	expect(Service.cancel_preorder(sim, cancelled_id) == "", "Player can cancel and refund an awaiting-stock pre-order")
	expect(sim.state.orders[cancelled_id].status == "cancelled" and sim.state.cash == before_cash and sim.state.ledger.back().deposits == 0,
		"Cancellation reverses the cash receipt and customer deposit without recognizing revenue")
	expect(Saves.valid(sim.state), "Cancelled pre-order remains save-valid")
	expect(_save_preorder_state(sim.state, cancelled_id, "cancelled"), "Cancelled and refunded state survives a manual save and load")
	var order_id := Fulfillment.place(sim, 0, [0], 10000, "", [10000], first_store, 0, true)
	expect(order_id > 0, "A second customer can place a pre-order")
	expect(Supply.purchase(sim.state, 0, Catalog.DEFAULT_SUPPLIER, 1) == "", "Warehouse replenishment can be purchased while a customer pre-order is outstanding")
	for batch in sim.state.inbound:
		batch.eta = sim.state.day
		batch.arrival = sim.state.day
	Supply.receive(sim)
	Fulfillment.allocate_preorders(sim)
	var order: Dictionary = sim.state.orders[order_id]
	expect(order.preorder_status == "ready_for_fulfillment" and not order.items[0].has("awaiting_stock"), "Received inventory is reserved for the oldest pre-order")
	expect(sim.stock(0) == 0 and Saves.valid(sim.state), "Allocated stock is reserved once and the pending save reconciles")
	expect(Fulfillment.ship(sim.state, order_id, sim.state.shipping) == "", "Allocated pre-order can enter normal fulfillment")
	order.arrival = sim.state.day
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	Fulfillment.deliver(sim.state, rng)
	expect(order.status == "delivered" and order.preorder_status == "delivered", "Existing fulfillment completes the pre-order lifecycle")
	expect(sim.state.ledger.back().sales == 10000 and sim.state.ledger.back().deposits == 0, "Revenue is recognized once when the order is delivered")
	expect(Saves.valid(sim.state), "Delivered pre-order, supplier costs, and statements remain save-valid")
	expect(_save_preorder_state(sim.state, order_id, "delivered"), "Delivered state survives a manual save and load")
	var report: Dictionary = sim.report(sim.state.day)
	expect(report.customer_deposits == 0 and report.inventory == 0, "Delivered order clears deposit liability and recognizes inventory cost")

func test_preorder_save_lifecycle() -> void:
	var sim := Sim.new(Sim.register("Founder", "Lifecycle Lab", "", 0, 1, 0, 611))
	Stores.create(sim.state, "Lifecycle Market", 0, "Lifecycle", "", 0)
	var store_id: int = int(sim.state.stores.back().id)
	Stores.set_listing(sim.state, store_id, 0, 10000, true, true)
	var capital := 1000000
	sim.state.cash += capital
	sim.state.ledger.back().capital += capital
	expect(Supply.purchase(sim.state, 0, Catalog.DEFAULT_SUPPLIER, 1) == "", "Lifecycle fixture replenishes first SKU")
	for batch in sim.state.inbound:
		batch.eta = sim.state.day
		batch.arrival = sim.state.day
	Supply.receive(sim)
	var order_id: int = Fulfillment.place(sim, 0, [0, 1], 20000, "", [10000, 10000], store_id, 0, true)
	expect(order_id > 0, "Multi-product preorder accepts an out-of-stock SKU")
	Fulfillment.allocate_preorders(sim)
	expect(sim.state.orders[order_id].preorder_status == "stock_allocated",
		"First available SKU moves a partial preorder to Stock Allocated")
	expect(_save_preorder_state(sim.state, order_id, "stock_allocated"), "Partially allocated state survives a manual save and load")
	expect(Supply.purchase(sim.state, 1, Catalog.DEFAULT_SUPPLIER, 1) == "", "Lifecycle fixture replenishes second SKU")
	for batch in sim.state.inbound:
		batch.eta = sim.state.day
		batch.arrival = sim.state.day
	Supply.receive(sim)
	Fulfillment.allocate_preorders(sim)
	expect(sim.state.orders[order_id].preorder_status == "ready_for_fulfillment", "All required inventory moves preorder to Ready for Fulfillment")
	expect(_save_preorder_state(sim.state, order_id, "ready_for_fulfillment"), "Ready state survives a manual save and load")
	expect(Fulfillment.ship(sim.state, order_id, sim.state.shipping) == "", "Ready preorder can ship through normal fulfillment")
	expect(sim.state.orders[order_id].preorder_status == "shipped", "Shipping sets the Shipped lifecycle state")
	expect(_save_preorder_state(sim.state, order_id, "shipped"), "Shipped state survives a manual save and load")
	var order: Dictionary = sim.state.orders[order_id]
	order.arrival = sim.state.day
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	Fulfillment.deliver(sim.state, rng)
	expect(order.preorder_status == "delivered" and _save_preorder_state(sim.state, order_id, "delivered"),
		"Delivered lifecycle state remains loadable")

func _save_preorder_state(state: Dictionary, order_id: int, expected: String) -> bool:
	if Slots.write(3, state) != OK: return false
	var loaded := Slots.read(3)
	var valid: bool = str(loaded.get("state", {}).get("orders", {}).get(order_id, {}).get("preorder_status", "")) == expected
	Slots.delete_slot(3)
	return valid

func test_advertising_economics() -> void:
	var easy: Sim = _economics_game(0, 8640)
	var normal_price: Dictionary = {"name": "Test", "product": 0, "platform": 0, "audience": 0, "objective": 3, "creative": 0, "learning": 1.0}
	var easy_listing: Dictionary = Stores.listing(easy.state, int(easy.state.stores.back().id), 0)
	var normal_probability: float = Ads.purchase_probability(easy, normal_price, easy_listing)
	var baseline_cpm: int = Ads.effective_cpm(easy.state, 0, 0, 0)
	var expensive: Sim = _economics_game(0, 864000)
	var expensive_listing: Dictionary = Stores.listing(expensive.state, int(expensive.state.stores.back().id), 0)
	var expensive_probability: float = Ads.purchase_probability(expensive, normal_price, expensive_listing)
	expect(Ads.effective_cpm(easy.state, 0, 0, 0) == Ads.effective_cpm(expensive.state, 0, 0, 0), "Selling price does not directly increase CPM")
	expect(expensive_probability < normal_probability, "Higher selling price lowers purchase probability through unit economics")
	var hard: Sim = _economics_game(2, 8640)
	var hard_listing: Dictionary = Stores.listing(hard.state, int(hard.state.stores.back().id), 0)
	expect(Ads.effective_cpm(hard.state, 0, 0, 0) > baseline_cpm, "Hard difficulty increases simulated competitive CPM")
	expect(Ads.purchase_probability(hard, normal_price, hard_listing) < normal_probability, "Hard difficulty reduces potential conversion probability")
	expect(Ads.effective_cpm(easy.state, 0, 1, 0) != Ads.effective_cpm(easy.state, 0, 0, 0), "Advertising platforms have distinct CPM economics")

func test_advertising_preorder_conversion() -> void:
	var converted := false
	for seed in range(1, 40):
		var sim: Sim = _economics_game(0, 7000)
		sim.state.seed = seed
		var store_id: int = int(sim.state.stores.back().id)
		Stores.set_listing(sim.state, store_id, 0, 7000, true, true)
		var config := {"name": "Pre-order awareness", "store_id": store_id, "product": 0,
			"platform": 0, "daily_budget": 100000, "audience": 0, "objective": 3, "bid_strategy": 0, "creative": 1}
		expect(Ads.create(sim.state, config) == "", "Advertising accepts an enabled pre-order listing")
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		Ads.simulate_day(sim, rng)
		if not sim.state.advertising.history.is_empty() and int(sim.state.advertising.history.back().preorders) > 0:
			converted = true
			expect(Fulfillment.outstanding_preorders(sim.state, 0, store_id) > 0, "Campaign pre-order conversion creates a pending fulfillment order")
			expect(sim.state.advertising.history.back().purchases == 0, "Pre-order is counted separately from completed purchases")
			var capital := 1000000
			sim.state.cash += capital
			sim.state.ledger.back().capital += capital
			expect(Supply.purchase(sim.state, 0, Catalog.DEFAULT_SUPPLIER, 1) == "", "Pre-order conversion can be fulfilled after restocking")
			for batch in sim.state.inbound:
				batch.eta = sim.state.day
				batch.arrival = sim.state.day
			Supply.receive(sim)
			Fulfillment.allocate_preorders(sim)
			var order_id := 0
			for id in sim.state.active_orders:
				if int(sim.state.orders[id].get("campaign_id", 0)) == 1:
					order_id = int(id)
					break
			expect(Fulfillment.ship(sim.state, order_id, sim.state.shipping) == "", "Campaign pre-order ships after inventory allocation")
			sim.state.orders[order_id].arrival = sim.state.day
			var delivery_rng := RandomNumberGenerator.new()
			delivery_rng.seed = seed + 20
			Fulfillment.deliver(sim.state, delivery_rng)
			var attributed := Ads.aggregate_range(sim.state, 1, 1, sim.state.day)
			expect(attributed.conversions == attributed.preorders and attributed.preorders > 0 and attributed.purchases == 0,
				"Pre-order delivery does not create a duplicate advertising conversion")
			expect(attributed.attributed_revenue == 7000, "Campaign revenue is attributed when the pre-order is delivered")
			break
	expect(converted, "Seeded advertising runs can produce real pre-order conversions")

func _economics_game(difficulty: int, listing_price: int) -> Sim:
	var data: Dictionary = Sim.register("Founder", "Ads Lab", "", 0, difficulty, 0, 729)
	var sim := Sim.new(data)
	Stores.create(sim.state, "Ads Store", 0, "Ads", "", 0)
	var store_id: int = int(sim.state.stores.back().id)
	Stores.set_listing(sim.state, store_id, 0, listing_price, true, true)
	return sim
