extends SceneTree

const Sim = preload("res://simulation.gd")
const Saves = preload("res://save_store.gd")
const Slots = preload("res://save_slots.gd")
const Catalog = preload("res://catalog.gd")
const Summary = preload("res://product_summary.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Stores = preload("res://store_manager.gd")

var failures := 0

func _initialize() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Use a fresh isolated save profile for final_test.gd.")
		quit(1)
		return
	test_slots()
	test_products()
	print("Phase 2 final simulation and saves: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func game(company: String) -> Sim:
	var state := Sim.register("Mira", company, "Aster Shop", 0, 1, 2, 153)
	state.website_active = true
	state.stores = Stores.migration_defaults(state) # Explicit legacy fixture stores for old-save and channel regression coverage.
	return Sim.new(state)

func test_slots() -> void:
	var legacy := game("Legacy Company")
	legacy.list_product(1, 6500)
	legacy.state.products[1].erase("channel_mask")
	expect(Saves.save(legacy.state) == OK, "Write a legacy Phase 2 save")
	var old := Slots.read(Slots.AUTOSAVE)
	expect(old.state == legacy.state and old.saved_at > 0, "Legacy save appears in Autosave with date and company")
	expect(Sim.new(old.state).product_on_channel(old.state.products[1], 1), "Legacy listing remains on its enabled channels")

	var first := game("Company One")
	var second := game("Company Two")
	second.advance(2)
	var third := game("Company Three")
	expect(Slots.write(1, first.state, 10) == OK and Slots.write(2, second.state, 20) == OK and Slots.write(3, third.state, 30) == OK, "Three independent manual slots can be saved")
	expect(Slots.read(1).state == first.state and Slots.read(2).state == second.state and Slots.read(3).state == third.state, "Manual slots preserve independent games")
	expect(Slots.write(0, legacy.state, 40) == OK and Slots.latest().slot == 0, "Latest timestamp can select autosave")
	expect(Slots.write(2, second.state, 50) == OK and Slots.latest().slot == 2, "Latest timestamp can select a manual slot")
	var file := FileAccess.open(Slots.path_for(2), FileAccess.WRITE)
	file.store_string("bad")
	file.close()
	expect(Slots.read(2).saved_at == 20 and Slots.latest().slot == 0, "Corrupt primary recovers the valid backup and its original timestamp")
	file = FileAccess.open(Slots.path_for(3), FileAccess.WRITE)
	file.store_string("bad")
	file.close()
	expect(Slots.read(3).is_empty() and Slots.latest().slot == 0, "Unreadable saves are skipped")
	expect(Saves.read_file(Saves.PATH) == legacy.state, "Slots leave the legacy file intact")

func test_products() -> void:
	var sim := game("Products")
	sim.list_product(0, 8300, 1)
	sim.list_product(1, 5500, 2, false)
	expect(sim.active_product_count() == 0 and not sim.product_on_channel(sim.product_state(1), 1), "Draft and out-of-stock products are excluded from the active total")
	expect(sim.product_on_channel(sim.product_state(0), 0) and not sim.product_on_channel(sim.product_state(0), 1), "Per-product channel mask limits the listing")
	expect(sim.buy(0, 3, 5) == "" and sim.buy(1, 3, 5) == "", "Both products can order stock")
	sim.advance(10)
	for order in sim.state.orders.values():
		expect(order.channel == 0 and order.items[0].product == 0, "Checkout uses published products and permitted channels")
	sim.unlist(0)
	sim.advance(5)
	var sim2 := game("Bundle")
	sim2.buy(0, 3, 2)
	sim2.buy(1, 3, 2)
	var stock_arrival: int = maxi(sim2.state.inbound[0].arrival, sim2.state.inbound[1].arrival)
	sim2.advance(stock_arrival - sim2.state.day + 1)
	Fulfillment.place(sim2, 0, [0, 1], 10001, "bundles", [6000, 4001])
	Fulfillment.ship(sim2.state, 1, 2)
	var stats := Summary.collect(sim2.state)
	expect(stats[0].units == 0 and stats[0].revenue == 0 and stats[0].profit + stats[1].profit == -1100, "In-transit orders allocate shipping only")
	sim2.advance(5)
	stats = Summary.collect(sim2.state)
	var history := sim2.report(sim2.state.day)
	expect(stats[0].revenue == 6000 and stats[1].revenue == 4001, "Bundle sales retain the original item amounts after rounding")
	expect(stats[0].profit + stats[1].profit == history.sales - history.cogs - history.fees - history.shipping, "Product profit reconciles to direct costs")
	var order: Dictionary = sim2.state.orders[1]
	order.restockable = true
	expect(Service.refund(sim2, 1) == "", "Refund delivered bundle")
	stats = Summary.collect(sim2.state)
	expect(stats[0].units == 0 and stats[1].revenue == 0 and stats[0].profit + stats[1].profit == -history.fees - history.shipping, "Returns reverse sales and resellable COGS while preserving operating costs")
	Fulfillment.place(sim2, 1, [0, 1], 6555, "upsells")
	Fulfillment.ship(sim2.state, 2, 1)
	sim2.advance(5)
	stats = Summary.collect(sim2.state)
	expect(stats[0].revenue + stats[1].revenue == 6555 and stats[0].units == 1 and stats[1].units == 1, "Old unpriced bundle history allocates an exact order total")
	expect(Saves.valid(sim.state) and Saves.valid(sim2.state), "New product data passes save and accounting validation")
