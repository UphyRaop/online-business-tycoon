extends RefCounted

const Catalog = preload("res://catalog.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Stores = preload("res://store_manager.gd")
const Supply = preload("res://supply.gd")

static func offers_for(state: Dictionary, product: int) -> Dictionary:
	return _normalize_offers(state.get("offers", {}).get(product, {}))

static func offers_for_store(state: Dictionary, store_id: int, product: int) -> Dictionary:
	var store := Stores.get_store(state, store_id)
	var store_offers: Dictionary = store.get("offers", {})
	if store_offers.has(product):
		return _normalize_offers(store_offers.get(product, {}))
	return offers_for(state, product)

static func _normalize_offers(stored: Variant) -> Dictionary:
	if not stored is Dictionary: return {}
	var normalized := {}
	if stored.has("mode"): stored = {int(stored.mode): stored}
	for key in stored:
		var mode := int(key)
		var offer: Variant = stored[key]
		if not offer is Dictionary: continue
		var value: Dictionary = offer.duplicate(true)
		value.mode = mode
		if mode == 1:
			value.quantity = clampi(int(value.get("quantity", 2)), 2, 10)
			value.discount = int(value.get("discount", 0))
			value.price = int(value.get("price", 0))
		else:
			if not value.get("items", null) is Array: value.items = [int(value.get("add_on", -1))]
			value.discount = int(value.get("discount", 0))
			value.price = int(value.get("price", 0))
		value.enabled = value.get("enabled", true) == true
		normalized[mode] = value
	if normalized.get(1, {}).get("enabled", false) and normalized.get(2, {}).get("enabled", false):
		normalized[2].enabled = false
	return normalized

static func set_bundle_for_store(state: Dictionary, store_id: int, product: int, quantity: int, discount: int, price: int = 0) -> String:
	if Stores.index_of(state, store_id) < 0: return "Choose an existing store listing."
	if not valid_product(product) or quantity < 2 or quantity > 10 or discount not in range(51) or price < 0:
		return "Choose 2–10 units and a valid bundle price or discount."
	var offers := offers_for_store(state, store_id, product)
	var enabled: bool = offers.get(1, {}).get("enabled", true)
	offers[1] = {"mode": 1, "quantity": quantity, "discount": discount, "price": price, "enabled": enabled}
	if enabled and offers.has(2): offers[2].enabled = false
	_store_offers_set(state, store_id, product, offers)
	return ""

static func set_upsell_for_store(state: Dictionary, store_id: int, product: int, items: Array, discount: int, price: int = 0) -> String:
	if Stores.index_of(state, store_id) < 0: return "Choose an existing store listing."
	if not valid_product(product) or items.is_empty() or items.size() > 2 or discount not in range(51) or price < 0:
		return "Choose one or two additional units and a valid price or discount."
	for add_on in items:
		if not valid_product(add_on) or int(add_on) == product: return "Every upsell product must differ from the primary product."
	var offers := offers_for_store(state, store_id, product)
	var enabled: bool = offers.get(2, {}).get("enabled", true)
	offers[2] = {"mode": 2, "items": items.duplicate(), "discount": discount, "price": price, "enabled": enabled}
	if enabled and offers.has(1): offers[1].enabled = false
	_store_offers_set(state, store_id, product, offers)
	return ""

static func set_enabled_for_store(state: Dictionary, store_id: int, product: int, mode: int, enabled: bool) -> String:
	if Stores.index_of(state, store_id) < 0: return "Choose an existing store listing."
	if not valid_product(product) or mode not in [1, 2]: return "Choose a valid product offer."
	var offers := offers_for_store(state, store_id, product)
	if not offers.has(mode): return "Save this offer before enabling or disabling it."
	offers[mode].enabled = enabled
	if enabled and offers.has(3 - mode): offers[3 - mode].enabled = false
	_store_offers_set(state, store_id, product, offers)
	return ""

static func _store_offers_set(state: Dictionary, store_id: int, product: int, offers: Dictionary) -> void:
	var index := Stores.index_of(state, store_id)
	var store: Dictionary = state.stores[index].duplicate(true)
	var values: Dictionary = store.get("offers", {})
	values[product] = offers
	store.offers = values
	state.stores[index] = store

static func set_bundle(state: Dictionary, product: int, quantity: int, discount: int, price: int = 0) -> String:
	if not valid_product(product) or quantity < 2 or quantity > 10 or discount not in range(51) or price < 0:
		return "Choose 2–10 units and a valid bundle price or discount."
	var offers := offers_for(state, product)
	var enabled: bool = offers.get(1, {}).get("enabled", true)
	offers[1] = {"mode": 1, "quantity": quantity, "discount": discount, "price": price, "enabled": enabled}
	if enabled and offers.has(2): offers[2].enabled = false
	state.offers[product] = offers
	return ""

static func set_upsell(state: Dictionary, product: int, items: Array, discount: int, price: int = 0) -> String:
	if not valid_product(product) or items.is_empty() or items.size() > 2 or discount not in range(51) or price < 0:
		return "Choose one or two additional units and a valid price or discount."
	for add_on in items:
		if not valid_product(add_on) or add_on == product:
			return "Every upsell product must differ from the primary product."
	var offers := offers_for(state, product)
	var enabled: bool = offers.get(2, {}).get("enabled", true)
	offers[2] = {"mode": 2, "items": items.duplicate(), "discount": discount, "price": price, "enabled": enabled}
	if enabled and offers.has(1): offers[1].enabled = false
	state.offers[product] = offers
	return ""

# Backwards-compatible API used by older saves and Phase 2 callers.
static func set_offer(state: Dictionary, product: int, mode: int, add_on: int, discount: int) -> String:
	if mode == 0:
		state.offers.erase(product)
		return ""
	if mode == 1:
		return set_bundle(state, product, 2, discount)
	if mode == 2:
		return set_upsell(state, product, [add_on], discount)
	return "Choose a valid offer type."

static func set_enabled(state: Dictionary, product: int, mode: int, enabled: bool) -> String:
	var offers := offers_for(state, product)
	if not offers.has(mode):
		return "Save this offer before enabling or disabling it."
	offers[mode].enabled = enabled
	if enabled and offers.has(3 - mode): offers[3 - mode].enabled = false
	state.offers[product] = offers
	return ""

static func valid_product(product: Variant) -> bool:
	return product is int and product in range(Catalog.PRODUCTS.size())

static func run_product(sim: RefCounted, product: int, item: Dictionary, channel: int, rng: RandomNumberGenerator, store_id: int = -1) -> void:
	var state: Dictionary = sim.state
	var definition: Dictionary = Catalog.PRODUCTS[product]
	var fair := Catalog.local_cents(state.country, definition.cost * 2.7)
	var value := clampf(float(fair) / item.price, 0.2, 1.8)
	var reputation: float = state.reputation / 100.0
	var store := Stores.get_store(state, store_id) if store_id >= 0 else {}
	var expected: float = 3.7 * definition.demand * value * Catalog.TRAFFIC[channel] * (0.60 + reputation * 0.65) * Stores.traffic_multiplier(store)
	var attempts := floori(expected)
	if rng.randf() < expected - attempts:
		attempts += 1
	var row: Dictionary = state.ledger.back()
	var totals: Dictionary = row.channels[channel]
	var conversion := clampf(0.30 + (reputation - 0.7) * 0.25 + (value - 1.0) * 0.15
		+ (2 - Catalog.SHIPPING[state.shipping].days) * 0.02, 0.05, 0.65) * Stores.conversion_multiplier(store)
	conversion = clampf(conversion, 0.03, 0.70)
	var offers := offers_for_store(state, store_id, product) if store_id >= 0 else offers_for(state, product)
	if store_id >= 0:
		state.advertising.visitors[store_id] = int(state.advertising.visitors.get(store_id, 0)) + attempts
	for attempt in attempts:
		totals.checkouts += 1
		if rng.randf() >= conversion:
			totals.abandoned += 1
			continue
		complete_checkout(sim, product, item.price, channel, offers, rng, store_id, 0)

static func complete_checkout(sim: RefCounted, product: int, price: int, channel: int, offers: Dictionary,
		rng: RandomNumberGenerator, store_id: int = -1, campaign_id: int = 0) -> int:
	var row: Dictionary = sim.state.ledger.back()
	var totals: Dictionary = row.channels[channel]
	if store_id < 0:
		for store in sim.state.stores:
			if int(store.type) == channel and store.legacy:
				store_id = int(store.id)
				break
	var main_listing: Dictionary = Stores.listing(sim.state, store_id, product) if store_id >= 0 else {}
	var allow_preorders: bool = main_listing.get("allow_preorders", false) == true
	var basket: Array = [product]
	var reference_prices: Array = [price]
	var total := price
	var kind := ""
	row.demand[product] = row.demand.get(product, 0) + 1
	for mode in [1, 2]:
		var offer: Dictionary = offers.get(mode, {})
		if offer.is_empty() or not offer.get("enabled", true):
			continue
		if rng.randf() >= offer_uptake(mode, offer.discount):
			continue
		var proposed: Array = []
		var references: Array = []
		if mode == 1:
			var quantity: int = int(offer.get("quantity", 2))
			if quantity < 2 or quantity > 10:
				continue
			proposed.assign(repeat_product(product, quantity - 1))
			references.assign(repeat_product(price, quantity - 1))
		else:
			var add_ons: Variant = offer.get("items", [offer.get("add_on", -1)])
			if not add_ons is Array or add_ons.is_empty() or add_ons.size() > 2:
				continue
			var valid := true
			for add_on in add_ons:
				if not valid_product(add_on) or add_on == product:
					valid = false
					break
				var add_on_listed: bool = sim.product_on_store(store_id, add_on) if store_id >= 0 else sim.product_on_channel(sim.product_state(add_on), channel)
				if not add_on_listed:
					valid = false
					break
				proposed.append(add_on)
				references.append(sim.product_state(add_on).price)
			if not valid:
				continue
		var needed := {product: 1}
		for sku in proposed:
			needed[sku] = int(needed.get(sku, 0)) + 1
		var available := true
		for sku in needed:
			var missing := maxi(0, int(needed[sku]) - sim.stock(sku))
			var supplier: int = int(sim.product_state(int(sku)).get("supplier", Catalog.DEFAULT_SUPPLIER))
			if missing > 0 and not allow_preorders and (not Supply.supplier_unlocked(sim.state, supplier) or not Catalog.SUPPLIERS[supplier].direct):
				available = false
				break
		if not available:
			totals.stockouts += 1
			return 0
		basket = [product]
		basket.append_array(proposed)
		reference_prices = [price]
		reference_prices.append_array(references)
		var subtotal := 0
		for reference in reference_prices:
			subtotal += int(reference)
		total = int(offer.get("price", 0))
		if total <= 0:
			total = maxi(1, roundi(float(subtotal) * (1.0 - float(offer.discount) / 100.0)))
		else:
			total = maxi(1, total)
		kind = "bundles" if mode == 1 else "upsells"
		break
	var final_counts := {}
	for sku in basket:
		final_counts[sku] = int(final_counts.get(sku, 0)) + 1
	var allow_preorders_for_basket := true
	for sku in final_counts:
		var missing := maxi(0, int(final_counts[sku]) - sim.stock(sku))
		var sku_listing: Dictionary = {}
		if missing > 0:
			sku_listing = Stores.listing(sim.state, store_id, int(sku)) if store_id >= 0 else {}
			allow_preorders_for_basket = allow_preorders_for_basket and sku_listing.get("allow_preorders", false) == true
		var supplier: int = int(sim.product_state(int(sku)).get("supplier", Catalog.DEFAULT_SUPPLIER))
		if missing > 0 and not sku_listing.get("allow_preorders", false) and (not Supply.supplier_unlocked(sim.state, supplier) or not Catalog.SUPPLIERS[supplier].direct):
			totals.stockouts += 1
			return 0
	for i in range(1, basket.size()):
		var sku: int = basket[i]
		row.demand[sku] = row.demand.get(sku, 0) + 1
	var prices := allocate(total, reference_prices)
	return Fulfillment.place(sim, channel, basket, total, kind, prices, store_id, campaign_id, allow_preorders_for_basket)

static func offer_uptake(mode: int, discount: int) -> float:
	return (0.45 if mode == 1 else 0.22) + float(discount) / 200.0

static func repeat_product(value: Variant, count: int) -> Array:
	var result: Array = []
	for _i in count:
		result.append(value)
	return result

static func allocate(total: int, weights: Array) -> Array:
	var sum := 0
	for weight in weights:
		sum += int(weight)
	var result: Array = []
	var cumulative_weight := 0
	var previous := 0
	for i in weights.size():
		cumulative_weight += int(weights[i])
		var cumulative := total if i == weights.size() - 1 else roundi(float(total) * cumulative_weight / sum)
		result.append(cumulative - previous)
		previous = cumulative
	return result
