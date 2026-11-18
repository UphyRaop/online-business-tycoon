extends RefCounted

const Catalog = preload("res://catalog.gd")
const Service = preload("res://customer_service.gd")
const Stores = preload("res://store_manager.gd")
const Advertising = preload("res://advertising.gd")

static func place(sim: RefCounted, channel: int, items: Array, total: int, offer_kind: String,
		prices: Array = [], store_id: int = -1, campaign_id: int = 0) -> int:
	var state: Dictionary = sim.state
	if store_id < 0:
		store_id = channel
	var id: int = state.next_order
	state.next_order += 1
	var method: int = state.shipping
	var lines: Array = []
	for i in items.size():
		var line: Dictionary = sim.reserve_unit(items[i])
		if prices.size() == items.size():
			line.revenue = prices[i]
		lines.append(line)
	state.orders[id] = {
		"id": id, "items": lines, "total": total, "channel": channel, "store_id": store_id,
		"campaign_id": campaign_id, "status": "queued",
		"placed": state.day, "method": method,
		"promise": state.day + 1 + Catalog.SHIPPING[method].days,
		"shipped": 0, "eta": 0, "arrival": 0, "delayed": false, "delivered": 0,
		"case_status": "", "case_day": 0, "reason": "", "return_requested": false,
		"restockable": true, "escalated": false, "refunded": false,
	}
	state.active_orders.append(id)
	state.cash += total
	var row: Dictionary = state.ledger.back()
	row.deposits += total
	var totals: Dictionary = row.channels[channel]
	totals.placed += 1
	if not offer_kind.is_empty():
		totals[offer_kind] += 1
	return id

static func ship(state: Dictionary, id: int, method: int) -> String:
	var order: Dictionary = state.orders.get(id, {})
	if order.get("status") != "queued" or method not in range(Catalog.SHIPPING.size()):
		return "This order cannot be dispatched."
	var shipping: Dictionary = Catalog.SHIPPING[method]
	var rng := RandomNumberGenerator.new()
	rng.state = state.seed
	var delay := rng.randi_range(1, 3) if rng.randf() >= shipping.reliability else 0
	state.seed = rng.state
	dispatch(state, order, method, delay)
	return ""

static func dispatch(state: Dictionary, order: Dictionary, method: int, delay: int) -> void:
	var shipping: Dictionary = Catalog.SHIPPING[method]
	var cost := Catalog.local_cents(state.country, shipping.cost)
	order.status = "shipped"
	order.method = method
	order.shipped = state.day
	order.eta = state.day + shipping.days
	order.arrival = order.eta + delay
	order.shipping_cost = cost
	state.cash -= cost
	var row: Dictionary = state.ledger.back()
	row.shipping += cost
	row.channels[order.channel].shipping += cost
	row.channels[order.channel].dispatched += 1
	var activity := Stores.store_activity(row, int(order.get("store_id", order.channel)))
	activity.shipping += cost
	row.store_activity[order.get("store_id", order.channel)] = activity

static func auto_dispatch(state: Dictionary, rng: RandomNumberGenerator) -> void:
	if not state.auto_dispatch:
		return
	for id in state.active_orders:
		var order: Dictionary = state.orders[id]
		if order.status == "queued":
			var shipping: Dictionary = Catalog.SHIPPING[order.method]
			var delay := rng.randi_range(1, 3) if rng.randf() >= shipping.reliability else 0
			dispatch(state, order, order.method, delay)

static func deliver(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var pending: Array = []
	for id in state.active_orders:
		var order: Dictionary = state.orders[id]
		if order.status == "shipped" and order.arrival <= state.day:
			complete(state, order, rng)
		else:
			if order.status == "shipped" and state.day >= order.eta:
				order.delayed = true
			pending.append(id)
	state.active_orders = pending

static func complete(state: Dictionary, order: Dictionary, rng: RandomNumberGenerator) -> void:
	var row: Dictionary = state.ledger.back()
	var channel: Dictionary = row.channels[order.channel]
	var fee := Catalog.fee(order.channel, order.total)
	order.channel_fee = fee
	row.deposits -= order.total
	row.sales += order.total
	row.fees += fee
	channel.sales += order.total
	channel.fees += fee
	channel.orders += 1
	channel.tracked_deliveries += 1
	if state.day <= order.promise:
		channel.on_time += 1
	for item in order.items:
		row.cogs += item.cost
		channel.cogs += item.cost
	var activity := Stores.store_activity(row, int(order.get("store_id", order.channel)))
	activity.sales += order.total
	activity.fees += fee
	activity.orders += 1
	for item in order.items:
		activity.cogs += item.cost
	row.store_activity[order.get("store_id", order.channel)] = activity
	Advertising.note_delivery(state, int(order.get("store_id", order.channel)))
	state.cash -= fee
	order.status = "delivered"
	order.delivered = state.day
	Service.on_delivery(state, order, rng)
