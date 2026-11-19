extends RefCounted

const Catalog = preload("res://catalog.gd")
const Simulation = preload("res://simulation.gd")

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
		"payables": 0,
		"customer_deposits": int(report.get("customer_deposits", 0)),
		"known_fixed_costs": fixed_costs,
		"cash_after_known_fixed_costs": int(state.get("cash", 0)) - fixed_costs,
	}

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
