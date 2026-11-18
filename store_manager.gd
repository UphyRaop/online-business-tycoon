extends RefCounted

const Catalog = preload("res://catalog.gd")
const MARKET_SETUP := 120.0
const WEBSITE_SETUP := 45.0
const MARKET_DAILY := 2.0
const WEBSITE_DAILY := 4.0
const ACTIVITY_FIELDS := ["sales", "refunds", "cogs", "fees", "shipping", "advertising", "setup", "operating", "orders"]

static func migration_defaults(state: Dictionary) -> Array:
	var brand: String = str(state.get("brand", state.get("company", "My Brand")))
	var website_name := brand + " Website"
	return [
		{"id": 0, "name": str(state.get("store", "Marketplace Store")), "type": 0,
			"brand": brand, "domain": "", "active": int(state.get("channel", 0)) in [0, 2],
			"legacy": true, "created": 1, "setup_cost": 0, "daily_cost": 0, "listings": {}},
		{"id": 1, "name": website_name, "type": 1, "brand": brand,
			"domain": str(state.get("website_domain", "my-business.shop")),
			"active": state.get("website_active", int(state.get("channel", 0)) != 0),
			"legacy": true, "created": 1, "setup_cost": 0, "daily_cost": 0, "listings": {}},
	]

static func setup_cost(country: int, kind: int) -> int:
	return Catalog.local_cents(country, MARKET_SETUP if kind == 0 else WEBSITE_SETUP)

static func daily_cost(country: int, kind: int) -> int:
	return Catalog.local_cents(country, MARKET_DAILY if kind == 0 else WEBSITE_DAILY)

static func create(state: Dictionary, name: String, kind: int, brand: String, domain: String = "") -> String:
	name = name.strip_edges()
	brand = brand.strip_edges()
	domain = domain.strip_edges().to_lower()
	if kind not in [0, 1] or name.is_empty() or brand.is_empty():
		return "Enter a store name and brand, then choose Marketplace or Own Website."
	if kind == 1 and domain.is_empty():
		return "Enter a simulated website domain."
	var cost := setup_cost(state.country, kind)
	if state.cash < cost:
		return "Insufficient company cash for this store's setup cost."
	var id: int = state.next_store
	state.next_store += 1
	var store := {
		"id": id, "name": name, "type": kind, "brand": brand,
		"domain": domain if kind == 1 else "", "active": true, "legacy": false,
		"created": state.day, "setup_cost": cost, "daily_cost": daily_cost(state.country, kind),
		"listings": {},
	}
	state.stores.append(store)
	state.cash -= cost
	var row: Dictionary = state.ledger.back()
	row.store_setup += cost
	var activity := store_activity(row, id)
	activity.setup += cost
	row.store_activity[id] = activity
	return ""

static func set_active(state: Dictionary, store_id: int, enabled: bool) -> String:
	var index := index_of(state, store_id)
	if index < 0:
		return "Store not found."
	state.stores[index].active = enabled
	var store: Dictionary = state.stores[index]
	if store.legacy and store.type == 1:
		state.website_active = enabled
	return ""

static func sync_legacy(state: Dictionary) -> void:
	for i in state.stores.size():
		var store: Dictionary = state.stores[i]
		if not store.legacy:
			continue
		if store.type == 0:
			store.name = str(state.store)
			store.brand = str(state.brand)
		else:
			store.name = str(state.brand) + " Website"
			store.brand = str(state.brand)
			store.domain = str(state.website_domain)
		state.stores[i] = store

static func sync_legacy_channels(state: Dictionary) -> void:
	for i in state.stores.size():
		var store: Dictionary = state.stores[i]
		if not store.legacy:
			continue
		store.active = state.channel in [0, 2] if store.type == 0 else state.website_active
		state.stores[i] = store

static func index_of(state: Dictionary, store_id: int) -> int:
	for i in state.stores.size():
		if state.stores[i].id == store_id:
			return i
	return -1

static func get_store(state: Dictionary, store_id: int) -> Dictionary:
	var index := index_of(state, store_id)
	return state.stores[index] if index >= 0 else {}

static func channel(store: Dictionary) -> int:
	return int(store.type)

static func listing(state: Dictionary, store_id: int, product: int) -> Dictionary:
	var store := get_store(state, store_id)
	if store.is_empty():
		return {}
	var base: Dictionary = state.products.get(product, {
		"price": Catalog.local_cents(state.country, Catalog.PRODUCTS[product].cost * 2.7),
		"listed": false, "channel_mask": 3, "supplier": 1, "lots": [],
	})
	if store.legacy:
		var overrides: Dictionary = store.get("listings", {})
		if overrides.has(product):
			var override: Dictionary = overrides[product]
			return {"price": int(override.price), "listed": override.listed == true,
				"channel_mask": 1 << channel(store), "product": product}
		var channel_id := channel(store)
		var channel_allowed: bool = (int(base.get("channel_mask", 3)) & (1 << channel_id)) != 0
		return {"price": base.price, "listed": base.listed and channel_allowed,
			"channel_mask": int(base.get("channel_mask", 3)), "product": product}
	var listings: Dictionary = store.listings
	var detail: Dictionary = listings.get(product, {})
	return {"price": int(detail.get("price", base.price)), "listed": detail.get("listed", false) == true,
		"channel_mask": 1 << channel(store), "product": product}

static func set_listing(state: Dictionary, store_id: int, product: int, price: int, listed: bool) -> String:
	if product not in range(Catalog.PRODUCTS.size()) or price < 1:
		return "Choose a catalog product and a selling price above zero."
	var index := index_of(state, store_id)
	if index < 0:
		return "Store not found."
	var store: Dictionary = state.stores[index]
	if store.legacy:
		var legacy_listings: Dictionary = store.get("listings", {})
		legacy_listings[product] = {"price": price, "listed": listed}
		store.listings = legacy_listings
		state.stores[index] = store
	else:
		var listings: Dictionary = store.listings
		var detail: Dictionary = listings.get(product, {"price": price, "listed": false})
		detail.price = price
		detail.listed = listed
		listings[product] = detail
		store.listings = listings
		state.stores[index] = store
	return ""

static func charge_daily(state: Dictionary) -> void:
	var row: Dictionary = state.ledger.back()
	for store in state.stores:
		if store.legacy or not store.active:
			continue
		var amount: int = int(store.daily_cost)
		if amount <= 0:
			continue
		state.cash -= amount
		row.store_expenses += amount
		var activity := store_activity(row, int(store.id))
		activity.operating += amount
		row.store_activity[store.id] = activity

static func allocate_shared_costs(state: Dictionary, overhead: int, hosting: int) -> void:
	var active_ids: Array[int] = []
	var websites: Array[int] = []
	for store in state.stores:
		if not store.active:
			continue
		active_ids.append(store.id)
		if store.type == 1:
			websites.append(store.id)
	if not active_ids.is_empty():
		var share := floori(float(overhead) / active_ids.size())
		var remainder := overhead - share * active_ids.size()
		for id in active_ids:
			var activity := store_activity(state.ledger.back(), id)
			activity.operating += share + (1 if remainder > 0 else 0)
			if remainder > 0:
				remainder -= 1
			state.ledger.back().store_activity[id] = activity
	if hosting > 0 and not websites.is_empty():
		var share := floori(float(hosting) / websites.size())
		var remainder := hosting - share * websites.size()
		for id in websites:
			var activity := store_activity(state.ledger.back(), id)
			activity.operating += share + (1 if remainder > 0 else 0)
			if remainder > 0:
				remainder -= 1
			state.ledger.back().store_activity[id] = activity

static func store_activity(row: Dictionary, store_id: int) -> Dictionary:
	var records: Dictionary = row.get("store_activity", {})
	if not records.has(store_id):
		var value := {}
		for field in ACTIVITY_FIELDS:
			value[field] = 0
		records[store_id] = value
		row.store_activity = records
	return records[store_id]

static func report(state: Dictionary, store_id: int, end_day: int = 0) -> Dictionary:
	var last := clampi(end_day if end_day > 0 else state.day - 1, 1, state.day)
	var totals := {}
	for field in ACTIVITY_FIELDS:
		totals[field] = 0
	for i in range(last):
		var activity: Dictionary = state.ledger[i].get("store_activity", {}).get(store_id, {})
		for field in ACTIVITY_FIELDS:
			totals[field] += int(activity.get(field, 0))
	return totals

static func incoming(state: Dictionary, product: int) -> int:
	var units := 0
	for batch in state.inbound:
		if batch.product == product:
			units += batch.units
	return units
