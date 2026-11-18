extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Saves = preload("res://save_store.gd")

var failures := 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for country in Catalog.COUNTRIES.size():
		for difficulty in Catalog.DIFFICULTIES.size():
			var sim := Sim.new(Sim.register("Mira", "Aster Labs", "Aster Shop", country, difficulty, 2, 153, true))
			play_loop(sim)
	test_save()
	test_migration()
	test_channel_operations()
	print("Phase 1 simulation: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func play_loop(sim: RefCounted) -> void:
	var state: Dictionary = sim.state
	var price := Catalog.local_cents(state.country, 65)
	var quote := Catalog.quote(state.country, 1, 0) + Catalog.inbound_freight(state.country, 0)
	var other_quote := Catalog.quote(state.country, 1, 2) + Catalog.inbound_freight(state.country, 2)
	var opening: int = state.cash
	expect(sim.buy(1, 0, 1) != "", "Supplier minimum enforced")
	expect(sim.buy(1, 2, 999) != "", "Unaffordable purchase rejected")
	expect(sim.buy(1, 0, 10) == "" and sim.buy(1, 2, 2) == "", "Buy from two suppliers")
	expect(state.cash == opening - quote * 10 - other_quote * 2, "Purchase reduces cash")
	var initial: Dictionary = sim.report(1)
	expect(initial.inventory == quote * 10 + other_quote * 2 and Sim.net(initial) == 0, "Stock is capitalized before sale")
	sim.list_product(1, price)
	sim.advance(1)
	var first: Dictionary = sim.report(1, 1)
	expect(first.sales == 0 and first.inventory == initial.inventory, "Inbound stock is capitalized before delivery")
	sim.advance(2)
	sim.advance(7)
	var early_orders: int = sim.state.orders.size()
	sim.list_product(1, price + 1)
	sim.advance(30)
	expect(sim.stock(1) == 0 and state.day == 41, "Advancement consumes stock and increments time")
	var all: Dictionary = sim.report(365)
	expect(all.sales == early_orders * price + (12 - early_orders) * (price + 1), "Repricing affects future checkouts only")
	expect(all.channels[0].sales > 0 and all.channels[1].sales > 0, "Distinct channel sales")
	var fees := 0
	for order in state.orders.values():
		fees += Catalog.fee(order.channel, order.total)
	expect(all.fees == fees, "Delivered sales use channel-specific fees")
	expect(all.cogs == quote * 10 + other_quote * 2 and all.inventory == 0, "Stock costs reconcile")
	expect(all.overhead == 40 * Catalog.local_cents(state.country, Catalog.OVERHEAD[state.difficulty]), "Overhead charged every day")
	for period in Sim.PERIODS:
		for day in [1, 7, 40, 41]:
			var report: Dictionary = sim.report(period, day)
			expect(report.start == maxi(1, day - period + 1) and report.end == day, "Report date range")
			expect(report.opening_cash + Sim.cash_change(report) == report.closing_cash, "Cash flow reconciles")
			expect(report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained, "Balance sheet balances")
	expect(state.cash == all.closing_cash and Saves.valid(state), "Accounting reconciles with stored state")
	sim.unlist(1)
	expect(not sim.product_state(1).listed, "Listing can be paused")

func test_save() -> void:
	var id := "user://phase1_test_%d" % Time.get_ticks_usec()
	var path := id + ".save"
	var state := Sim.register("Mira", "Aster Labs", "Aster Shop", 0, 1, 0, 22, true)
	var sim := Sim.new(state)
	sim.buy(1, 0, 10)
	sim.list_product(1, 6500)
	expect(Saves.save(state, path) == OK, "Write local save")
	expect(Saves.load_state(path, id) == state, "Exact save and load")
	var original := state.duplicate(true)
	state.company = "Renamed Co"
	state.store = "Renamed Store"
	expect(Saves.save(state, path) == OK, "Replace local save")
	var reloaded := Sim.new(Saves.load_state(path, id))
	expect(reloaded.state == state, "Reload names and inventory")
	sim.advance(7)
	reloaded.advance(7)
	expect(reloaded.state == state, "Random sequence continues after load")
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("bad")
	damaged.close()
	expect(Saves.load_state(path, id) == original, "Recover backup from a damaged save")
	for file in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

func test_migration() -> void:
	var state := Saves.migrate({
		"country": 0, "difficulty": 1, "channel": 2, "company": "Old Store",
		"initial_cash": 5000, "history": [{"revenue": 50, "costs": 25, "orders": 1}],
		"listings": [{"product": 0, "supplier": 1, "price": 50}],
	})
	expect(not state.is_empty(), "Prototype save migrates")
	if not state.is_empty():
		var sim := Sim.new(state)
		var totals: Dictionary = sim.report(365)
		expect(totals.closing_cash == 502500 and Sim.net(totals) == 2500, "Historical cash and profit retained")
		expect(totals.channels[2].orders == 1 and sim.product_state(0).listed, "Legacy combined orders and listings retained")

func test_channel_operations() -> void:
	for channel in [0, 1]:
		var sim := Sim.new(Sim.register("Mira", "Aster Labs", "Aster Shop", 0, 2, channel, 153, true))
		sim.list_product(4, 3200)
		sim.advance(1)
		var empty := sim.report(1, 1)
		expect(empty.sales == 0 and empty.overhead > 0, "Out-of-stock listing creates no sales")
		sim.buy(4, 2, 10)
		sim.advance(14)
		var active := sim.report(14, 15)
		expect(active.channels[channel].orders > 0 and active.channels[1 - channel].orders == 0, "Exclusive channel routing")
		expect(active.hosting == (0 if channel == 0 else 11200), "Hosting only when website is enabled")
		sim.advance(365)
		var closing := sim.report(365)
		expect(closing.overdraft > 0 and closing.assets == closing.overdraft + closing.customer_deposits + closing.equity_capital + closing.retained, "Overdraft balances after cash runs out")
