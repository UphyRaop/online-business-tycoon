extends RefCounted

const Catalog = preload("res://catalog.gd")
const MARKET_SETUP := 0.0
const MARKETPLACES := ["Shopee", "TikTok Shop", "Lazada", "SHEIN"]
const MARKET_FEES := [12.0, 13.0, 11.0, 14.0]
const WEBSITE_SETUP := 45.0
const MARKET_DAILY := 2.0
const WEBSITE_DAILY := 4.0
const WEBSITE_PLATFORMS := [
	{"id": "shopify", "name": "Shopify", "setup": 60.0, "daily": 5.5, "fee_bps": 290, "feature": "Integrated storefront tools", "traffic": 1.04, "conversion": 1.02},
	{"id": "woocommerce", "name": "WooCommerce", "setup": 35.0, "daily": 3.5, "fee_bps": 340, "feature": "Flexible store configuration", "traffic": 0.98, "conversion": 1.05},
	{"id": "wix", "name": "Wix", "setup": 45.0, "daily": 4.0, "fee_bps": 320, "feature": "Visual site building", "traffic": 1.02, "conversion": 1.0},
	{"id": "squarespace", "name": "Squarespace", "setup": 55.0, "daily": 4.5, "fee_bps": 300, "feature": "Design-focused storefront", "traffic": 0.95, "conversion": 1.08},
]
const LEGACY_WEBSITE_FEE_BPS := 400
const ACTIVITY_FIELDS := ["sales", "refunds", "cogs", "fees", "shipping", "advertising", "setup", "operating", "orders"]

static func migration_defaults(state: Dictionary) -> Array:
	var brand: String = str(state.get("brand", state.get("company", "My Brand")))
	var website_name := brand + " Website"
	var marketplace_name := str(state.get("store", "")).strip_edges()
	if marketplace_name.is_empty():
		marketplace_name = str(state.get("company", "Marketplace Store")) + " Marketplace"
	return [
		{"id": 0, "name": marketplace_name, "type": 0,
			"brand": brand, "domain": "", "platform": -1, "website_platform": "", "website_fee_bps": 0,
			"active": int(state.get("channel", 0)) in [0, 2],
			"legacy": true, "created": 1, "setup_cost": 0, "daily_cost": 0, "listings": {}, "offers": {}},
		{"id": 1, "name": website_name, "type": 1, "brand": brand, "website_platform": "legacy", "website_fee_bps": LEGACY_WEBSITE_FEE_BPS,
			"domain": str(state.get("website_domain", "my-business.shop")),
			"active": state.get("website_active", int(state.get("channel", 0)) != 0),
			"legacy": true, "created": 1, "setup_cost": 0, "daily_cost": 0, "listings": {}, "offers": {}},
	]

static func website_platform_index(platform_id: String) -> int:
	for i in WEBSITE_PLATFORMS.size():
		if WEBSITE_PLATFORMS[i].id == platform_id: return i
	return -1

static func setup_cost(country: int, kind: int, website_platform: int = -1) -> int:
	if kind == 0: return Catalog.local_cents(country, MARKET_SETUP)
	if website_platform in range(WEBSITE_PLATFORMS.size()):
		return Catalog.local_cents(country, WEBSITE_PLATFORMS[website_platform].setup)
	return Catalog.local_cents(country, WEBSITE_SETUP)

static func daily_cost(country: int, kind: int, website_platform: int = -1) -> int:
	if kind == 0: return Catalog.local_cents(country, MARKET_DAILY)
	if website_platform in range(WEBSITE_PLATFORMS.size()):
		return Catalog.local_cents(country, WEBSITE_PLATFORMS[website_platform].daily)
	return Catalog.local_cents(country, WEBSITE_DAILY)

static func create(state: Dictionary, name: String, kind: int, brand: String, domain: String = "", platform: int = 0, website_platform: int = -1) -> String:
	name = name.strip_edges()
	brand = brand.strip_edges()
	domain = domain.strip_edges().to_lower()
	if kind not in [0, 1] or name.is_empty() or brand.is_empty():
		return "Enter a store name and brand, then choose Marketplace or Website."
	if kind == 1 and domain.is_empty():
		return "Enter a simulated website domain."
	if kind == 0 and platform not in range(MARKETPLACES.size()):
		return "Choose a marketplace."
	if kind == 1 and website_platform not in range(WEBSITE_PLATFORMS.size()):
		return "Choose a website platform."
	for existing in state.stores:
		if existing.name.to_lower() == name.to_lower():
			return "Store names must be unique."
		if kind == 1 and existing.type == 1 and existing.domain.to_lower() == domain:
			return "Website domains must be unique."
	var cost := setup_cost(state.country, kind, website_platform)
	if state.cash < cost:
		return "Insufficient company cash for this store's setup cost."
	var id: int = state.next_store
	state.next_store += 1
	var store := {
		"id": id, "name": name, "type": kind, "brand": brand,
		"domain": domain if kind == 1 else "", "platform": platform if kind == 0 else -1,
		"website_platform": WEBSITE_PLATFORMS[website_platform].id if kind == 1 else "",
		"website_fee_bps": int(WEBSITE_PLATFORMS[website_platform].fee_bps) if kind == 1 else 0,
		"active": true, "legacy": false,
		"created": state.day, "setup_cost": cost, "daily_cost": daily_cost(state.country, kind, website_platform),
		"listings": {}, "offers": {},
	}
	state.stores.append(store)
	state.cash -= cost
	var row: Dictionary = state.ledger.back()
	row.store_setup += cost
	var activity := store_activity(row, id)
	activity.setup += cost
	row.store_activity[id] = activity
	return ""

static func store_fee(store: Dictionary, channel: int, total: int) -> int:
	var platform: int = store.get("platform", -1)
	if channel == 0 and platform in range(MARKET_FEES.size()):
		return roundi(total * MARKET_FEES[platform] / 100.0)
	if channel == 1:
		return roundi(total * int(store.get("website_fee_bps", LEGACY_WEBSITE_FEE_BPS)) / 10000.0)
	return Catalog.fee(channel, total)

static func traffic_multiplier(store: Dictionary) -> float:
	if int(store.get("type", -1)) != 1: return 1.0
	var index := website_platform_index(str(store.get("website_platform", "legacy")))
	return float(WEBSITE_PLATFORMS[index].traffic) if index >= 0 else 1.0

static func conversion_multiplier(store: Dictionary) -> float:
	if int(store.get("type", -1)) != 1: return 1.0
	var index := website_platform_index(str(store.get("website_platform", "legacy")))
	return float(WEBSITE_PLATFORMS[index].conversion) if index >= 0 else 1.0

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
		"product_id": Catalog.product_id(product),
		"price": Catalog.local_cents(state.country, Catalog.PRODUCTS[product].cost * 2.7),
		"listed": false, "channel_mask": 3, "supplier": Catalog.DEFAULT_SUPPLIER, "supplier_id": Catalog.supplier_id(Catalog.DEFAULT_SUPPLIER), "lots": [],
	})
	if store.legacy:
		var overrides: Dictionary = store.get("listings", {})
		if overrides.has(product):
			var override: Dictionary = overrides[product]
			return {"price": int(override.price), "listed": override.listed == true,
				"channel_mask": 1 << channel(store), "product": product,
				"product_id": Catalog.product_id(product), "allow_preorders": override.get("allow_preorders", false) == true}
		var channel_id := channel(store)
		var channel_allowed: bool = (int(base.get("channel_mask", 3)) & (1 << channel_id)) != 0
		return {"price": base.price, "listed": base.listed and channel_allowed,
			"channel_mask": int(base.get("channel_mask", 3)), "product": product,
			"product_id": Catalog.product_id(product), "allow_preorders": false}
	var listings: Dictionary = store.listings
	var detail: Dictionary = listings.get(product, {})
	return {"price": int(detail.get("price", base.price)), "listed": detail.get("listed", false) == true,
		"channel_mask": 1 << channel(store), "product": product,
		"product_id": Catalog.product_id(product), "allow_preorders": detail.get("allow_preorders", false) == true}

static func set_listing(state: Dictionary, store_id: int, product: int, price: int, listed: bool, allow_preorders: Variant = null) -> String:
	if product not in range(Catalog.PRODUCTS.size()) or price < 1:
		return "Choose a catalog product and a selling price above zero."
	var index := index_of(state, store_id)
	if index < 0:
		return "Store not found."
	var store: Dictionary = state.stores[index]
	if store.legacy:
		var legacy_listings: Dictionary = store.get("listings", {})
		var previous: Dictionary = legacy_listings.get(product, {})
		legacy_listings[product] = {"price": price, "listed": listed,
			"product_id": Catalog.product_id(product),
			"allow_preorders": previous.get("allow_preorders", false) if allow_preorders == null else allow_preorders == true}
		store.listings = legacy_listings
		state.stores[index] = store
	else:
		var listings: Dictionary = store.listings
		var detail: Dictionary = listings.get(product, {"price": price, "listed": false})
		detail.price = price
		detail.listed = listed
		detail.product_id = Catalog.product_id(product)
		if allow_preorders != null:
			detail.allow_preorders = allow_preorders == true
		elif not detail.has("allow_preorders"):
			detail.allow_preorders = false
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

static func report(state: Dictionary, store_id: int, end_day: int = 0, start_day: int = 1) -> Dictionary:
	# Day `state.day` has not been completed yet. Store reports use only closed
	# ledger days, even if a caller explicitly requests the current day.
	var last := mini(end_day if end_day > 0 else int(state.day) - 1, int(state.day) - 1)
	var totals := {}
	for field in ACTIVITY_FIELDS:
		totals[field] = 0
	var first := maxi(1, start_day)
	if last < first:
		return totals
	for i in range(first - 1, last):
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
