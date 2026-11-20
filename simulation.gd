extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Storefront = preload("res://storefront.gd")
const Calendar = preload("res://game_calendar.gd")
const Stores = preload("res://store_manager.gd")
const Advertising = preload("res://advertising.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
const PERIODS := [1, 7, 30, 365]
const FIELDS := ["sales", "cogs", "direct_cogs", "fees", "overhead", "hosting", "legacy", "purchases", "credit_purchases", "credit_inbound_freight", "supplier_repayments", "supplier_credit_adjustments", "direct_purchases", "direct_inbound_freight", "capital", "shipping", "refunds", "deposits", "advertising", "store_setup", "store_expenses", "inventory_returns", "supplier_refunds", "dev_cash_adjustment", "dev_inventory_adjustment"]
const CHANNEL_FIELDS := ["orders", "sales", "cogs", "fees", "hosting", "shipping", "refunds",
	"placed", "dispatched", "tracked_deliveries", "on_time", "checkouts", "abandoned", "stockouts", "bundles", "upsells", "refunded"]
const VERSION := 6

var state: Dictionary

func _init(data: Dictionary) -> void:
	state = data

static func register(owner: String, company: String, store: String, country: int,
		difficulty: int, channel: int, seed_value: int) -> Dictionary:
	if company.strip_edges().is_empty() or country not in range(Catalog.COUNTRIES.size()) or difficulty not in range(Catalog.DIFFICULTIES.size()) or channel not in range(Catalog.CHANNELS.size()):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var opening := entry()
	opening.capital = Catalog.local_cents(country, Catalog.CAPITAL[difficulty])
	var data := {
		"version": 1, "owner": owner, "company": company, "store": store,
		"company_id": _new_company_id(owner, company, country, seed_value),
		"brand": company.strip_edges(), "website_domain": _domain_for(company), "website_active": false,
		"country": country, "difficulty": difficulty, "channel": channel,
		"day": 1, "cash": opening.capital, "seed": rng.state,
		"products": {}, "ledger": [opening],
	}
	data.stores = []
	upgrade(data)
	return data

static func upgrade(data: Dictionary) -> void:
	if not data.get("owner") is String:
		data.owner = ""
	if not data.has("brand") or not data.get("brand") is String or str(data.brand).strip_edges().is_empty():
		data.brand = str(data.get("company", "My Online Business"))
	if not data.has("website_domain") or not data.get("website_domain") is String or str(data.website_domain).strip_edges().is_empty():
		data.website_domain = _domain_for(str(data.get("brand", data.get("company", "my-store"))))
	if not data.has("website_active") or not data.get("website_active") is bool:
		data.website_active = int(data.get("channel", 0)) != 0
	var old_version: int = int(data.get("version", 0))
	if old_version not in [1, 2, 3, 4, 5, VERSION]:
		return
	if not data.get("ledger") is Array:
		return
	if not data.get("company_id") is String or str(data.company_id).is_empty():
		data.company_id = _legacy_company_id(data)
	for row in data.ledger:
		if not row is Dictionary or not row.get("channels") is Array:
			return
		for channel in row.channels:
			if not channel is Dictionary:
				return
	if old_version == 1:
		data.merge({
			"inbound": [], "quotes": {}, "next_purchase": 1, "orders": {}, "active_orders": [],
			"next_order": 1, "open_cases": [], "shipping": 1, "auto_dispatch": true,
			"satisfaction": 80, "reputation": 70, "offers": {},
		}, true)
	for row in data.get("ledger", []):
		row.merge(entry())
		for channel in row.channels:
			for field in CHANNEL_FIELDS:
				if not channel.has(field):
					channel[field] = 0
	if not data.get("supplier_returns") is Array:
		data.supplier_returns = []
	if not data.get("next_supplier_return") is int or int(data.next_supplier_return) < 1:
		data.next_supplier_return = 1
	if not data.get("stores") is Array:
		data.stores = []
		if int(data.get("channel", 0)) in [0, 2]:
			var legacy_market: Dictionary = Stores.migration_defaults(data)[0]
			legacy_market.active = true
			data.stores.append(legacy_market)
		if int(data.get("channel", 0)) in [1, 2]:
			var legacy_site: Dictionary = Stores.migration_defaults(data)[1]
			legacy_site.active = true
			data.stores.append(legacy_site)
	if not data.get("next_store") is int or data.next_store < 2:
		data.next_store = 2
	for store in data.get("stores", []):
		if not store is Dictionary: continue
		if not store.get("listings") is Dictionary: store.listings = {}
		if not store.get("offers") is Dictionary: store.offers = {}
		for product in store.listings:
			var listing: Dictionary = store.listings[product]
			if int(product) in range(Catalog.PRODUCTS.size()):
				listing.product_id = Catalog.product_id(int(product))
			if not listing.get("allow_preorders") is bool:
				listing.allow_preorders = false
			store.listings[product] = listing
		if int(store.get("type", -1)) == 1:
			if not store.has("website_platform"): store.website_platform = "legacy"
			if not store.has("website_fee_bps"): store.website_fee_bps = Stores.LEGACY_WEBSITE_FEE_BPS
		else:
			if not store.has("platform"): store.platform = -1 if store.get("legacy", false) else 0
			if not store.has("website_platform"): store.website_platform = ""
			if not store.has("website_fee_bps"): store.website_fee_bps = 0
	for product in data.get("offers", {}):
		data.offers[product] = Storefront.offers_for(data, product)
	for order in data.get("orders", {}).values():
		if not order.get("preorder") is bool:
			order.preorder = false
		if not order.get("preorder"):
			order.erase("preorder_status")
	Advertising.ensure_state(data)
	Supply.ensure_progress(data)
	Supply.migrate_references(data)
	SupplierCredit.ensure(data)
	data.version = VERSION
	data.catalog_schema_version = 1

static func _domain_for(name: String) -> String:
	var slug := name.to_lower().strip_edges().replace(" ", "-")
	var clean := ""
	for i in slug.length():
		var c := slug.substr(i, 1)
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-":
			clean += c
	while clean.contains("--"):
		clean = clean.replace("--", "-")
	clean = clean.trim_prefix("-").trim_suffix("-")
	return (clean if not clean.is_empty() else "my-business") + ".shop"

static func _new_company_id(owner: String, company: String, country: int, seed_value: int) -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return "company-%s" % bytes.hex_encode() if not bytes.is_empty() else "company-%s" % _stable_company_suffix("%s|%s|%d|%d|%d" % [owner, company, country, seed_value, Time.get_ticks_usec()])

static func _legacy_company_id(data: Dictionary) -> String:
	return "company-legacy-%s" % _stable_company_suffix("%s|%s|%d|%d" % [str(data.get("owner", "")).strip_edges().to_lower(), str(data.get("company", "")).strip_edges().to_lower(), int(data.get("country", 0)), int(data.get("seed", 0))])

static func _stable_company_suffix(value: String) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(value.to_utf8_buffer())
	return hasher.finish().hex_encode().substr(0, 32)

static func entry() -> Dictionary:
	var row := {"channels": [], "demand": {}, "inbound_freight": 0, "store_activity": {}}
	for field in FIELDS:
		row[field] = 0
	for channel in Catalog.CHANNELS:
		var totals := {}
		for field in CHANNEL_FIELDS:
			totals[field] = 0
		row.channels.append(totals)
	return row

func product_state(product: int) -> Dictionary:
	var fallback: Dictionary = {
		"product_id": Catalog.product_id(product),
		"supplier": Catalog.DEFAULT_SUPPLIER, "supplier_id": Catalog.supplier_id(Catalog.DEFAULT_SUPPLIER),
		"price": Catalog.local_cents(state.country, Catalog.PRODUCTS[product].cost * 2.7),
		"listed": false, "lots": [], "channel_mask": 3,
	}
	var result: Dictionary = state.products.get(product, fallback).duplicate(true)
	result.product_id = Catalog.product_id(product)
	return result

func channel_enabled(channel: int) -> bool:
	# A present stores array is authoritative. New registrations deliberately have
	# an empty array; legacy channel flags must not create phantom destinations.
	if state.get("stores") is Array:
		for store in state.stores:
			if int(store.get("type", -1)) == channel and store.get("active", false):
				return true
		return false
	var has_store_type := false
	for store in state.get("stores", []):
		if int(store.get("type", -1)) == channel:
			has_store_type = true
			if store.get("active", false):
				return true
	if has_store_type:
		return false
	if channel == 0:
		return state.channel == 0 or state.channel == 2
	return state.get("website_active", state.channel != 0)

func product_on_channel(item: Dictionary, channel: int) -> bool:
	return item.listed and channel_enabled(channel) and (int(item.get("channel_mask", 3)) & (1 << channel)) != 0

func product_on_store(store_id: int, product: int) -> bool:
	var store := Stores.get_store(state, store_id)
	if store.is_empty() or not store.active:
		return false
	return Stores.listing(state, store_id, product).get("listed", false) == true

func active_product_count() -> int:
	var count := 0
	for product in Catalog.PRODUCTS.size():
		if stock(product) <= 0:
			continue
		for store in state.stores:
			if product_on_store(int(store.id), product):
				count += 1
				break
	return count

func stock(product: int) -> int:
	var units := 0
	for lot in product_state(product).lots:
		units += lot.units
	return units

func unit_cost(product: int, supplier: int) -> Dictionary:
	var lots: Array = product_state(product).lots
	if not lots.is_empty():
		return cost_breakdown(lots[0], "Next FIFO unit")
	var incoming := {}
	for batch in state.inbound:
		if batch.product == product and (incoming.is_empty() or batch.arrival < incoming.arrival):
			incoming = batch
	if not incoming.is_empty():
		return cost_breakdown(incoming, "Next inbound unit")
	var freight := Catalog.inbound_freight(state.country, supplier)
	return cost_breakdown({"cost": Supply.quote(state, product, supplier).cost + freight, "freight": freight}, "Supplier quote")

static func cost_breakdown(lot: Dictionary, source: String) -> Dictionary:
	var freight: int = lot.get("freight", 0)
	return {"goods": lot.cost - freight, "freight": freight, "landed": lot.cost, "source": source}

func select_supplier(product: int, supplier: int) -> void:
	if not Catalog.supplier_available_for_sourcing(supplier): return
	var item := product_state(product)
	item.product_id = Catalog.product_id(product)
	item.supplier = supplier
	item.supplier_id = Catalog.supplier_id(supplier)
	state.products[product] = item

func buy(product: int, supplier: int, units: int) -> String:
	var result := Supply.purchase(state, product, supplier, units)
	if result.is_empty():
		select_supplier(product, supplier)
		SupplierCredit.record_upfront_purchase(state, supplier, int(state.next_purchase) - 1)
	return result

func return_stock(product: int, supplier: int, units: int) -> Dictionary:
	Fulfillment.allocate_preorders(self)
	return Supply.return_stock(state, product, supplier, units)

func add_stock(product: int, lot: Dictionary) -> void:
	var item := product_state(product)
	lot.product_id = Catalog.product_id(product)
	item.lots.append(lot)
	item.product_id = Catalog.product_id(product)
	state.products[product] = item

func reserve_unit(product: int) -> Dictionary:
	var lots: Array = state.products[product].lots
	var lot: Dictionary = lots.front()
	var unit := {"product": product, "product_id": Catalog.product_id(product), "cost": lot.cost, "quality": lot.quality, "freight": lot.get("freight", 0)}
	lot.units -= 1
	if lot.units == 0:
		lots.pop_front()
	return unit

func list_product(product: int, price: int, channel_mask: int = 3, listed: bool = true) -> void:
	var item := product_state(product)
	item.product_id = Catalog.product_id(product)
	item.price = price
	item.listed = listed
	item.channel_mask = channel_mask
	state.products[product] = item

func unlist(product: int) -> void:
	state.products[product].listed = false

func advance(days: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.state = state.seed
	for day_index in range(days):
		var row: Dictionary = state.ledger.back()
		Supply.receive(self)
		Fulfillment.allocate_preorders(self)
		Fulfillment.deliver(state, rng)
		Supply.ensure_progress(state)
		Service.tick(state)
		row.overhead = Catalog.local_cents(state.country, Catalog.OVERHEAD[state.difficulty])
		var has_legacy_website := false
		for store in state.stores:
			if store.legacy and store.type == 1 and store.active:
				has_legacy_website = true
		Stores.charge_daily(state)
		if has_legacy_website:
			row.hosting = Catalog.local_cents(state.country, Catalog.HOSTING)
			row.channels[1].hosting = row.hosting
		Stores.allocate_shared_costs(state, row.overhead, row.hosting)
		state.cash -= row.overhead + row.hosting
		Advertising.simulate_day(self, rng)
		var ordered_stores: Array = state.stores.duplicate()
		if not ordered_stores.is_empty():
			var first_store: int = state.day % ordered_stores.size()
			for offset in ordered_stores.size():
				var store: Dictionary = ordered_stores[(first_store + offset) % ordered_stores.size()]
				if not store.active:
					continue
				for product in Catalog.PRODUCTS.size():
					var item := Stores.listing(state, int(store.id), product)
					if not item.get("listed", false):
						continue
					if not row.demand.has(product): row.demand[product] = 0
					Storefront.run_product(self, product, item, Stores.channel(store), rng, int(store.id))
		Fulfillment.auto_dispatch(state, rng)
		state.day += 1
		state.ledger.append(entry())
		SupplierCredit.process_due(state)
	state.seed = rng.state

static func net(row: Dictionary) -> int:
	return row.sales - row.refunds - row.cogs - row.fees - row.overhead - row.hosting - row.shipping - row.legacy - row.get("advertising", 0) - row.get("store_setup", 0) - row.get("store_expenses", 0) + row.get("supplier_refunds", 0) - row.get("inventory_returns", 0)

static func cash_change(row: Dictionary) -> int:
	return net(row) + row.cogs - (row.purchases - row.get("credit_purchases", 0)) - row.get("direct_purchases", 0) - row.get("supplier_repayments", 0) - row.get("supplier_credit_adjustments", 0) + row.capital + row.deposits + row.get("inventory_returns", 0) + row.get("dev_cash_adjustment", 0)

func calendar_report(period: int, anchor: int) -> Dictionary:
	var boundaries := Calendar.bounds(period, clampi(anchor, 1, state.day))
	var end := mini(state.day, boundaries.y)
	return report(end - maxi(1, boundaries.x) + 1, end)

func report_completed(days: int, end_day: int = 0) -> Dictionary:
	var last_completed := int(state.get("day", 1)) - 1
	var requested_end := end_day if end_day > 0 else last_completed
	var end := mini(requested_end, last_completed)
	if end < 1:
		return _empty_completed_report()
	return report(mini(maxi(1, days), end), end)

func calendar_report_completed(period: int, anchor: int = 0) -> Dictionary:
	var last_completed := int(state.get("day", 1)) - 1
	if last_completed < 1:
		return _empty_completed_report()
	var requested_anchor := anchor if anchor > 0 else last_completed
	var boundaries := Calendar.bounds(period, clampi(requested_anchor, 1, last_completed))
	var start := maxi(1, boundaries.x)
	var end := mini(last_completed, boundaries.y)
	return report_completed(maxi(1, end - start + 1), end)

func _empty_completed_report() -> Dictionary:
	var result := entry()
	result.merge({
		"start": 0, "end": 0, "opening_cash": 0, "closing_cash": 0,
		"inventory": 0, "goods_in_transit": 0, "equity_capital": 0, "retained": 0,
		"assets": 0, "overdraft": 0, "customer_deposits": 0,
		"supplier_payables": 0, "payables": 0, "liabilities": 0,
	}, true)
	return result

func report(days: int, end_day: int = 0) -> Dictionary:
	var end := clampi(end_day if end_day > 0 else state.day, 1, state.day)
	var start := maxi(1, end - days + 1)
	var result := entry()
	var opening_cash := 0
	var inventory := 0
	var goods_in_transit := 0
	var capital := 0
	var retained := 0
	var deposits := 0
	for i in range(end):
		var row: Dictionary = state.ledger[i]
		inventory += row.purchases - (row.cogs - row.get("direct_cogs", 0)) - row.get("inventory_returns", 0) + row.get("dev_inventory_adjustment", 0)
		goods_in_transit += row.get("direct_purchases", 0) - row.get("direct_cogs", 0)
		capital += row.capital + row.get("dev_cash_adjustment", 0) + row.get("dev_inventory_adjustment", 0)
		retained += net(row)
		deposits += row.deposits
		if i < start - 1:
			opening_cash += cash_change(row)
			continue
		for field in FIELDS:
			result[field] += row[field]
		result.inbound_freight += row.get("inbound_freight", 0)
		for channel in result.channels.size():
			for field in CHANNEL_FIELDS:
				result.channels[channel][field] += row.channels[channel][field]
	result.start = start
	result.end = end
	result.opening_cash = opening_cash
	result.closing_cash = opening_cash + cash_change(result)
	result.inventory = inventory
	result.goods_in_transit = goods_in_transit
	result.equity_capital = capital
	result.retained = retained
	result.assets = maxi(0, result.closing_cash) + inventory + goods_in_transit
	result.overdraft = maxi(0, -result.closing_cash)
	result.customer_deposits = deposits
	result.supplier_payables = SupplierCredit.open_payables(state, -1, end)
	result.payables = result.supplier_payables
	result.liabilities = result.overdraft + result.customer_deposits + result.supplier_payables
	return result
