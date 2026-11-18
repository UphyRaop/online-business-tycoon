extends RefCounted

const Catalog = preload("res://catalog.gd")
const Service = preload("res://customer_service.gd")
const Stores = preload("res://store_manager.gd")
const Advertising = preload("res://advertising.gd")
const Supply = preload("res://supply.gd")

static func place(sim: RefCounted, channel: int, items: Array, total: int, offer_kind: String,
		prices: Array = [], store_id: int = -1, campaign_id: int = 0) -> int:
	var state: Dictionary = sim.state
	if store_id < 0:
		store_id = channel
	var required_direct := 0
	var available_stock := {}
	for product_value in items:
		var product_id: int = int(product_value)
		var stock_remaining: int = int(available_stock.get(product_id, sim.stock(product_id)))
		if stock_remaining > 0:
			available_stock[product_id] = stock_remaining - 1
		else:
			var source: int = int(sim.product_state(product_id).get("supplier", 0))
			if not Supply.supplier_unlocked(state, source) or not Catalog.SUPPLIERS[source].direct:
				return 0
			required_direct += Catalog.quote(state.country, product_id, source) + Catalog.inbound_freight(state.country, source)
	if state.cash + total < required_direct:
		return 0
	var id: int = state.next_order
	state.next_order += 1
	var method: int = state.shipping
	var lines: Array = []
	var direct_cost := 0
	var direct_freight := 0
	for i in items.size():
		var product: int = items[i]
		var line: Dictionary
		if sim.stock(product) > 0:
			line = sim.reserve_unit(product)
		else:
			var product_state: Dictionary = sim.product_state(product)
			var supplier: int = int(product_state.get("supplier", 0))
			var provider: Dictionary = Catalog.SUPPLIERS[supplier]
			var freight: int = Catalog.inbound_freight(state.country, supplier)
			var goods: int = Catalog.quote(state.country, product, supplier)
			var landed := goods + freight
			line = {"product": product, "cost": landed, "quality": provider.quality, "freight": freight,
				"direct_supplier": supplier, "supplier_name": provider.name}
			direct_cost += landed
			direct_freight += freight
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
	if direct_cost > 0:
		state.cash -= direct_cost
		row.direct_purchases += direct_cost
		row.inbound_freight = int(row.get("inbound_freight", 0)) + direct_freight
		row.direct_inbound_freight += direct_freight
	var totals: Dictionary = row.channels[channel]
	totals.placed += 1
	if not offer_kind.is_empty():
		totals[offer_kind] += 1
	return id

static func ship(state: Dictionary, id: int, method: int) -> String:
	var order: Dictionary = state.orders.get(id, {})
	if order.get("status") != "queued" or method not in range(Catalog.SHIPPING.size()):
		return "This order cannot be dispatched."
	for item in order.items:
		if item.has("direct_supplier"):
			return "Supplier-direct orders follow their supplier's fulfillment schedule."
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
	for id in state.active_orders:
		var order: Dictionary = state.orders[id]
		if order.status == "queued":
			var direct_lead := 0
			for item in order.items:
				if item.has("direct_supplier"):
					direct_lead = maxi(direct_lead, int(Catalog.SUPPLIERS[int(item.direct_supplier)].lead))
			if direct_lead > 0:
				var supplier_delay := 0
				var supplier_reliability := 1.0
				for item in order.items:
					if item.has("direct_supplier"):
						var provider: Dictionary = Catalog.SUPPLIERS[int(item.direct_supplier)]
						supplier_reliability = minf(supplier_reliability, float(provider.reliability))
				if rng.randf() >= supplier_reliability:
					supplier_delay = rng.randi_range(1, 3)
				var has_warehouse_item := false
				for item in order.items:
					if not item.has("direct_supplier"):
						has_warehouse_item = true
				if has_warehouse_item:
					var shipping: Dictionary = Catalog.SHIPPING[order.method]
					var delay := rng.randi_range(1, 3) if rng.randf() >= shipping.reliability else 0
					dispatch(state, order, order.method, delay)
					order.eta = maxi(order.eta, state.day + direct_lead)
					order.arrival = maxi(order.arrival, order.eta + supplier_delay)
				else:
					order.status = "shipped"
					order.shipped = state.day
					order.eta = state.day + direct_lead
					order.arrival = order.eta + supplier_delay
					order.shipping_cost = 0
					state.ledger.back().channels[order.channel].dispatched += 1
				continue
			if not state.auto_dispatch:
				continue
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
	var fee := Stores.store_fee(Stores.get_store(state, int(order.get("store_id", order.channel))), order.channel, order.total)
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
		if item.has("direct_supplier"):
			row.direct_cogs += item.cost
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
