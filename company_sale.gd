extends RefCounted

## Company-level valuation and sale ledger operations. Monetary values are the
## simulation's minor units (the same units as `state.cash`), and every personal
## sale credit is retained in the currency of the sold company. No FX conversion
## is implied or required.

const Catalog = preload("res://catalog.gd")
const Simulation = preload("res://simulation.gd")
const CEOProfile = preload("res://ceo_profile.gd")
const Calendar = preload("res://game_calendar.gd")
const MIN_OPERATING_DAYS_FOR_EARNINGS_VALUE := 180
const FALLBACK_REVENUE_MULTIPLE := 0.10
const BASE_PROFIT_MULTIPLE := 2.5

static func preview(state: Dictionary) -> Dictionary:
	if state.is_empty() or str(state.get("company_id", "")).strip_edges().is_empty():
		return {"error": "Company identity is unavailable."}
	var operating_days := mini(365, maxi(0, int(state.get("day", 1)) - 1))
	var report_end := maxi(1, int(state.get("day", 1)) - 1)
	var report_days := maxi(1, operating_days)
	var sim := Simulation.new(state)
	var report: Dictionary = sim.report(report_days, report_end)
	var net_sales := int(report.get("sales", 0)) - int(report.get("refunds", 0))
	var annual_revenue := maxi(0, _annualize(net_sales, operating_days))
	var operating_profit := Simulation.net(report)
	var annual_operating_profit := _normalized_annual_profit(state.get("ledger", []), operating_days)
	var observed_annual_operating_profit := _annualize(operating_profit, operating_days)
	var growth := _revenue_growth(state, operating_days)
	var reputation := clampi(int(state.get("reputation", 70)), 0, 100)
	var satisfaction := clampi(int(state.get("satisfaction", 80)), 0, 100)
	var multiple := _profit_multiple(operating_days, growth, reputation, satisfaction,
		annual_operating_profit, int(state.get("cash", 0)), bool(state.get("bankrupt", false)))
	var enterprise_value := 0
	var valuation_method := "Asset and conservative revenue fallback"
	var tangible_assets := maxi(0, int(state.get("cash", 0))) + maxi(0, int(report.get("inventory", 0))) + maxi(0, int(report.get("goods_in_transit", 0)))
	var operating_liabilities := maxi(0, int(report.get("overdraft", 0))) + maxi(0, int(report.get("customer_deposits", 0)))
	var debt := _recorded_debt(state)
	var liabilities := operating_liabilities + debt
	var positive_company_cash := maxi(0, int(state.get("cash", 0)))
	# The current model has no separately recorded non-operating assets. Do not
	# infer an asset value from unrecognized fields or duplicate operating assets.
	var non_operating_assets := 0
	var used_fallback := operating_days < MIN_OPERATING_DAYS_FOR_EARNINGS_VALUE or annual_operating_profit <= 0
	if used_fallback:
		# In the fallback, enterprise value covers only a small revenue-derived
		# goodwill component. Cash, inventory, and supplier goods in transit are
		# then added once as verified tangible assets.
		enterprise_value = maxi(0, roundi(float(annual_revenue) * FALLBACK_REVENUE_MULTIPLE))
		valuation_method = "Verified net assets plus 10% of normalized annual sales"
	else:
		# Earnings-based enterprise value includes the going concern's operating
		# assets and working capital, including inventory. Inventory is therefore
		# displayed but not added again. Positive company cash is added separately.
		enterprise_value = maxi(0, roundi(float(annual_operating_profit) * multiple))
		valuation_method = "Normalized annual operating profit × adjusted multiple"
	var equity_value: int
	if used_fallback:
		equity_value = maxi(0, enterprise_value + tangible_assets + non_operating_assets - liabilities)
	else:
		equity_value = maxi(0, enterprise_value + positive_company_cash + non_operating_assets - liabilities)
	return {
		"error": "", "company_id": str(state.company_id), "company_name": str(state.get("company", "Company")),
		"currency": Catalog.CURRENCIES[int(state.get("country", 0))] if int(state.get("country", 0)) in range(Catalog.CURRENCIES.size()) else "",
		"country": int(state.get("country", 0)), "operating_days": operating_days,
		"annual_revenue": annual_revenue, "annual_operating_profit": annual_operating_profit,
		"period_sales": int(report.get("sales", 0)), "period_net_sales": net_sales,
		"period_operating_profit": operating_profit,
		"observed_annual_operating_profit": observed_annual_operating_profit,
		"revenue_growth": growth, "reputation": reputation, "customer_satisfaction": satisfaction,
		"multiple": multiple, "enterprise_value": enterprise_value, "equity_value": equity_value,
		"cash": int(state.get("cash", 0)), "positive_company_cash": positive_company_cash,
		"inventory_value": maxi(0, int(report.get("inventory", 0))),
		"goods_in_transit_value": maxi(0, int(report.get("goods_in_transit", 0))),
		"debt": debt, "overdraft": maxi(0, int(report.get("overdraft", 0))),
		"customer_deposits": maxi(0, int(report.get("customer_deposits", 0))),
		"liabilities": liabilities, "non_operating_assets": non_operating_assets,
		"used_fallback": used_fallback, "method": valuation_method,
		"factors": {"history_days": operating_days, "growth": growth,
			"reputation": reputation, "customer_satisfaction": satisfaction,
			"bankrupt": bool(state.get("bankrupt", false)), "negative_cash": int(state.get("cash", 0)) < 0},
	}

static func _annualize(amount: int, days: int) -> int:
	if days <= 0: return 0
	return roundi(float(amount) * 365.0 / float(days))

static func _normalized_annual_profit(ledger: Array, operating_days: int) -> int:
	if operating_days <= 0: return 0
	var daily_profit: Array[float] = []
	for day in range(1, mini(operating_days, ledger.size()) + 1):
		var row: Variant = ledger[day - 1]
		if row is Dictionary: daily_profit.append(float(Simulation.net(row)))
	if daily_profit.is_empty(): return 0
	var ordered := daily_profit.duplicate()
	ordered.sort()
	var median := _median(ordered)
	var deviations: Array[float] = []
	for amount in ordered: deviations.append(absf(amount - median))
	deviations.sort()
	var mad := _median(deviations)
	# A zero-MAD history is stable in its majority. Winsorize any exceptional
	# day to the median rather than allowing one isolated spike to set earnings.
	var cap := 3.0 * mad
	var normalized_total := 0.0
	for amount in daily_profit:
		normalized_total += clampf(amount, median - cap, median + cap)
	return roundi(normalized_total * 365.0 / float(daily_profit.size()))

static func _median(ordered: Array[float]) -> float:
	if ordered.is_empty(): return 0.0
	var middle := ordered.size() / 2
	if ordered.size() % 2 == 1: return ordered[middle]
	return (ordered[middle - 1] + ordered[middle]) / 2.0

static func _profit_multiple(days: int, growth: float, reputation: int, satisfaction: int,
		profit: int, cash: int, bankrupt: bool) -> float:
	var stability := 0.5 * minf(1.0, float(days) / 365.0)
	var growth_adjustment := clampf(growth * 0.25, -0.5, 0.5)
	var reputation_adjustment := (float(reputation) - 50.0) / 100.0
	var satisfaction_adjustment := (float(satisfaction) - 50.0) / 100.0
	var risk_adjustment := -0.75 if bankrupt else 0.0
	if cash < 0: risk_adjustment -= 0.5
	if profit < 0: risk_adjustment -= 0.5
	return clampf(BASE_PROFIT_MULTIPLE + stability + growth_adjustment + reputation_adjustment + satisfaction_adjustment + risk_adjustment, 0.5, 5.0)

static func _revenue_growth(state: Dictionary, operating_days: int) -> float:
	if operating_days < 180: return 0.0
	var ledger: Array = state.get("ledger", [])
	# Endpoints are inclusive: 91–180 and 1–90 are exactly 90 days apiece.
	var latest := _sales_between(ledger, operating_days - 89, operating_days)
	var previous := _sales_between(ledger, operating_days - 179, operating_days - 90)
	if previous <= 0: return 0.0
	return clampf(float(latest - previous) / float(previous), -1.0, 2.0)

static func _sales_between(ledger: Array, start_day: int, end_day: int) -> int:
	var result := 0
	for day in range(maxi(1, start_day), mini(end_day, ledger.size()) + 1):
		var row: Variant = ledger[day - 1]
		if row is Dictionary: result += maxi(0, int(row.get("sales", 0)) - int(row.get("refunds", 0)))
	return result

static func _recorded_debt(state: Dictionary) -> int:
	# No borrowing model currently creates debt. This reads a future or imported
	# explicit debt balance when present without deriving debt from cash forecasts.
	var debt: Variant = state.get("debt", 0)
	return maxi(0, int(debt)) if debt is int else 0

static func sell(profile: Dictionary, state: Dictionary) -> Dictionary:
	var value := preview(state)
	if not str(value.get("error", "")).is_empty(): return {"error": str(value.error)}
	var updated := CEOProfile.ensure(profile, str(state.get("owner", "")))
	var company_id := str(state.get("company_id", ""))
	var company_index := CEOProfile.company_index(updated, company_id)
	if company_index < 0:
		updated = CEOProfile.register_company(updated, state)
		company_index = CEOProfile.company_index(updated, company_id)
	if company_index < 0: return {"error": "This company is not in the CEO portfolio."}
	var company: Dictionary = updated.companies[company_index]
	if str(company.get("ownership_status", "owned")) != "owned":
		return {"error": "This company has already been sold or is no longer owned."}
	var record_id := "company_sale:%s" % company_id
	for transaction in updated.personal_finance_ledger:
		if str(transaction.get("record_id", "")) == record_id:
			return {"error": "A sale transaction for this company is already recorded."}
	var record := {
		"record_id": record_id, "type": "company_sale", "company_id": company_id,
		"company_name": str(state.get("company", "Company")), "day": int(state.get("day", 1)),
		"date": Calendar.format(int(state.get("day", 1))),
		"amount": int(value.equity_value), "currency": str(value.currency),
		"country": int(value.country), "valuation": value.duplicate(true),
	}
	company.ownership_status = "sold"
	company.sale_record = record.duplicate(true)
	updated.companies[company_index] = company
	updated.personal_finance_ledger.append(record)
	# Leave personal_cash and personal_net_worth as null: this ledger records
	# only known sale proceeds and does not invent a historical starting balance.
	if not CEOProfile.valid(updated): return {"error": "The sale could not be recorded in a valid CEO profile."}
	return {"error": "", "profile": updated, "record": record, "valuation": value}

static func known_sale_proceeds_by_currency(profile: Dictionary) -> Dictionary:
	var totals := {}
	for transaction in profile.get("personal_finance_ledger", []):
		if transaction is Dictionary and transaction.get("type", "") == "company_sale":
			var currency := str(transaction.get("currency", ""))
			if not currency.is_empty(): totals[currency] = int(totals.get(currency, 0)) + int(transaction.get("amount", 0))
	return totals
