extends RefCounted

const Catalog = preload("res://catalog.gd")

static func collect(state: Dictionary) -> Dictionary:
	var metrics := {}
	for order in state.orders.values():
		if order.status == "queued":
			continue
		var items: Array = order.items
		var weights: Array = []
		var all_priced := true
		for item in items:
			if not item.has("revenue"):
				all_priced = false
		for item in items:
			weights.append(item.revenue if all_priced else item.cost)
		var shipping := int(order.get("shipping_cost", Catalog.local_cents(state.country, Catalog.SHIPPING[order.method].cost)))
		var delivered: bool = order.status == "delivered"
		var revenue: int = order.total if delivered and not order.refunded else 0
		var fee := int(order.get("channel_fee", Catalog.fee(order.channel, order.total))) if delivered else 0
		var sales := allocate(revenue, weights)
		var fees := allocate(fee, weights)
		var freight := allocate(shipping, weights)
		for i in items.size():
			var item: Dictionary = items[i]
			var totals: Dictionary = metrics.get(item.product, {"units": 0, "revenue": 0, "profit": 0})
			var cogs: int = item.cost if delivered and not (order.refunded and order.restockable) else 0
			totals.units += 1 if delivered and not order.refunded else 0
			totals.revenue += sales[i]
			totals.profit += sales[i] - cogs - fees[i] - freight[i]
			metrics[item.product] = totals
	return metrics

static func allocate(total: int, weights: Array) -> Array:
	var result: Array = []
	var sum := 0
	for weight in weights:
		sum += weight
	var previous := 0
	var running_weight := 0
	for i in weights.size():
		running_weight += weights[i]
		var cumulative := total if i == weights.size() - 1 else roundi(total * (float(running_weight) / sum))
		result.append(cumulative - previous)
		previous = cumulative
	return result
