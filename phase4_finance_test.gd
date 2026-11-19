extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Stores = preload("res://store_manager.gd")
const Finance = preload("res://finance_management.gd")
const Saves = preload("res://save_store.gd")

var failures := 0

func _initialize() -> void:
	var state := Sim.register("Ari Founder", "Ledger Labs", "", 0, 0, 0, 3841)
	var sim := Sim.new(state)
	var opening_report := sim.report(1)
	var opening_dashboard := Finance.dashboard(state, opening_report)
	expect(opening_dashboard.cash == state.cash and opening_dashboard.receivables == 0 and opening_dashboard.payables == 0,
		"Financial overview reads current cash and reflects immediate settlement rules")
	expect(opening_dashboard.revenue == 0 and opening_dashboard.expenses == 0 and opening_dashboard.net_profit == 0,
		"New company overview derives zero activity from the opening ledger")
	expect(state.stores.is_empty(), "Financial reporting does not create stores")

	var marketplace_error := Stores.create(state, "Ledger Market", 0, "Ledger", "", 0)
	var website_index := Stores.website_platform_index("shopify")
	var website_error := Stores.create(state, "Ledger Website", 1, "Ledger", "ledger.example.test", 0, website_index)
	expect(marketplace_error.is_empty() and website_error.is_empty(), "Fixture can create valid active store destinations")
	var setup_cash := int(state.cash)
	sim.advance(1)
	var report := sim.report(1, 1)
	var overview := Finance.dashboard(state, report)
	var expected_fixed := Catalog.local_cents(state.country, Catalog.OVERHEAD[state.difficulty])
	for store in state.stores:
		if store.active and not store.legacy:
			expected_fixed += int(store.daily_cost)
	expect(overview.known_fixed_costs == expected_fixed,
		"Known fixed-cost estimate includes overhead and active store costs only")
	expect(overview.cash_after_known_fixed_costs == int(state.cash) - expected_fixed,
		"Forecast remains a separate estimate subtracted from actual company cash")
	expect(state.cash < setup_cash and overview.cash == state.cash,
		"Reported cash is actual cash after recorded daily charges")
	expect(report.closing_cash == report.opening_cash + Sim.cash_change(report),
		"Cash flow statement opening balance plus ledger movement equals closing cash")
	expect(report.assets == report.overdraft + report.customer_deposits + report.equity_capital + report.retained,
		"Balance sheet assets reconcile with liabilities and equity")

	var categories := Finance.expense_categories(report)
	expect(categories.any(func(item): return item.id == "overhead" and item.amount > 0),
		"Expense breakdown categorizes recurring operating overhead from the ledger")
	expect(categories.any(func(item): return item.id == "store_expenses" and item.amount > 0),
		"Expense breakdown categorizes active store operating costs")
	var daily := Finance.daily_totals(state, report.start, report.end)
	expect(daily.size() == 1 and daily[0].day == 1 and daily[0].cash_change == Sim.cash_change(report),
		"Daily ledger history reconciles its cash movement with the statement")
	expect(int(state.version) == 6 and Saves.valid(state),
		"Read-only reporting preserves the existing save schema and company data")
	print("Phase 4 financial reporting: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
