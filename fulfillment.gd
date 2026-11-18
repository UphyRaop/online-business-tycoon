extends RefCounted

const Catalog = preload("res://catalog.gd")
const Service = preload("res://customer_service.gd")
const Stores = preload("res://store_manager.gd")
const Advertising = preload("res://advertising.gd")
const Supply = preload("res://supply.gd")

static func place(sim: RefCounted, channel: int, items: Array, total: int, offer_kind: String,
		prices: Array = [], store_id: int = -1, campaign_id: int = 0, allow_preorders: bool = false) -> int:
	var state: Dictionary = sim.state
	if store_id < 0:
		store_id = channel
	var missing_stock := false
	var required_direct := 0
	var available_stock := {}
	for product_value in items:
		var product_id: int = int(product_value)
		var stock_remaining: int = int(available_stock.get(product_id, sim.stock(product_id)))
		if stock_remaining > 0:
			available_stock[product_id] = stock_remaining - 1
		else:
			if allow_preorders:
				missing_stock = true
				continue
			var source: int = int(sim.product_state(product_id).get("supplier", Catalog.DEFAULT_SUPPLIER))
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
			line.product_id = Catalog.product_id(product)
		elif missing_stock:
			line = {"product": product, "product_id": Catalog.product_id(product), "cost": 0,
				"quality": 1.0, "freight": 0, "awaiting_stock": true}
		else:
			var product_state: Dictionary = sim.product_state(product)
			var supplier: int = int(product_state.get("supplier", Catalog.DEFAULT_SUPPLIER))
			var provider: Dictionary = Catalog.SUPPLIERS[supplier]
			var freight: int = Catalog.inbound_freight(state.country, supplier)
			var goods: int = Catalog.quote(state.country, product, supplier)
			var landed := goods + freight
			line = {"product": product, "cost": landed, "quality": provider.quality, "freight": freight,
				"direct_supplier": supplier, "direct_supplier_id": Catalog.supplier_id(supplier),
				"supplier_name": provider.name, "supplier_lead": provider.lead,
				"supplier_reliability": provider.reliability}
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
	if missing_stock:
		var expected_restock := 0
		for batch in state.inbound:
			if int(batch.product) in items:
				var estimate: int = int(batch.arrival if batch.get("delayed", false) else batch.eta)
				if expected_restock == 0 or estimate < expected_restock: expected_restock = estimate
		if expected_restock == 0:
			var max_lead := 0
			for product_value in items:
				max_lead = maxi(max_lead, int(Catalog.SUPPLIERS[int(sim.product_state(int(product_value)).get("supplier", Catalog.DEFAULT_SUPPLIER))].lead))
			expected_restock = state.day + max_lead
		state.orders[id].preorder = true
		state.orders[id].preorder_status = "awaiting_stock"
		state.orders[id].expected_restock = expected_restock
		state.orders[id].fulfillment_delay = maxi(0, expected_restock - state.day) + Catalog.SHIPPING[method].days
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
	if order.get("preorder", false) and order.get("preorder_status") != "ready_for_fulfillment":
		return "This pre-order is waiting for stock allocation."
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
	if order.get("preorder", false): order.preorder_status = "shipped"
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
			if order.get("preorder", false) and order.get("preorder_status") != "ready_for_fulfillment":
				continue
			var direct_lead := 0
			for item in order.items:
				if item.has("direct_supplier"):
					direct_lead = maxi(direct_lead, int(item.get("supplier_lead", Catalog.SUPPLIERS[int(item.direct_supplier)].lead)))
			if direct_lead > 0:
				var supplier_delay := 0
				var supplier_reliability := 1.0
				for item in order.items:
					if item.has("direct_supplier"):
						var reliability: float = float(item.get("supplier_reliability", Catalog.SUPPLIERS[int(item.direct_supplier)].reliability))
						supplier_reliability = minf(supplier_reliability, reliability)
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
					if order.get("preorder", false): order.preorder_status = "shipped"
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
	if order.get("preorder", false): order.preorder_status = "delivered"
	Advertising.note_delivery(state, order)
	state.cash -= fee
	order.status = "delivered"
	order.delivered = state.day
	Service.on_delivery(state, order, rng)

static func allocate_preorders(sim: RefCounted) -> void:
	var state: Dictionary = sim.state
	var ids: Array = state.orders.keys()
	ids.sort_custom(func(a: int, b: int):
		var first: Dictionary = state.orders[a]
		var second: Dictionary = state.orders[b]
		return first.placed < second.placed if first.placed != second.placed else a < b
	)
	for id in ids:
		var order: Dictionary = state.orders[id]
		if not order.get("preorder", false) or order.status != "queued": continue
		for index in order.items.size():
			var line: Dictionary = order.items[index]
			if not line.get("awaiting_stock", false) or sim.stock(int(line.product)) < 1: continue
			var allocated: Dictionary = sim.reserve_unit(int(line.product))
			allocated.product = int(line.product)
			allocated.product_id = Catalog.product_id(int(line.product))
			if line.has("revenue"): allocated.revenue = int(line.revenue)
			order.items[index] = allocated
		var waiting := false
		var allocated_any := false
		for line in order.items:
			waiting = waiting or line.get("awaiting_stock", false)
			allocated_any = allocated_any or not line.get("awaiting_stock", false)
		if waiting:
			order.preorder_status = "stock_allocated" if allocated_any else "awaiting_stock"
		else:
			order.preorder_status = "ready_for_fulfillment"
			order.expected_restock = state.day
			order.fulfillment_delay = Catalog.SHIPPING[order.method].days
			order.promise = maxi(order.promise, state.day + 1 + Catalog.SHIPPING[order.method].days)

static func outstanding_preorders(state: Dictionary, product: int = -1, store_id: int = -1) -> int:
	var total := 0
	for order in state.orders.values():
		if not order.get("preorder", false) or order.status in ["delivered", "cancelled"]: continue
		if store_id >= 0 and int(order.store_id) != store_id: continue
		for line in order.items:
			if product < 0 or int(line.product) == product: total += 1
	return total
