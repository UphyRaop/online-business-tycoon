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
	var boundary_state := Sim.register("Report CEO", "Report Co", "", 0, 1, 0, 911)
	var boundary_sim := Sim.new(boundary_state)
	boundary_state.ledger[0].sales = 500
	boundary_state.ledger[0].channels[0].sales = 500
	var day_one_history := boundary_sim.report_completed(30)
	expect(day_one_history.end == 0 and day_one_history.sales == 0,
		"Day 1 unfinished ledger activity is excluded from completed historical reports")
	boundary_state.day = 2
	boundary_state.ledger.append(Sim.entry())
	boundary_state.ledger[1].sales = 900
	var daily_history := boundary_sim.calendar_report_completed(0, 2)
	expect(daily_history.end == 1 and daily_history.sales == 500,
		"Daily reports anchored to the current day stop at the last completed day")
	var future_history := boundary_sim.report_completed(30, 999)
	expect(future_history.end == 1 and future_history.sales == 500,
		"Historical reports cap future anchors before current unfinished ledger entries")

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

	var day_one_sim := Sim.new(Sim.register("Day One", "Opening Balance", "", 0, 0, 0, 3842))
	var day_one_daily := Finance.completed_period_report(day_one_sim, 0, 1)
	var day_one_month := Finance.completed_period_report(day_one_sim, 2, 1)
	expect(day_one_daily.end == 0 and day_one_daily.sales == 0,
		"Day 1 daily reports exclude unfinished activity")
	expect(day_one_month.end == 0 and day_one_month.sales == 0,
		"Day 1 monthly reports contain no unfinished current-day activity")
	day_one_sim.state.day = 2
	day_one_sim.state.ledger.append(Sim.entry())
	var day_two_daily := Finance.completed_period_report(day_one_sim, 0, 2)
	var day_two_month := Finance.completed_period_report(day_one_sim, 2, 2)
	expect(day_two_daily.end == 0 and day_two_daily.sales == 0,
		"A selected current daily period remains empty until that day completes")
	expect(day_two_month.start == 1 and day_two_month.end == 1,
		"A monthly report includes completed days but excludes the current unfinished day")

	var transaction_row: Dictionary = Sim.entry()
	transaction_row.sales = 10000
	transaction_row.refunds = 500
	transaction_row.deposits = 2500
	transaction_row.capital = 500
	transaction_row.purchases = 8000
	transaction_row.credit_purchases = 2000
	transaction_row.inbound_freight = 1000
	transaction_row.credit_inbound_freight = 400
	transaction_row.direct_purchases = 2000
	transaction_row.direct_inbound_freight = 300
	transaction_row.supplier_repayments = 900
	transaction_row.supplier_credit_adjustments = 100
	transaction_row.supplier_refunds = 700
	transaction_row.cogs = 4000
	transaction_row.fees = 250
	transaction_row.shipping = 800
	transaction_row.overhead = 200
	transaction_row.hosting = 100
	transaction_row.advertising = 300
	transaction_row.store_setup = 600
	transaction_row.store_expenses = 150
	transaction_row.inventory_returns = 1000
	var transaction_state: Dictionary = Sim.register("Txn", "Transactions", "", 0, 0, 0, 3843)
	transaction_state.day = 2
	transaction_state.ledger[0] = transaction_row
	transaction_state.ledger.append(Sim.entry())
	var transactions := Finance.transaction_rows(transaction_state, 1, 2)
	var transaction_cash_total := 0
	if not transactions.is_empty():
		for item in transactions[0].incoming: transaction_cash_total += int(item.amount)
		for item in transactions[0].outgoing: transaction_cash_total += int(item.amount)
	expect(transactions.size() == 1 and transaction_cash_total == Sim.cash_change(transaction_row),
		"Money In/Out transaction activity reconciles exactly to ledger cash movement with supplier credit and freight")
	expect(transactions[0].other.any(func(item): return item.label == "Cost of goods sold")
		and transactions[0].incoming.any(func(item): return item.label == "Supplier refunds")
		and transactions[0].outgoing.any(func(item): return item.label == "Supplier repayments"),
		"Transaction categories separate non-cash costs from receipts and payments")

	var store_report_state: Dictionary = Sim.register("Store", "Store Reports", "", 0, 0, 0, 3844)
	var store_id := int(store_report_state.next_store)
	expect(Stores.create(store_report_state, "Report Store", 0, "Report", "", 0).is_empty(),
		"Store report fixture can create a destination")
	var store_current: Dictionary = Stores.store_activity(store_report_state.ledger[0], store_id)
	store_current.sales = 700
	store_current.setup = 250
	var current_only := Stores.report(store_report_state, store_id)
	expect(current_only.sales == 0 and current_only.setup == 0,
		"Store report excludes setup and sales from the unfinished Day 1")
	store_report_state.day = 2
	store_report_state.ledger.append(Sim.entry())
	var pending_activity: Dictionary = Stores.store_activity(store_report_state.ledger[1], store_id)
	pending_activity.sales = 9999
	var completed_only := Stores.report(store_report_state, store_id, 2, 1)
	var current_range := Stores.report(store_report_state, store_id, 2, 2)
	expect(completed_only.sales == 700 and completed_only.setup == 250,
		"Explicit store report end day is clamped before current unfinished activity")
	expect(current_range.sales == 0,
		"Store reporting range cannot include the unfinished current day")
	expect(int(state.version) == 6 and Saves.valid(state),
		"Read-only reporting preserves the existing save schema and company data")
	print("Phase 4 financial reporting: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
