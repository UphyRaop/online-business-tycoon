extends RefCounted

const Catalog = preload("res://catalog.gd")
const Simulation = preload("res://simulation.gd")
const Calendar = preload("res://game_calendar.gd")

const EXPENSE_FIELDS := [
	{"id": "cogs", "label": "Cost of Goods Sold", "field": "cogs"},
	{"id": "refunds", "label": "Customer Refunds", "field": "refunds"},
	{"id": "fees", "label": "Channel Fees", "field": "fees"},
	{"id": "shipping", "label": "Outbound Shipping", "field": "shipping"},
	{"id": "overhead", "label": "Operating Overhead", "field": "overhead"},
	{"id": "hosting", "label": "Legacy Website Hosting", "field": "hosting"},
	{"id": "advertising", "label": "Advertising", "field": "advertising"},
	{"id": "store_setup", "label": "Store Setup", "field": "store_setup"},
	{"id": "store_expenses", "label": "Store Operating Costs", "field": "store_expenses"},
	{"id": "legacy", "label": "Other Legacy Costs", "field": "legacy"},
	{"id": "supplier_return_loss", "label": "Supplier Return Loss", "field": "supplier_return_loss"},
]

static func dashboard(state: Dictionary, report: Dictionary) -> Dictionary:
	var net_sales: int = int(report.sales) - int(report.refunds)
	var gross_profit: int = net_sales - int(report.cogs)
	var net_profit: int = Simulation.net(report)
	var operating_cash_flow: int = Simulation.cash_change(report) - int(report.capital)
	var fixed_costs := known_fixed_costs(state)
	return {
		"cash": int(state.get("cash", 0)),
		"revenue": int(report.sales),
		"expenses": int(report.sales) - net_profit,
		"gross_profit": gross_profit,
		"net_profit": net_profit,
		"operating_cash_flow": operating_cash_flow,
		"receivables": 0,
		"payables": int(report.get("supplier_payables", 0)),
		"customer_deposits": int(report.get("customer_deposits", 0)),
		"overhead": fixed_costs,
		"known_fixed_costs": fixed_costs,
		"cash_forecast": int(state.get("cash", 0)) - fixed_costs,
		"cash_after_known_fixed_costs": int(state.get("cash", 0)) - fixed_costs,
	}

## Returns a statement for the selected calendar period, ending no later than
## the last completed simulation day. Day `state.day` is still being simulated.
static func completed_period_report(simulation: RefCounted, period: int, anchor: int) -> Dictionary:
	# Simulation owns the historical cut-off so finance, stores, sales and ads
	# share the same rule. Keep this wrapper for existing finance UI callers.
	return simulation.calendar_report_completed(period, anchor)

static func transaction_rows(state: Dictionary, first_day: int, last_day: int) -> Array[Dictionary]:
	## Cash movement grouped like a banking activity feed. Non-cash entries such
	## as COGS stay in Other and do not alter the accounting ledger.
	var result: Array[Dictionary] = []
	var first := maxi(1, first_day)
	var last := mini(int(state.get("day", 1)) - 1, last_day)
	for day in range(last, first - 1, -1):
		if day - 1 < 0 or day - 1 >= state.ledger.size():
			continue
		var row: Dictionary = state.ledger[day - 1]
		var incoming: Array[Dictionary] = []
		var outgoing: Array[Dictionary] = []
		var other: Array[Dictionary] = []
		var cash := cash_flow_lines(row)
		_add_transaction(incoming, "Customer receipts", int(cash.customer_receipts))
		_add_transaction(incoming, "Supplier refunds", int(cash.supplier_refunds))
		_add_transaction(incoming, "Owner investment", int(cash.owner_investment))
		var developer_adjustment := int(cash.developer_adjustment)
		if developer_adjustment > 0: _add_transaction(incoming, "Developer test adjustment", developer_adjustment)
		elif developer_adjustment < 0: _add_transaction(outgoing, "Developer test adjustment", developer_adjustment)
		_add_transaction(outgoing, "Customer refunds", int(cash.customer_refunds))
		_add_transaction(outgoing, "Warehouse goods", int(cash.warehouse_goods))
		_add_transaction(outgoing, "Supplier-direct goods", int(cash.supplier_direct_goods))
		_add_transaction(outgoing, "Inbound freight", int(cash.inbound_freight))
		_add_transaction(outgoing, "Supplier repayments", int(cash.supplier_repayments))
		_add_transaction(outgoing, "Outbound shipping", int(cash.outbound_shipping))
		_add_transaction(outgoing, "Advertising", int(cash.advertising))
		_add_transaction(outgoing, "Store setup", int(cash.store_setup))
		_add_transaction(outgoing, "Store operating costs", int(cash.store_expenses))
		_add_transaction(outgoing, "Other operating costs", int(cash.other_operating))
		_add_transaction(other, "Cost of goods sold", -int(row.cogs))
		_add_transaction(other, "Supplier credit inventory purchase", -int(row.get("credit_purchases", 0)))
		_add_transaction(other, "Credit-financed inbound freight", -int(row.get("credit_inbound_freight", 0)))
		_add_transaction(other, "Supplier credit return applied to payable", int(row.get("supplier_credit_adjustments", 0)))
		_add_transaction(other, "Inventory return adjustment", int(row.get("supplier_refunds", 0)) - int(row.get("inventory_returns", 0)))
		if not incoming.is_empty() or not outgoing.is_empty() or not other.is_empty():
			result.append({"day": day, "incoming": incoming, "outgoing": outgoing, "other": other,
				"cash_change": Simulation.cash_change(row), "net_profit": Simulation.net(row)})
	return result

static func _add_transaction(target: Array[Dictionary], label: String, amount: int) -> void:
	if amount != 0:
		target.append({"label": label, "amount": amount})

static func known_fixed_costs(state: Dictionary) -> int:
	var country := int(state.get("country", 0))
	var total := Catalog.local_cents(country, Catalog.OVERHEAD[clampi(int(state.get("difficulty", 0)), 0, Catalog.OVERHEAD.size() - 1)])
	var has_legacy_website := false
	for store in state.get("stores", []):
		if not store.get("active", false):
			continue
		if store.get("legacy", false):
			if int(store.get("type", -1)) == 1:
				has_legacy_website = true
			continue
		total += int(store.get("daily_cost", 0))
	if has_legacy_website:
		total += Catalog.local_cents(country, Catalog.HOSTING)
	return total

static func expense_categories(report: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in EXPENSE_FIELDS:
		var amount: int = int(report.get(item.field, 0))
		if item.id == "supplier_return_loss":
			amount = int(report.get("inventory_returns", 0)) - int(report.get("supplier_refunds", 0))
		if amount > 0:
			result.append({"id": item.id, "label": item.label, "amount": amount})
	return result

static func cash_flow_lines(report: Dictionary) -> Dictionary:
	var cash_purchases := int(report.get("purchases", 0)) - int(report.get("credit_purchases", 0))
	var cash_freight := int(report.get("inbound_freight", 0)) - int(report.get("credit_inbound_freight", 0))
	var direct_freight := int(report.get("direct_inbound_freight", 0))
	var lines := {
		"customer_receipts": int(report.get("sales", 0)) + int(report.get("deposits", 0)),
		"customer_refunds": -int(report.get("refunds", 0)),
		"warehouse_goods": -(cash_purchases - (cash_freight - direct_freight)),
		"supplier_direct_goods": -(int(report.get("direct_purchases", 0)) - direct_freight),
		"inbound_freight": -cash_freight,
		"supplier_repayments": -int(report.get("supplier_repayments", 0)),
		"supplier_refunds": int(report.get("supplier_refunds", 0)) - int(report.get("supplier_credit_adjustments", 0)),
		"outbound_shipping": -int(report.get("shipping", 0)),
		"advertising": -int(report.get("advertising", 0)),
		"store_setup": -int(report.get("store_setup", 0)),
		"store_expenses": -int(report.get("store_expenses", 0)),
		"other_operating": -int(report.get("fees", 0)) - int(report.get("overhead", 0)) - int(report.get("hosting", 0)) - int(report.get("legacy", 0)),
		"owner_investment": int(report.get("capital", 0)),
		"developer_adjustment": int(report.get("dev_cash_adjustment", 0)),
	}
	lines.total = 0
	for key in lines.keys():
		if key != "total": lines.total += int(lines[key])
	return lines

static func daily_totals(state: Dictionary, first_day: int, last_day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := maxi(1, first_day)
	var finish := mini(int(state.get("day", 1)) - 1, last_day)
	for day in range(start, finish + 1):
		if day - 1 < 0 or day - 1 >= state.ledger.size():
			continue
		var row: Dictionary = state.ledger[day - 1]
		var expenses: int = int(row.cogs) + int(row.refunds) + int(row.fees) + int(row.shipping) + int(row.overhead) + int(row.hosting) + int(row.legacy) + int(row.advertising) + int(row.store_setup) + int(row.store_expenses) + int(row.get("inventory_returns", 0)) - int(row.get("supplier_refunds", 0))
		result.append({"day": day, "sales": int(row.sales), "expenses": expenses, "net_profit": Simulation.net(row), "cash_change": Simulation.cash_change(row)})
	return result
