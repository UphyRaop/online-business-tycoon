extends RefCounted

const Stores = preload("res://store_manager.gd")
const Advertising = preload("res://advertising.gd")
const RETURN_WINDOW := 14

static func rate(state: Dictionary, satisfaction: int, reputation: int) -> void:
	state.satisfaction = clampi(state.satisfaction + satisfaction, 0, 100)
	state.reputation = clampi(state.reputation + reputation, 0, 100)

static func on_delivery(state: Dictionary, order: Dictionary, rng: RandomNumberGenerator) -> void:
	var late: bool = order.delivered > order.promise
	var quality := 0.0
	for line in order.items:
		quality += line.quality
	quality /= order.items.size()
	rate(state, -3 if late else 1, -2 if late else 1)
	var defect := rng.randf() < clampf(0.035 + (1.0 - quality) * 0.32, 0.015, 0.16)
	var return_request := defect or rng.randf() < 0.035
	if not return_request and not late:
		return
	order.case_status = "open"
	order.case_day = state.day
	order.reason = "Defective item" if defect else ("Change of mind" if return_request else "Late delivery")
	order.return_requested = return_request
	order.restockable = not defect
	state.open_cases.append(order.id)
	rate(state, -3, -1)

static func tick(state: Dictionary) -> void:
	for id in state.open_cases:
		var order: Dictionary = state.orders[id]
		if not order.escalated and state.day - order.case_day >= 5:
			order.escalated = true
			rate(state, -4, -3)

static func respond(state: Dictionary, id: int) -> String:
	var order: Dictionary = state.orders.get(id, {})
	if order.get("case_status") != "open" or order.return_requested:
		return "This case requires a return decision or has already closed."
	close_case(state, order, "resolved")
	rate(state, 3, 2)
	return ""

static func reject_return(state: Dictionary, id: int) -> String:
	var order: Dictionary = state.orders.get(id, {})
	if order.get("case_status") != "open" or not order.return_requested:
		return "No pending return request."
	close_case(state, order, "declined")
	rate(state, -4, -3)
	return ""

static func can_refund(state: Dictionary, order: Dictionary) -> bool:
	return order.get("status") == "delivered" and not order.refunded and (
		order.case_status == "open" or state.day - order.delivered <= RETURN_WINDOW)

static func refund(sim: RefCounted, id: int) -> String:
	var state: Dictionary = sim.state
	var order: Dictionary = state.orders.get(id, {})
	if not can_refund(state, order):
		return "This order is outside its refund window or has already been refunded."
	var row: Dictionary = state.ledger.back()
	var channel: Dictionary = row.channels[order.channel]
	row.refunds += order.total
	channel.refunds += order.total
	var activity := Stores.store_activity(row, int(order.get("store_id", order.channel)))
	activity.refunds += order.total
	channel.refunded += 1
	state.cash -= order.total
	var reversed_cost := 0
	if order.restockable:
		for item in order.items:
			if item.has("direct_supplier"):
				continue
			reversed_cost += item.cost
			sim.add_stock(item.product, {"units": 1, "cost": item.cost, "quality": item.quality, "freight": item.get("freight", 0)})
			row.cogs -= item.cost
			channel.cogs -= item.cost
			activity.cogs -= item.cost
	row.store_activity[order.get("store_id", order.channel)] = activity
	Advertising.note_refund(state, int(order.get("campaign_id", 0)), int(order.get("store_id", order.channel)), order.total, reversed_cost)
	order.refunded = true
	close_case(state, order, "refunded")
	rate(state, 4, 2)
	return ""

static func close_case(state: Dictionary, order: Dictionary, outcome: String) -> void:
	order.case_status = outcome
	state.open_cases.erase(order.id)
