extends RefCounted

## Supplier credit is a conservative, interest-free trade-payables facility.
## Policy: 5 fully settled supplier purchases and trust >= 40; trust gains 8
## points per upfront trade, 6 per timely payment, and loses 20 for each
## overdue obligation. Terms are 7 game days, with no late fee. The line is
## min(15% positive equity, 25% trailing-30-day net sales, USD 500 cap) × trust.

const Catalog = preload("res://catalog.gd")
const Calendar = preload("res://game_calendar.gd")
const SCHEMA_VERSION := 1
const TRUST_THRESHOLD := 40
const SETTLED_PURCHASE_THRESHOLD := 5
const PAYMENT_TERM_DAYS := 7
const LATE_TRUST_PENALTY := 20
const UPFRONT_TRUST_GAIN := 8
const TIMELY_PAYMENT_TRUST_GAIN := 6
const CREDIT_CAP_USD := 500.0

static func _empty_state() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "relationships": {}, "obligations": [], "payments": [], "adjustments": [],
		"events": [], "next_obligation_id": 1, "next_payment_id": 1, "next_adjustment_id": 1}

static func ensure(state: Dictionary) -> void:
	var credit: Variant = state.get("supplier_credit", null)
	if not credit is Dictionary:
		credit = _empty_state()
	else:
		credit = credit.duplicate(true)
	if int(credit.get("schema_version", 0)) != SCHEMA_VERSION:
		credit = _empty_state()
	if not credit.get("relationships") is Dictionary: credit.relationships = {}
	if not credit.get("obligations") is Array: credit.obligations = []
	if not credit.get("payments") is Array: credit.payments = []
	if not credit.get("adjustments") is Array: credit.adjustments = []
	if not credit.get("events") is Array: credit.events = []
	if not credit.get("next_obligation_id") is int or int(credit.next_obligation_id) < 1:
		credit.next_obligation_id = _next_id(credit.obligations, "id")
	if not credit.get("next_payment_id") is int or int(credit.next_payment_id) < 1:
		credit.next_payment_id = _next_id(credit.payments, "id")
	if not credit.get("next_adjustment_id") is int or int(credit.next_adjustment_id) < 1:
		credit.next_adjustment_id = _next_id(credit.adjustments, "id")
	for supplier_id in credit.relationships:
		var relationship: Dictionary = credit.relationships[supplier_id] if credit.relationships[supplier_id] is Dictionary else {}
		credit.relationships[supplier_id] = _normalize_relationship(relationship)
	state.supplier_credit = credit

static func _normalize_relationship(raw: Dictionary) -> Dictionary:
	return {"trust": clampi(int(raw.get("trust", 0)), 0, 100),
		"trade_count": maxi(0, int(raw.get("trade_count", 0))),
		"settled_purchase_count": maxi(0, int(raw.get("settled_purchase_count", 0))),
		"timely_repayments": maxi(0, int(raw.get("timely_repayments", 0))),
		"late_repayments": maxi(0, int(raw.get("late_repayments", 0))),
		"overdue_count": maxi(0, int(raw.get("overdue_count", 0))),
		"processed_trade_ids": raw.get("processed_trade_ids", []) if raw.get("processed_trade_ids", []) is Array else []}

static func _next_id(records: Array, field: String) -> int:
	var maximum := 0
	for record in records:
		if record is Dictionary: maximum = maxi(maximum, int(record.get(field, 0)))
	return maximum + 1

static func relationship(state: Dictionary, supplier: int) -> Dictionary:
	ensure(state)
	if supplier not in range(Catalog.SUPPLIERS.size()): return _normalize_relationship({})
	var key := Catalog.supplier_id(supplier)
	var credit: Dictionary = state.supplier_credit
	if not credit.relationships.has(key): credit.relationships[key] = _normalize_relationship({})
	state.supplier_credit = credit
	return credit.relationships[key].duplicate(true)

static func open_payables(state: Dictionary, supplier: int = -1, end_day: int = 0) -> int:
	ensure(state)
	var total := 0
	var cutoff := int(end_day) if end_day > 0 else int(state.get("day", 1))
	for obligation in state.supplier_credit.obligations:
		if not obligation is Dictionary: continue
		if supplier >= 0 and int(obligation.get("supplier", -1)) != supplier: continue
		if int(obligation.get("purchase_day", 0)) > cutoff: continue
		var balance := int(obligation.get("principal", 0))
		for payment in state.supplier_credit.payments:
			if int(payment.get("obligation_id", -1)) == int(obligation.get("id", -2)) and int(payment.get("day", 0)) <= cutoff:
				balance -= int(payment.get("amount", 0))
		for adjustment in state.supplier_credit.adjustments:
			if int(adjustment.get("obligation_id", -1)) == int(obligation.get("id", -2)) and int(adjustment.get("day", 0)) <= cutoff:
				balance -= int(adjustment.get("amount", 0))
		total += maxi(0, balance)
	return total

static func supplier_payables(state: Dictionary, supplier: int) -> Array[Dictionary]:
	ensure(state)
	var result: Array[Dictionary] = []
	for obligation in state.supplier_credit.obligations:
		if obligation is Dictionary and int(obligation.get("supplier", -1)) == supplier and int(obligation.get("balance", 0)) > 0:
			result.append(obligation.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.due_day) < int(b.due_day))
	return result

static func _has_overdue(state: Dictionary, supplier: int) -> bool:
	for obligation in supplier_payables(state, supplier):
		if int(state.day) > int(obligation.due_day): return true
	return false

static func supplier_credit_limit(state: Dictionary, supplier: int) -> int:
	ensure(state)
	if supplier not in range(Catalog.SUPPLIERS.size()) or not Catalog.supplier_available_for_sourcing(supplier): return 0
	var relation := relationship(state, supplier)
	if int(relation.trust) < TRUST_THRESHOLD or int(relation.settled_purchase_count) < SETTLED_PURCHASE_THRESHOLD:
		return 0
	if _has_overdue(state, supplier) or int(state.get("cash", 0)) <= 0: return 0
	var financials := _company_condition(state)
	if int(financials.equity) <= 0 or int(financials.net_sales_30d) <= 0: return 0
	var equity_cap := floori(float(financials.equity) * 0.15)
	var sales_cap := floori(float(financials.net_sales_30d) * 0.25)
	var usd_cap := Catalog.local_cents(int(state.get("country", 0)), CREDIT_CAP_USD)
	var conservative_base := mini(equity_cap, mini(sales_cap, usd_cap))
	return floori(float(conservative_base) * int(relation.trust) / 100.0)

static func credit_available(state: Dictionary, supplier: int) -> int:
	return maxi(0, supplier_credit_limit(state, supplier) - open_payables(state, supplier))

static func eligibility(state: Dictionary, supplier: int) -> Dictionary:
	ensure(state)
	var relation := relationship(state, supplier)
	var limit := supplier_credit_limit(state, supplier)
	var reason := ""
	if supplier not in range(Catalog.SUPPLIERS.size()) or not Catalog.supplier_available_for_sourcing(supplier):
		reason = "This supplier cannot offer new purchases."
	elif int(relation.trust) < TRUST_THRESHOLD:
		reason = "Build trust to at least %d through successful purchases and repayments." % TRUST_THRESHOLD
	elif int(relation.settled_purchase_count) < SETTLED_PURCHASE_THRESHOLD:
		reason = "%d more settled supplier purchases are needed." % (SETTLED_PURCHASE_THRESHOLD - int(relation.settled_purchase_count))
	elif _has_overdue(state, supplier):
		reason = "Settle overdue amounts before using supplier credit again."
	elif int(state.get("cash", 0)) <= 0:
		reason = "Positive company cash is required for credit eligibility."
	elif int(_company_condition(state).equity) <= 0:
		reason = "Positive company equity is required for credit eligibility."
	elif int(_company_condition(state).net_sales_30d) <= 0:
		reason = "Recent company sales are required for credit eligibility."
	elif credit_available(state, supplier) <= 0:
		reason = "No credit headroom is currently available."
	return {"eligible": reason.is_empty(), "reason": reason, "trust": int(relation.trust),
		"settled_purchases": int(relation.settled_purchase_count), "credit_limit": limit,
		"outstanding": open_payables(state, supplier), "available": credit_available(state, supplier),
		"term_days": PAYMENT_TERM_DAYS, "due_day": int(state.get("day", 1)) + PAYMENT_TERM_DAYS}

static func _company_condition(state: Dictionary) -> Dictionary:
	var inventory := 0
	var transit := 0
	var deposits := 0
	var recent_sales := 0
	var recent_refunds := 0
	var end_day := int(state.get("day", 1))
	for index in range(state.get("ledger", []).size()):
		var row: Dictionary = state.ledger[index]
		inventory += int(row.get("purchases", 0)) - (int(row.get("cogs", 0)) - int(row.get("direct_cogs", 0))) - int(row.get("inventory_returns", 0))
		transit += int(row.get("direct_purchases", 0)) - int(row.get("direct_cogs", 0))
		deposits += int(row.get("deposits", 0))
		var row_day := index + 1
		if row_day >= end_day - 29:
			recent_sales += int(row.get("sales", 0))
			recent_refunds += int(row.get("refunds", 0))
	var cash := int(state.get("cash", 0))
	var overdraft := maxi(0, -cash)
	var assets := maxi(0, cash) + maxi(0, inventory) + maxi(0, transit)
	var liabilities := overdraft + deposits + open_payables(state)
	return {"assets": assets, "liabilities": liabilities, "equity": assets - liabilities,
		"net_sales_30d": maxi(0, recent_sales - recent_refunds)}

static func record_upfront_purchase(state: Dictionary, supplier: int, purchase_id: int) -> void:
	ensure(state)
	if supplier not in range(Catalog.SUPPLIERS.size()) or purchase_id < 1: return
	var key := Catalog.supplier_id(supplier)
	var relation := relationship(state, supplier)
	var trade_key := "cash:%d" % purchase_id
	if trade_key in relation.processed_trade_ids: return
	relation.processed_trade_ids.append(trade_key)
	relation.trade_count += 1
	relation.settled_purchase_count += 1
	relation.trust = mini(100, int(relation.trust) + UPFRONT_TRUST_GAIN)
	_save_relationship(state, key, relation)
	_add_event(state, {"type": "upfront_purchase", "day": int(state.day), "supplier": supplier, "purchase_id": purchase_id,
		"trust_delta": UPFRONT_TRUST_GAIN})

static func _save_relationship(state: Dictionary, supplier_id: String, relation: Dictionary) -> void:
	var credit: Dictionary = state.supplier_credit
	credit.relationships[supplier_id] = relation
	state.supplier_credit = credit

static func _add_event(state: Dictionary, event: Dictionary) -> void:
	var credit: Dictionary = state.supplier_credit
	credit.events.append(event)
	state.supplier_credit = credit

static func purchase_on_credit(state: Dictionary, product: int, supplier: int, units: int) -> Dictionary:
	ensure(state)
	var Supply = load("res://supply.gd")
	var terms: Dictionary = Supply.purchase_breakdown(state, product, supplier, units)
	if not str(terms.get("error", "")).is_empty(): return {"error": str(terms.error)}
	var condition := eligibility(state, supplier)
	if not condition.eligible: return {"error": str(condition.reason), "terms": condition}
	var total := int(terms.total)
	if total > int(condition.available):
		return {"error": "This order exceeds the supplier credit limit by %s." % _money_text(total - int(condition.available)), "terms": condition}
	var order: Dictionary = Supply.purchase_order(state, product, supplier, units, total)
	if not str(order.get("error", "")).is_empty(): return order
	var credit: Dictionary = state.supplier_credit
	var id := int(credit.next_obligation_id)
	credit.next_obligation_id = id + 1
	var due_day := int(state.day) + PAYMENT_TERM_DAYS
	credit.obligations.append({"id": id, "supplier": supplier, "supplier_id": Catalog.supplier_id(supplier),
		"supplier_name": Catalog.SUPPLIERS[supplier].name, "purchase_id": int(order.purchase_id),
		"product": product, "product_id": Catalog.product_id(product), "units": units,
		"principal": total, "balance": total, "purchase_day": int(state.day), "due_day": due_day,
		"purchase_date": Calendar.format(int(state.day)), "due_date": Calendar.format(due_day),
		"status": "open", "late_event_recorded": false})
	state.supplier_credit = credit
	var relation := relationship(state, supplier)
	var trade_key := "credit:%d" % int(order.purchase_id)
	if trade_key not in relation.processed_trade_ids:
		relation.processed_trade_ids.append(trade_key)
		relation.trade_count += 1
		_save_relationship(state, Catalog.supplier_id(supplier), relation)
	_add_event(state, {"type": "credit_purchase", "day": int(state.day), "supplier": supplier,
		"obligation_id": id, "purchase_id": int(order.purchase_id), "trust_delta": 0})
	return {"error": "", "obligation": credit.obligations.back().duplicate(true), "terms": condition, "purchase": order}

static func repay(state: Dictionary, obligation_id: int, amount: int, request_id: String = "") -> Dictionary:
	ensure(state)
	# Reconcile missed due dates before accepting any repayment, including when
	# a game is resumed directly on a date past the obligation's due day.
	process_due(state)
	if amount <= 0: return {"error": "Enter a repayment amount above zero."}
	if request_id.is_empty(): request_id = "repayment-%d" % int(state.supplier_credit.next_payment_id)
	for existing in state.supplier_credit.payments:
		if str(existing.get("request_id", "")) == request_id:
			return {"error": "This repayment has already been recorded.", "duplicate": true}
	var obligation_index := -1
	for index in state.supplier_credit.obligations.size():
		if int(state.supplier_credit.obligations[index].get("id", -1)) == obligation_id:
			obligation_index = index
			break
	if obligation_index < 0: return {"error": "Supplier payable not found."}
	var credit: Dictionary = state.supplier_credit
	var obligation: Dictionary = credit.obligations[obligation_index]
	var balance := int(obligation.get("balance", 0))
	if balance <= 0: return {"error": "This supplier payable is already settled."}
	if amount > balance: return {"error": "Repayment exceeds the remaining payable balance."}
	if amount > int(state.get("cash", 0)): return {"error": "Insufficient company cash for this repayment."}
	var day := int(state.day)
	var timely := day <= int(obligation.due_day)
	var next_balance := balance - amount
	var payment_id := int(credit.next_payment_id)
	credit.next_payment_id = payment_id + 1
	state.cash -= amount
	state.ledger.back().supplier_repayments += amount
	obligation.balance = next_balance
	obligation.status = "paid" if next_balance == 0 else ("overdue" if day > int(obligation.due_day) else "partial")
	credit.obligations[obligation_index] = obligation
	credit.payments.append({"id": payment_id, "request_id": request_id, "obligation_id": obligation_id,
		"supplier": int(obligation.supplier), "amount": amount, "day": day, "date": Calendar.format(day),
		"balance_after": next_balance, "timely": timely})
	state.supplier_credit = credit
	var relation := relationship(state, int(obligation.supplier))
	var trust_delta := 0
	if next_balance == 0:
		relation.settled_purchase_count += 1
		if timely:
			relation.timely_repayments += 1
			relation.trust = mini(100, int(relation.trust) + TIMELY_PAYMENT_TRUST_GAIN)
			trust_delta = TIMELY_PAYMENT_TRUST_GAIN
		else:
			relation.late_repayments += 1
			# Missing the due date already reduced trust in process_due(). A late
			# settlement restores the account but never awards trust for lateness.
	_save_relationship(state, str(obligation.supplier_id), relation)
	_add_event(state, {"type": "repayment", "day": day, "supplier": int(obligation.supplier),
		"obligation_id": obligation_id, "payment_id": payment_id, "trust_delta": trust_delta})
	return {"error": "", "payment_id": payment_id, "balance": next_balance, "status": str(obligation.status), "timely": timely}

## Supplier refunds from credit-financed lots first reduce that purchase's
## outstanding payable. Any refund beyond that balance remains a cash refund.
## return_id makes a repeated adjustment idempotent.
static func record_return_adjustment(state: Dictionary, supplier: int, product: int,
		purchase_id: int, refund_amount: int, return_id: int) -> Dictionary:
	ensure(state)
	if supplier not in range(Catalog.SUPPLIERS.size()) or product not in range(Catalog.PRODUCTS.size()) \
		or purchase_id < 1 or refund_amount < 0 or return_id < 1:
		return {"error": "Invalid supplier return adjustment.", "applied": 0}
	var obligation_index := -1
	for index in state.supplier_credit.obligations.size():
		var candidate: Dictionary = state.supplier_credit.obligations[index]
		if int(candidate.get("purchase_id", -1)) == purchase_id and int(candidate.get("supplier", -1)) == supplier \
			and int(candidate.get("product", -1)) == product:
			obligation_index = index
			break
	if obligation_index < 0:
		return {"error": "", "applied": 0}
	var credit: Dictionary = state.supplier_credit
	var obligation: Dictionary = credit.obligations[obligation_index]
	for existing in credit.adjustments:
		if int(existing.get("return_id", -1)) == return_id and int(existing.get("obligation_id", -1)) == int(obligation.id):
			return {"error": "", "duplicate": true,
				"applied": int(existing.get("amount", 0)), "adjustment_id": int(existing.get("id", 0))}
	var current_balance := int(obligation.get("balance", 0))
	var applied := mini(maxi(0, refund_amount), current_balance)
	if applied <= 0:
		return {"error": "", "applied": 0}
	var adjustment_id := int(credit.next_adjustment_id)
	credit.next_adjustment_id = adjustment_id + 1
	var next_balance := current_balance - applied
	obligation.balance = next_balance
	obligation.status = "adjusted" if next_balance == 0 else ("overdue" if bool(obligation.get("late_event_recorded", false)) else "partial")
	credit.obligations[obligation_index] = obligation
	credit.adjustments.append({"id": adjustment_id, "return_id": return_id, "obligation_id": int(obligation.id),
		"supplier": supplier, "product": product, "purchase_id": purchase_id, "amount": applied,
		"day": int(state.day), "date": Calendar.format(int(state.day)), "balance_after": next_balance})
	state.supplier_credit = credit
	_add_event(state, {"type": "return_adjustment", "day": int(state.day), "supplier": supplier,
		"obligation_id": int(obligation.id), "return_id": return_id, "adjustment_id": adjustment_id, "trust_delta": 0})
	return {"error": "", "applied": applied, "balance": next_balance, "adjustment_id": adjustment_id}

static func process_due(state: Dictionary) -> void:
	ensure(state)
	var credit: Dictionary = state.supplier_credit
	for index in credit.obligations.size():
		var obligation: Dictionary = credit.obligations[index]
		if int(obligation.get("balance", 0)) <= 0 or int(state.day) <= int(obligation.get("due_day", 0)):
			continue
		if bool(obligation.get("late_event_recorded", false)):
			continue
		obligation.status = "overdue"
		obligation.late_event_recorded = true
		credit.obligations[index] = obligation
		var relation := relationship(state, int(obligation.supplier))
		relation.trust = maxi(0, int(relation.trust) - LATE_TRUST_PENALTY)
		relation.overdue_count += 1
		_save_relationship(state, str(obligation.supplier_id), relation)
		_add_event(state, {"type": "late", "day": int(state.day), "supplier": int(obligation.supplier),
			"obligation_id": int(obligation.id), "trust_delta": -LATE_TRUST_PENALTY})
	credit = state.supplier_credit
	state.supplier_credit = credit

static func validate(state: Dictionary) -> bool:
	if not state.get("supplier_credit") is Dictionary: return false
	var credit: Dictionary = state.supplier_credit
	if int(credit.get("schema_version", 0)) != SCHEMA_VERSION or not credit.get("relationships") is Dictionary \
		or not credit.get("obligations") is Array or not credit.get("payments") is Array \
		or not credit.get("adjustments") is Array or not credit.get("events") is Array:
		return false
	if not credit.get("next_obligation_id") is int or not credit.get("next_payment_id") is int or not credit.get("next_adjustment_id") is int: return false
	var obligation_ids := {}
	var max_obligation := 0
	var obligation_total := 0
	for obligation in credit.obligations:
		if not obligation is Dictionary: return false
		for field in ["id", "supplier", "purchase_id", "product", "units", "principal", "balance", "purchase_day", "due_day"]:
			if not obligation.get(field) is int: return false
		if int(obligation.id) < 1 or int(obligation.supplier) not in range(Catalog.SUPPLIERS.size()) or int(obligation.product) not in range(Catalog.PRODUCTS.size()): return false
		if int(obligation.purchase_id) < 1 or int(obligation.purchase_id) >= int(state.get("next_purchase", 1)): return false
		if int(obligation.units) < 1 or int(obligation.principal) < 1 or int(obligation.balance) < 0 or int(obligation.balance) > int(obligation.principal): return false
		if int(obligation.purchase_day) < 1 or int(obligation.purchase_day) > int(state.get("day", 1)) or int(obligation.due_day) < int(obligation.purchase_day) or not obligation.get("status") is String: return false
		if str(obligation.get("supplier_id", "")) != Catalog.supplier_id(int(obligation.supplier)) or str(obligation.get("product_id", "")) != Catalog.product_id(int(obligation.product)): return false
		if str(obligation.get("status", "")) not in ["open", "partial", "overdue", "paid", "adjusted"] or not obligation.get("late_event_recorded") is bool: return false
		if not obligation.get("supplier_name") is String or not obligation.get("purchase_date") is String or not obligation.get("due_date") is String: return false
		if obligation_ids.has(int(obligation.id)): return false
		obligation_ids[int(obligation.id)] = true
		max_obligation = maxi(max_obligation, int(obligation.id))
		obligation_total += int(obligation.principal)
	if int(credit.next_obligation_id) <= max_obligation: return false
	var payment_ids := {}
	var payment_requests := {}
	var max_payment := 0
	var repayment_total := 0
	var repaid_by_obligation := {}
	var repaid_by_day := {}
	for payment in credit.payments:
		if not payment is Dictionary or not payment.get("id") is int or not payment.get("obligation_id") is int or not payment.get("amount") is int or not payment.get("day") is int:
			return false
		if not obligation_ids.has(int(payment.obligation_id)) or int(payment.amount) < 1 or int(payment.day) < 1 or int(payment.day) > int(state.get("day", 1)): return false
		if not payment.get("supplier") is int or not payment.get("date") is String or not payment.get("timely") is bool or not payment.get("balance_after") is int: return false
		if payment_ids.has(int(payment.id)) or payment_requests.has(str(payment.get("request_id", ""))): return false
		if str(payment.get("request_id", "")).is_empty(): return false
		if int(payment.id) < 1 or int(payment.balance_after) < 0 or int(payment.supplier) not in range(Catalog.SUPPLIERS.size()): return false
		var obligation_for_payment: Dictionary = {}
		for candidate in credit.obligations:
			if int(candidate.get("id", -1)) == int(payment.obligation_id):
				obligation_for_payment = candidate
				break
		if obligation_for_payment.is_empty() or int(payment.supplier) != int(obligation_for_payment.supplier): return false
		if bool(payment.timely) != (int(payment.day) <= int(obligation_for_payment.due_day)): return false
		payment_ids[int(payment.id)] = true
		payment_requests[str(payment.request_id)] = true
		max_payment = maxi(max_payment, int(payment.id))
		repayment_total += int(payment.amount)
		repaid_by_obligation[int(payment.obligation_id)] = int(repaid_by_obligation.get(int(payment.obligation_id), 0)) + int(payment.amount)
		repaid_by_day[int(payment.day)] = int(repaid_by_day.get(int(payment.day), 0)) + int(payment.amount)
	if int(credit.next_payment_id) <= max_payment: return false
	var adjustment_ids := {}
	var return_adjustments := {}
	var max_adjustment := 0
	var adjustment_total := 0
	var adjusted_by_obligation := {}
	var adjustment_by_day := {}
	for adjustment in credit.adjustments:
		if not adjustment is Dictionary: return false
		for field in ["id", "return_id", "obligation_id", "supplier", "product", "purchase_id", "amount", "day", "balance_after"]:
			if not adjustment.get(field) is int: return false
		if int(adjustment.id) < 1 or int(adjustment.return_id) < 1 or not obligation_ids.has(int(adjustment.obligation_id)) \
			or int(adjustment.amount) < 1 or int(adjustment.day) < 1 or int(adjustment.day) > int(state.get("day", 1)) \
			or not adjustment.get("date") is String or int(adjustment.balance_after) < 0:
			return false
		var matching_obligation: Dictionary = {}
		for candidate in credit.obligations:
			if int(candidate.get("id", -1)) == int(adjustment.obligation_id):
				matching_obligation = candidate
				break
		if matching_obligation.is_empty() or int(adjustment.supplier) != int(matching_obligation.supplier) \
			or int(adjustment.product) != int(matching_obligation.product) or int(adjustment.purchase_id) != int(matching_obligation.purchase_id):
			return false
		var return_key := "%d:%d" % [int(adjustment.return_id), int(adjustment.obligation_id)]
		if adjustment_ids.has(int(adjustment.id)) or return_adjustments.has(return_key): return false
		adjustment_ids[int(adjustment.id)] = true
		return_adjustments[return_key] = true
		max_adjustment = maxi(max_adjustment, int(adjustment.id))
		adjustment_total += int(adjustment.amount)
		adjusted_by_obligation[int(adjustment.obligation_id)] = int(adjusted_by_obligation.get(int(adjustment.obligation_id), 0)) + int(adjustment.amount)
		adjustment_by_day[int(adjustment.day)] = int(adjustment_by_day.get(int(adjustment.day), 0)) + int(adjustment.amount)
	if int(credit.next_adjustment_id) <= max_adjustment: return false
	var credit_ledger_total := 0
	var ledger_repayments := 0
	var ledger_adjustments := 0
	for index in state.get("ledger", []).size():
		var row: Dictionary = state.ledger[index]
		var row_credit := int(row.get("credit_purchases", 0))
		var row_repayments := int(row.get("supplier_repayments", 0))
		var row_adjustments := int(row.get("supplier_credit_adjustments", 0))
		if row_credit < 0 or row_credit > int(row.get("purchases", 0)) or row_repayments < 0 or row_adjustments < 0: return false
		credit_ledger_total += row_credit
		ledger_repayments += row_repayments
		ledger_adjustments += row_adjustments
		if row_repayments != int(repaid_by_day.get(index + 1, 0)): return false
		if row_adjustments != int(adjustment_by_day.get(index + 1, 0)): return false
	if credit_ledger_total != obligation_total or ledger_repayments != repayment_total or ledger_adjustments != adjustment_total: return false
	for obligation in credit.obligations:
		var settled_amount := int(repaid_by_obligation.get(int(obligation.id), 0)) + int(adjusted_by_obligation.get(int(obligation.id), 0))
		if settled_amount != int(obligation.principal) - int(obligation.balance): return false
	for supplier_id in credit.relationships:
		var relation: Variant = credit.relationships[supplier_id]
		if not relation is Dictionary or str(supplier_id).is_empty() or Catalog.supplier_index(str(supplier_id)) < 0: return false
		if int(relation.get("trust", -1)) not in range(101) or int(relation.get("trade_count", -1)) < 0 or int(relation.get("settled_purchase_count", -1)) < 0: return false
		if not relation.get("processed_trade_ids") is Array: return false
	return true

static func _money_text(amount: int) -> String:
	return "%d.%02d" % [amount / 100, amount % 100]
