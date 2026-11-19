extends RefCounted

const Catalog = preload("res://catalog.gd")
const Calendar = preload("res://game_calendar.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
const QUOTE_DAYS := 7

static func ensure_progress(state: Dictionary) -> void:
	if not state.get("supplier_level") is int:
		state.supplier_level = 1
	var sales := 0
	for row in state.get("ledger", []):
		sales += int(row.get("sales", 0))
	var usd_scale: float = Catalog.SCALE[state.get("country", 0)] / Catalog.SCALE[1]
	var equivalent := float(sales) / (usd_scale * 100.0)
	var thresholds: Array = state.get("supplier_thresholds_usd", Catalog.SUPPLIER_THRESHOLDS_USD.duplicate())
	var valid_thresholds := state.has("supplier_thresholds_usd") and thresholds.size() == 4
	for value in thresholds:
		if not (value is int or value is float) or float(value) < 0:
			valid_thresholds = false
	if not valid_thresholds:
		thresholds = Catalog.SUPPLIER_THRESHOLDS_USD.duplicate()
	state.supplier_thresholds_usd = thresholds
	for level in range(2, 5):
		if equivalent >= float(thresholds[level - 1]):
			state.supplier_level = maxi(state.supplier_level, level)
	if not state.get("supplier_unlocks") is Array:
		state.supplier_unlocks = []
	for supplier in Catalog.SUPPLIER_SELECTION_INDICES:
		if Catalog.SUPPLIERS[supplier].level <= state.supplier_level and supplier not in state.supplier_unlocks:
			state.supplier_unlocks.append(supplier)
	var unlock_ids: Array[String] = []
	for supplier in state.supplier_unlocks:
		if int(supplier) in range(Catalog.SUPPLIERS.size()):
			var stable_id := Catalog.supplier_id(int(supplier))
			if stable_id not in unlock_ids: unlock_ids.append(stable_id)
	state.supplier_unlock_ids = unlock_ids

static func migrate_references(state: Dictionary) -> void:
	# Numeric supplier fields remain in their original positions for historical
	# records. Stable IDs make those references explicit across future catalog edits.
	for product in state.get("products", {}):
		var item: Dictionary = state.products[product]
		var original: int = int(item.get("supplier", Catalog.DEFAULT_SUPPLIER))
		if original not in range(Catalog.SUPPLIERS.size()):
			original = Catalog.DEFAULT_SUPPLIER
		item.product_id = Catalog.product_id(int(product))
		item.supplier_id = Catalog.supplier_id(original)
		if not Catalog.supplier_available_for_sourcing(original):
			item.legacy_supplier = {"id": Catalog.supplier_id(original), "name": Catalog.SUPPLIERS[original].name}
		for lot in item.get("lots", []):
			lot.product_id = Catalog.product_id(int(product))
			if not lot.has("supplier"):
				lot.supplier = original
			lot.supplier_id = Catalog.supplier_id(int(lot.supplier))
			lot.supplier_name = Catalog.SUPPLIERS[int(lot.supplier)].name
		state.products[product] = item
	for batch in state.get("inbound", []):
		var supplier: int = int(batch.get("supplier", Catalog.DEFAULT_SUPPLIER))
		if supplier in range(Catalog.SUPPLIERS.size()):
			batch.product_id = Catalog.product_id(int(batch.product))
			batch.supplier_id = Catalog.supplier_id(supplier)
			batch.supplier_name = Catalog.SUPPLIERS[supplier].name
	for product in state.get("quotes", {}):
		for supplier in state.quotes[product]:
			if int(supplier) in range(Catalog.SUPPLIERS.size()):
				var quote: Dictionary = state.quotes[product][supplier]
				quote.supplier_id = Catalog.supplier_id(int(supplier))
				quote.supplier_name = Catalog.SUPPLIERS[int(supplier)].name
	for order_id in state.get("orders", {}):
		var order: Dictionary = state.orders[order_id]
		for item in order.get("items", []):
			if item.has("product") and int(item.product) in range(Catalog.PRODUCTS.size()):
				item.product_id = Catalog.product_id(int(item.product))
			if item.has("direct_supplier"):
				var supplier: int = int(item.direct_supplier)
				if supplier in range(Catalog.SUPPLIERS.size()):
					item.direct_supplier_id = Catalog.supplier_id(supplier)
					item.direct_supplier_name = str(item.get("supplier_name", Catalog.SUPPLIERS[supplier].name))
					item.supplier_lead = int(item.get("supplier_lead", Catalog.SUPPLIERS[supplier].lead))
					item.supplier_reliability = float(item.get("supplier_reliability", Catalog.SUPPLIERS[supplier].reliability))
	state.supplier_schema_version = 2

static func supplier_unlocked(state: Dictionary, supplier: int) -> bool:
	return Catalog.supplier_available_for_sourcing(supplier) and supplier in range(Catalog.SUPPLIERS.size()) \
		and (supplier in state.get("supplier_unlocks", []) or Catalog.SUPPLIERS[supplier].level <= state.get("supplier_level", 1))

static func quote(state: Dictionary, product: int, supplier: int) -> Dictionary:
	if supplier not in range(Catalog.SUPPLIERS.size()) or not Catalog.supplier_available_for_sourcing(supplier):
		return {"cost": 0, "minimum": 0, "expires": 0, "discount": 0}
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	if not supplier_unlocked(state, supplier): return {"cost": 0, "minimum": provider.minimum, "expires": 0, "discount": 0}
	var base := Catalog.quote(state.country, product, supplier)
	var negotiated: Dictionary = state.quotes.get(product, {}).get(supplier, {})
	if not negotiated.is_empty() and state.day <= negotiated.expires:
		return negotiated
	return {"cost": base, "minimum": provider.minimum, "expires": 0, "discount": 0}

static func negotiate(state: Dictionary, product: int, supplier: int, units: int) -> String:
	if supplier not in range(Catalog.SUPPLIERS.size()) or not Catalog.supplier_available_for_sourcing(supplier): return "This supplier is retained for historical records and is unavailable for new sourcing."
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	if not supplier_unlocked(state, supplier): return "Supplier platform is locked."
	var threshold: int = negotiation_minimum(supplier)
	if units < threshold or units > maximum_order_quantity(supplier):
		return "This supplier negotiates orders of %s to %s units." % [_quantity(threshold), _quantity(maximum_order_quantity(supplier))]
	var deals: Dictionary = state.quotes.get(product, {})
	var existing := quote(state, product, supplier)
	if existing.discount > 0:
		return "The current quote is firm through %s." % Calendar.format(existing.expires)
	var discount: int = provider.discount if units >= threshold * 2 else maxi(1, roundi(provider.discount / 2.0))
	var minimum := threshold * 2 if units >= threshold * 2 else threshold
	deals[supplier] = {
		"cost": maxi(1, roundi(Catalog.quote(state.country, product, supplier) * (1.0 - discount / 100.0))),
		"minimum": minimum, "expires": state.day + QUOTE_DAYS - 1, "discount": discount,
		"supplier_id": Catalog.supplier_id(supplier), "supplier_name": provider.name,
	}
	state.quotes[product] = deals
	return ""

static func negotiation_minimum(supplier: int) -> int:
	return maxi(10, Catalog.SUPPLIERS[supplier].minimum * 4)

static func maximum_order_quantity(supplier: int) -> int:
	return int(Catalog.SUPPLIER_MAX_ORDER[supplier]) if supplier in range(Catalog.SUPPLIER_MAX_ORDER.size()) else 0

static func purchase(state: Dictionary, product: int, supplier: int, units: int) -> String:
	return str(purchase_order(state, product, supplier, units, 0).get("error", ""))

static func purchase_breakdown(state: Dictionary, product: int, supplier: int, units: int) -> Dictionary:
	if product not in range(Catalog.PRODUCTS.size()): return {"error": "Choose a valid catalog product."}
	if supplier not in range(Catalog.SUPPLIERS.size()) or not Catalog.supplier_available_for_sourcing(supplier): return {"error": "This supplier is retained for historical records and is unavailable for new sourcing."}
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	if not supplier_unlocked(state, supplier): return {"error": "Supplier platform is locked."}
	var offer := quote(state, product, supplier)
	var maximum := maximum_order_quantity(supplier)
	if units < provider.minimum or units > maximum:
		return {"error": "Enter a quantity from %s to %s." % [_quantity(provider.minimum), _quantity(maximum)]}
	var goods: int = offer.cost if units >= offer.minimum else Catalog.quote(state.country, product, supplier)
	var freight := Catalog.inbound_freight(state.country, supplier)
	return {"error": "", "supplier": supplier, "supplier_id": Catalog.supplier_id(supplier), "product": product,
		"units": units, "goods_unit_cost": goods, "freight_unit_cost": freight,
		"landed_unit_cost": goods + freight, "total": (goods + freight) * units,
		"minimum": int(provider.minimum), "maximum": maximum, "offer": offer.duplicate(true)}

static func purchase_order(state: Dictionary, product: int, supplier: int, units: int, credit_amount: int = 0) -> Dictionary:
	var breakdown := purchase_breakdown(state, product, supplier, units)
	if not str(breakdown.get("error", "")).is_empty(): return breakdown
	var total := int(breakdown.total)
	if credit_amount < 0 or credit_amount > total: return {"error": "Invalid supplier credit amount."}
	if total - credit_amount > int(state.cash): return {"error": "Insufficient cash for this purchase."}
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	var freight := int(breakdown.freight_unit_cost)
	var landed := int(breakdown.landed_unit_cost)
	var rng := RandomNumberGenerator.new()
	rng.state = state.seed
	var delay := rng.randi_range(1, 3) if rng.randf() >= provider.reliability else 0
	state.seed = rng.state
	var id: int = state.next_purchase
	state.next_purchase += 1
	state.inbound.append({
		"id": id, "product": product, "product_id": Catalog.product_id(product), "supplier": supplier, "supplier_id": Catalog.supplier_id(supplier),
		"supplier_name": provider.name, "units": units, "cost": landed,
		"freight": freight,
		"quality": provider.quality, "lead_time": provider.lead, "eta": state.day + provider.lead, "arrival": state.day + provider.lead + delay,
		"delayed": false, "payment_method": "credit" if credit_amount > 0 else "cash",
	})
	state.cash -= total - credit_amount
	state.ledger.back().purchases += total
	state.ledger.back().credit_purchases += credit_amount
	var row: Dictionary = state.ledger.back()
	var freight_total := freight * units
	row.inbound_freight = row.get("inbound_freight", 0) + freight_total
	# Allocate the credit portion proportionally so cash-flow statements exclude
	# freight financed by the supplier, including mixed cash/credit purchases.
	var credited_freight := mini(freight_total, int(round(float(freight_total) * float(credit_amount) / float(maxi(1, total)))))
	row.credit_inbound_freight = row.get("credit_inbound_freight", 0) + credited_freight
	return {"error": "", "purchase_id": id, "total": total, "credit_amount": credit_amount,
		"cash_paid": total - credit_amount, "landed_unit_cost": landed, "freight_unit_cost": freight}

static func return_sources(state: Dictionary, product: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if product not in range(Catalog.PRODUCTS.size()): return result
	var item: Dictionary = state.get("products", {}).get(product, {})
	var groups := {}
	for lot in item.get("lots", []):
		var supplier := _lot_supplier(lot)
		if not groups.has(supplier):
			groups[supplier] = {"supplier": supplier, "name": _lot_supplier_name(lot, supplier), "units": 0}
		groups[supplier].units += maxi(0, int(lot.get("units", 0)))
	for supplier in groups:
		if int(groups[supplier].units) > 0:
			result.append(groups[supplier])
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.supplier) < int(b.supplier))
	return result

static func preview_return(state: Dictionary, product: int, supplier: int, units: int) -> Dictionary:
	if product not in range(Catalog.PRODUCTS.size()): return {"error": "Choose a valid product."}
	if units <= 0: return {"error": "Enter a positive quantity to return."}
	var source: Dictionary = {}
	for option in return_sources(state, product):
		if int(option.supplier) == supplier:
			source = option
			break
	if source.is_empty(): return {"error": "No unreserved stock from this supplier is available to return."}
	if units > int(source.units): return {"error": "Return quantity exceeds unreserved stock from this supplier."}
	var remaining := units
	var original_cost := 0
	var landed_cost := 0
	var refund := 0
	var allocations: Array[Dictionary] = []
	var item: Dictionary = state.products.get(product, {})
	for lot in item.get("lots", []):
		if _lot_supplier(lot) != supplier or remaining <= 0: continue
		var taken := mini(remaining, maxi(0, int(lot.get("units", 0))))
		if taken <= 0: continue
		var costs := _lot_costs(state, product, lot)
		var goods_total := int(costs.goods) * taken
		var landed_total := int(costs.landed) * taken
		var refund_total := floori(float(costs.goods) * 0.5) * taken
		original_cost += goods_total
		landed_cost += landed_total
		refund += refund_total
		allocations.append({"units": taken, "original_unit_cost": int(costs.goods), "landed_unit_cost": int(costs.landed),
			"freight_per_unit": int(costs.freight), "cost_fallback": bool(costs.fallback),
			"purchase_id": int(lot.get("purchase_id", 0)), "payment_method": str(lot.get("payment_method", "cash")),
			"refund": refund_total})
		remaining -= taken
	return {"error": "" if remaining == 0 else "Unable to allocate the requested historical lots.", "supplier": supplier,
		"supplier_name": str(source.name), "units": units, "original_purchase_cost": original_cost,
		"landed_cost": landed_cost, "refund": refund, "allocations": allocations}

static func return_stock(state: Dictionary, product: int, supplier: int, units: int) -> Dictionary:
	var preview := preview_return(state, product, supplier, units)
	if not str(preview.get("error", "")).is_empty(): return preview
	var item: Dictionary = state.products.get(product, {}).duplicate(true)
	var remaining := units
	var index := 0
	while index < item.lots.size() and remaining > 0:
		var lot: Dictionary = item.lots[index]
		if _lot_supplier(lot) != supplier:
			index += 1
			continue
		var taken := mini(remaining, int(lot.units))
		lot.units -= taken
		remaining -= taken
		if lot.units <= 0:
			item.lots.remove_at(index)
		else:
			item.lots[index] = lot
			index += 1
	if remaining != 0: return {"error": "The available stock changed before the return could be recorded."}
	var record := {
		"id": int(state.get("next_supplier_return", 1)), "day": int(state.day), "date": Calendar.format(int(state.day)),
		"product": product, "product_id": Catalog.product_id(product), "supplier": supplier,
		"supplier_id": Catalog.supplier_id(supplier) if supplier in range(Catalog.SUPPLIERS.size()) else "",
		"supplier_name": str(preview.supplier_name), "units": units,
		"original_purchase_cost": int(preview.original_purchase_cost), "landed_cost": int(preview.landed_cost),
		"refund": int(preview.refund), "allocations": preview.allocations,
	}
	var credit_refunds_by_purchase := {}
	for allocation in record.allocations:
		if str(allocation.get("payment_method", "cash")) != "credit" or int(allocation.get("purchase_id", 0)) < 1: continue
		var purchase_id := int(allocation.purchase_id)
		credit_refunds_by_purchase[purchase_id] = int(credit_refunds_by_purchase.get(purchase_id, 0)) + int(allocation.get("refund", 0))
	var credit_adjustment_total := 0
	for purchase_id in credit_refunds_by_purchase:
		var adjustment := SupplierCredit.record_return_adjustment(state, supplier, product, int(purchase_id),
			int(credit_refunds_by_purchase[purchase_id]), int(record.id))
		if not str(adjustment.get("error", "")).is_empty() and not bool(adjustment.get("duplicate", false)):
			return {"error": str(adjustment.error)}
		credit_adjustment_total += int(adjustment.get("applied", 0))
	record.supplier_credit_adjustments = credit_adjustment_total
	state.products[product] = item
	state.next_supplier_return = int(record.id) + 1
	if not state.get("supplier_returns") is Array: state.supplier_returns = []
	state.supplier_returns.append(record)
	var row: Dictionary = state.ledger.back()
	row.inventory_returns += int(record.landed_cost)
	row.supplier_refunds += int(record.refund)
	row.supplier_credit_adjustments += credit_adjustment_total
	state.cash += int(record.refund) - credit_adjustment_total
	return {"error": "", "record": record}

static func _lot_supplier(lot: Dictionary) -> int:
	var supplier := int(lot.get("supplier", -1))
	if supplier in range(Catalog.SUPPLIERS.size()): return supplier
	var stable_id := str(lot.get("supplier_id", ""))
	return Catalog.supplier_index(stable_id) if not stable_id.is_empty() else -1

static func _lot_supplier_name(lot: Dictionary, supplier: int) -> String:
	if supplier in range(Catalog.SUPPLIERS.size()): return Catalog.SUPPLIERS[supplier].name
	var recorded := str(lot.get("supplier_name", "")).strip_edges()
	return recorded if not recorded.is_empty() else "Historical supplier not recorded"

static func _lot_costs(state: Dictionary, product: int, lot: Dictionary) -> Dictionary:
	if lot.get("cost") is int and int(lot.cost) > 0:
		var landed := int(lot.cost)
		var freight := clampi(int(lot.get("freight", 0)), 0, landed - 1)
		return {"goods": landed - freight, "landed": landed, "freight": freight, "fallback": false}
	# Old/partial lots without a unit cost use the catalog's original base goods cost
	# converted at the company's country scale. This is stable and excludes supplier
	# discounts, current quotes, freight, and later negotiation state.
	var goods := Catalog.local_cents(int(state.get("country", 0)), float(Catalog.PRODUCTS[product].cost))
	return {"goods": goods, "landed": goods, "freight": 0, "fallback": true}

static func receive(sim: RefCounted) -> void:
	var pending: Array = []
	for batch in sim.state.inbound:
		if batch.arrival <= sim.state.day:
				sim.add_stock(batch.product, {"units": batch.units, "cost": batch.cost, "quality": batch.quality, "freight": batch.get("freight", 0),
					"supplier": batch.get("supplier", Catalog.DEFAULT_SUPPLIER), "supplier_id": batch.get("supplier_id", Catalog.supplier_id(int(batch.get("supplier", Catalog.DEFAULT_SUPPLIER)))),
					"supplier_name": batch.get("supplier_name", Catalog.SUPPLIERS[int(batch.get("supplier", Catalog.DEFAULT_SUPPLIER))].name),
					"purchase_id": int(batch.get("id", 0)), "payment_method": str(batch.get("payment_method", "cash"))})
		else:
			batch.delayed = sim.state.day >= batch.eta
			pending.append(batch)
	sim.state.inbound = pending

static func incoming(state: Dictionary, product: int, horizon: int = 0) -> int:
	var units := 0
	for batch in state.inbound:
		var estimate: int = batch.arrival if batch.delayed else batch.eta
		if batch.product == product and (horizon == 0 or estimate <= state.day + horizon):
			units += batch.units
	return units

static func forecast(sim: RefCounted, product: int, supplier: int) -> Dictionary:
	var state: Dictionary = sim.state
	var lead: int = Catalog.SUPPLIERS[supplier].lead
	var observed := 0
	var days := 0
	for i in range(maxi(0, state.day - 15), state.day - 1):
		var observed_row: Dictionary = state.ledger[i].demand
		if observed_row.has(product):
			days += 1
			observed += observed_row[product]
	var daily: float = float(observed) / days if days > 0 else 2.0 * Catalog.PRODUCTS[product].demand * (1.72 if state.channel == 2 else Catalog.TRAFFIC[state.channel])
	var target := ceili(daily * (lead + 3))
	var gap := maxi(0, target - sim.stock(product) - incoming(state, product, lead + 3))
	var suggested := clampi(gap, Catalog.SUPPLIERS[supplier].minimum, maximum_order_quantity(supplier)) if gap > 0 else 0
	return {"daily": daily, "days": days, "target": target, "suggested": suggested, "lead": lead}

static func _quantity(value: int) -> String:
	var text := str(value)
	var result := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0: result += ","
		result += text[i]
	return result
