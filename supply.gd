extends RefCounted

const Catalog = preload("res://catalog.gd")
const Calendar = preload("res://game_calendar.gd")
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
	for supplier in Catalog.SUPPLIERS.size():
		if Catalog.SUPPLIERS[supplier].level <= state.supplier_level and supplier not in state.supplier_unlocks:
			state.supplier_unlocks.append(supplier)

static func supplier_unlocked(state: Dictionary, supplier: int) -> bool:
	return supplier in range(Catalog.SUPPLIERS.size()) and (supplier in state.get("supplier_unlocks", []) or Catalog.SUPPLIERS[supplier].level <= state.get("supplier_level", 1))

static func quote(state: Dictionary, product: int, supplier: int) -> Dictionary:
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	if not supplier_unlocked(state, supplier): return {"cost": 0, "minimum": provider.minimum, "expires": 0, "discount": 0}
	var base := Catalog.quote(state.country, product, supplier)
	var negotiated: Dictionary = state.quotes.get(product, {}).get(supplier, {})
	if not negotiated.is_empty() and state.day <= negotiated.expires:
		return negotiated
	return {"cost": base, "minimum": provider.minimum, "expires": 0, "discount": 0}

static func negotiate(state: Dictionary, product: int, supplier: int, units: int) -> String:
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	if not supplier_unlocked(state, supplier): return "Supplier platform is locked."
	var threshold: int = negotiation_minimum(supplier)
	if units < threshold or units > 999:
		return "This supplier negotiates orders of %d to 999 units." % threshold
	var deals: Dictionary = state.quotes.get(product, {})
	var existing := quote(state, product, supplier)
	if existing.discount > 0:
		return "The current quote is firm through %s." % Calendar.format(existing.expires)
	var discount: int = provider.discount if units >= threshold * 2 else maxi(1, roundi(provider.discount / 2.0))
	var minimum := threshold * 2 if units >= threshold * 2 else threshold
	deals[supplier] = {
		"cost": maxi(1, roundi(Catalog.quote(state.country, product, supplier) * (1.0 - discount / 100.0))),
		"minimum": minimum, "expires": state.day + QUOTE_DAYS - 1, "discount": discount,
	}
	state.quotes[product] = deals
	return ""

static func negotiation_minimum(supplier: int) -> int:
	return maxi(10, Catalog.SUPPLIERS[supplier].minimum * 4)

static func purchase(state: Dictionary, product: int, supplier: int, units: int) -> String:
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	if not supplier_unlocked(state, supplier): return "Supplier platform is locked."
	var offer := quote(state, product, supplier)
	if units < provider.minimum or units > 999:
		return "Enter a quantity from %d to 999." % provider.minimum
	var goods: int = offer.cost if units >= offer.minimum else Catalog.quote(state.country, product, supplier)
	var freight := Catalog.inbound_freight(state.country, supplier)
	var cost := goods + freight
	if cost * units > state.cash:
		return "Insufficient cash for this purchase."
	var rng := RandomNumberGenerator.new()
	rng.state = state.seed
	var delay := rng.randi_range(1, 3) if rng.randf() >= provider.reliability else 0
	state.seed = rng.state
	var id: int = state.next_purchase
	state.next_purchase += 1
	state.inbound.append({
		"id": id, "product": product, "supplier": supplier, "units": units, "cost": cost,
		"freight": freight,
		"quality": provider.quality, "eta": state.day + provider.lead, "arrival": state.day + provider.lead + delay,
		"delayed": false,
	})
	state.cash -= cost * units
	state.ledger.back().purchases += cost * units
	var row: Dictionary = state.ledger.back()
	row.inbound_freight = row.get("inbound_freight", 0) + freight * units
	return ""

static func receive(sim: RefCounted) -> void:
	var pending: Array = []
	for batch in sim.state.inbound:
		if batch.arrival <= sim.state.day:
			sim.add_stock(batch.product, {"units": batch.units, "cost": batch.cost, "quality": batch.quality, "freight": batch.get("freight", 0)})
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
	var suggested := clampi(gap, Catalog.SUPPLIERS[supplier].minimum, 999) if gap > 0 else 0
	return {"daily": daily, "days": days, "target": target, "suggested": suggested, "lead": lead}
