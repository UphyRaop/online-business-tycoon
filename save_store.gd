extends RefCounted

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Storefront = preload("res://storefront.gd")
const Advertising = preload("res://advertising.gd")
const Stores = preload("res://store_manager.gd")
const PATH := "user://business_phase1.save"
const PROTOTYPE := "user://business_save.json"

static func save(state: Dictionary, path: String = PATH, timestamp: float = 0) -> Error:
	if not valid(state):
		return ERR_INVALID_DATA
	var parent_path := ProjectSettings.globalize_path(path).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var pending := path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"state": state, "saved_at": timestamp} if timestamp > 0 else state)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result

	var target := ProjectSettings.globalize_path(path)
	var backup := target + ".bak"
	if FileAccess.file_exists(target):
		# Keep a known-good backup when recovering from a damaged primary.
		if read_file(target).is_empty():
			result = DirAccess.remove_absolute(target)
		else:
			result = DirAccess.rename_absolute(target, backup)
		if result != OK:
			return result
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(pending), target)

static func load_state(path: String = PATH, legacy_path: String = PROTOTYPE) -> Dictionary:
	var state := read_file(path)
	if state.is_empty():
		state = read_file(path + ".bak")
	if state.is_empty() and FileAccess.file_exists(legacy_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
		if parsed is Dictionary:
			state = migrate(parsed)
	return state

static func read_file(path: String) -> Dictionary:
	return read_record(path).get("state", {})

static func read_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 8:
		return {}
	if file.get_32() != file.get_length() - 4:
		return {}
	file.seek(0)
	var parsed: Variant = file.get_var(false)
	if parsed is Dictionary:
		var data: Variant = parsed.get("state", parsed)
		var saved_at: Variant = parsed.get("saved_at", FileAccess.get_modified_time(path))
		if data is Dictionary and (saved_at is float or saved_at is int) and is_finite(float(saved_at)) and saved_at >= 0:
			Sim.upgrade(data)
			if valid(data):
				return {"state": data, "saved_at": float(saved_at)}
	return {}

static func valid(state: Dictionary) -> bool:
	if state.get("version") != Sim.VERSION:
		return false
	for field in ["owner", "company", "company_id", "store", "brand", "website_domain"]:
		if not state.get(field) is String:
			return false
	if state.company_id.strip_edges().is_empty() or state.brand.strip_edges().is_empty() or state.website_domain.strip_edges().is_empty() or not state.get("website_active") is bool:
		return false
	for field in ["country", "difficulty", "channel", "day", "cash", "seed"]:
		if not state.get(field) is int:
			return false
	if state.country not in range(Catalog.COUNTRIES.size()) or state.difficulty not in range(3) or state.channel not in range(3):
		return false
	if not state.get("ledger") is Array or state.day < 1 or state.ledger.size() != state.day:
		return false
	var computed_cash := 0
	var inventory := 0
	var goods_in_transit := 0
	var deposits := 0
	for row in state.ledger:
		if not row is Dictionary or not row.get("channels") is Array or row.channels.size() != 3:
			return false
		if not row.get("demand") is Dictionary:
			return false
		for product in row.demand:
			if not valid_product(product) or not row.demand[product] is int or row.demand[product] < 0:
				return false
		for field in Sim.FIELDS:
			if not row.get(field) is int:
				return false
		var inbound_freight: Variant = row.get("inbound_freight", 0)
		if not inbound_freight is int or inbound_freight < 0 or inbound_freight > row.purchases + row.get("direct_purchases", 0):
			return false
		for channel in row.channels:
			if not channel is Dictionary:
				return false
			for field in Sim.CHANNEL_FIELDS:
				if not channel.get(field) is int:
					return false
		if not row.get("store_activity") is Dictionary:
			return false
		for store_id in row.store_activity:
			if not store_id is int or not row.store_activity[store_id] is Dictionary:
				return false
			for field in Stores.ACTIVITY_FIELDS:
				if not row.store_activity[store_id].get(field) is int:
					return false
		computed_cash += Sim.cash_change(row)
		var direct_cogs: int = row.get("direct_cogs", 0)
		var direct_purchases: int = row.get("direct_purchases", 0)
		var direct_freight: int = row.get("direct_inbound_freight", 0)
		if direct_cogs < 0 or direct_purchases < 0 or direct_freight < 0 or direct_freight > direct_purchases or int(row.get("inventory_returns", 0)) < 0 or int(row.get("supplier_refunds", 0)) < 0:
			return false
		inventory += row.purchases - (row.cogs - direct_cogs) - int(row.get("inventory_returns", 0))
		goods_in_transit += direct_purchases - direct_cogs
		if goods_in_transit < 0:
			return false
		deposits += row.deposits
	if not state.get("products") is Dictionary or computed_cash != state.cash:
		return false
	if not valid_supplier_returns(state):
		return false
	var stock_value := 0
	for product in state.products:
		var item: Variant = state.products[product]
		if not product is int or product not in range(Catalog.PRODUCTS.size()) or not item is Dictionary:
			return false
		if not item.get("listed") is bool or not item.get("price") is int or item.price < 1:
			return false
		if not item.get("channel_mask", 3) is int or item.get("channel_mask", 3) not in [1, 2, 3]:
			return false
		if not item.get("supplier") is int or item.supplier not in range(Catalog.SUPPLIERS.size()) or not item.get("lots") is Array:
			return false
		if item.get("supplier_id", "") != Catalog.supplier_id(item.supplier):
			return false
		for lot in item.lots:
			if not valid_lot(lot) or not lot.get("units") is int or lot.units < 1:
				return false
			stock_value += lot.units * lot.cost
	return valid_operations(state, inventory - stock_value, goods_in_transit, deposits)

static func valid_product(product: Variant) -> bool:
	return product is int and product in range(Catalog.PRODUCTS.size())

static func valid_lot(lot: Variant) -> bool:
	if not lot is Dictionary or not lot.get("cost") is int or lot.cost <= 0 or not lot.get("quality") is float or not is_finite(lot.quality):
		return false
	var freight: Variant = lot.get("freight", 0)
	return freight is int and freight >= 0 and freight < lot.cost

static func valid_store_offers(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for product in raw:
		if not valid_product(product) or not raw[product] is Dictionary: return false
		if not valid_offer_config(int(product), raw[product]): return false
	return true

static func valid_offer_config(product: int, raw: Dictionary) -> bool:
	var offers := Storefront._normalize_offers(raw)
	for mode in offers:
		var offer: Variant = offers[mode]
		if mode not in [1, 2] or not offer is Dictionary or int(offer.get("mode", 0)) != mode:
			return false
		if not offer.get("discount") is int or int(offer.discount) not in range(51) or not offer.get("enabled", true) is bool:
			return false
		if not offer.get("price", 0) is int or int(offer.get("price", 0)) < 0:
			return false
		if mode == 1:
			if not offer.get("quantity") is int or int(offer.quantity) not in range(2, 11): return false
		else:
			var items: Variant = offer.get("items", [])
			if not items is Array or items.is_empty() or items.size() > 2: return false
			for item in items:
				if not valid_product(item) or int(item) == product: return false
	return true

static func valid_supplier_returns(state: Dictionary) -> bool:
	if not state.get("supplier_returns") is Array or not state.get("next_supplier_return") is int or state.next_supplier_return < 1:
		return false
	var ids := {}
	var by_day := {}
	var maximum_id := 0
	for record in state.supplier_returns:
		if not record is Dictionary: return false
		for field in ["id", "day", "product", "supplier", "units", "original_purchase_cost", "landed_cost", "refund"]:
			if not record.get(field) is int: return false
		if record.id < 1 or record.day < 1 or record.day > state.day or not valid_product(record.product) or record.supplier < -1 or record.supplier >= Catalog.SUPPLIERS.size(): return false
		if record.units < 1 or record.original_purchase_cost < 1 or record.landed_cost < record.original_purchase_cost or record.refund < 0 or record.refund > record.original_purchase_cost / 2.0: return false
		if ids.has(record.id) or not record.get("supplier_name") is String or not record.get("date") is String or record.get("product_id") != Catalog.product_id(record.product): return false
		if record.supplier >= 0 and record.get("supplier_id") != Catalog.supplier_id(record.supplier): return false
		if record.supplier < 0 and record.get("supplier_id", "") != "": return false
		if not record.get("allocations") is Array or record.allocations.is_empty(): return false
		var units := 0
		var goods := 0
		var landed := 0
		var refund := 0
		for allocation in record.allocations:
			if not allocation is Dictionary: return false
			for field in ["units", "original_unit_cost", "landed_unit_cost", "freight_per_unit"]:
				if not allocation.get(field) is int: return false
			if allocation.units < 1 or allocation.original_unit_cost < 1 or allocation.landed_unit_cost < allocation.original_unit_cost or allocation.freight_per_unit != allocation.landed_unit_cost - allocation.original_unit_cost or not allocation.get("cost_fallback") is bool: return false
			units += allocation.units
			goods += allocation.units * allocation.original_unit_cost
			landed += allocation.units * allocation.landed_unit_cost
			refund += floori(float(allocation.original_unit_cost) * 0.5) * allocation.units
		if units != record.units or goods != record.original_purchase_cost or landed != record.landed_cost or refund != record.refund: return false
		ids[record.id] = true
		maximum_id = maxi(maximum_id, record.id)
		if not by_day.has(record.day): by_day[record.day] = {"cost": 0, "refund": 0}
		by_day[record.day].cost += record.landed_cost
		by_day[record.day].refund += record.refund
	if state.next_supplier_return <= maximum_id: return false
	for day in state.ledger.size():
		var values: Dictionary = by_day.get(day + 1, {"cost": 0, "refund": 0})
		if int(state.ledger[day].get("inventory_returns", 0)) != int(values.cost) or int(state.ledger[day].get("supplier_refunds", 0)) != int(values.refund): return false
	return true

static func valid_operations(state: Dictionary, committed_cost: int, goods_in_transit: int, deposits: int) -> bool:
	for field in ["inbound", "active_orders", "open_cases", "stores"]:
		if not state.get(field) is Array:
			return false
	for field in ["orders", "quotes", "offers"]:
		if not state.get(field) is Dictionary:
			return false
	for field in ["next_order", "next_purchase", "shipping", "satisfaction", "reputation", "next_store"]:
		if not state.get(field) is int:
			return false
	if not state.get("advertising") is Dictionary:
		return false
	if not state.get("supplier_level") is int or state.supplier_level not in range(1, 5):
		return false
	if not state.get("supplier_unlocks") is Array or not state.get("supplier_unlock_ids") is Array or not state.get("supplier_thresholds_usd") is Array or state.supplier_thresholds_usd.size() != 4:
		return false
	for supplier in state.supplier_unlocks:
		if not supplier is int or supplier not in range(Catalog.SUPPLIERS.size()):
			return false
	for supplier_id in state.supplier_unlock_ids:
		if not supplier_id is String or Catalog.supplier_index(supplier_id) < 0:
			return false
	for threshold in state.supplier_thresholds_usd:
		if not (threshold is int or threshold is float) or float(threshold) < 0 or not is_finite(float(threshold)):
			return false
	if state.next_order < 1 or state.next_purchase < 1 or state.shipping not in range(Catalog.SHIPPING.size()) or not state.get("auto_dispatch") is bool:
		return false
	if state.satisfaction not in range(101) or state.reputation not in range(101):
		return false
	var store_ids := {}
	for store in state.stores:
		if not store is Dictionary:
			return false
		for field in ["id", "type", "created", "setup_cost", "daily_cost"]:
			if not store.get(field) is int:
				return false
		for field in ["name", "brand", "domain", "website_platform"]:
			if not store.get(field) is String:
				return false
		if not store.get("website_fee_bps") is int or store.website_fee_bps < 0 or store.website_fee_bps > 2000:
			return false
		if not store.get("active") is bool or not store.get("legacy") is bool or not store.get("listings") is Dictionary or not valid_store_offers(store.get("offers", {})):
			return false
		if store.id < 0 or store_ids.has(store.id) or store.type not in [0, 1] or store.created < 1 or store.setup_cost < 0 or store.daily_cost < 0 or store.name.strip_edges().is_empty() or store.brand.strip_edges().is_empty():
			return false
		if store.type == 1 and store.domain.strip_edges().is_empty():
			return false
		if store.type == 1 and store.website_platform != "legacy" and Stores.website_platform_index(store.website_platform) < 0:
			return false
		if store.type == 0 and not store.legacy and int(store.get("platform", -1)) not in range(Stores.MARKETPLACES.size()):
			return false
		store_ids[store.id] = true
		for product in store.listings:
			var listing: Variant = store.listings[product]
			if not valid_product(product) or not listing is Dictionary or not listing.get("price") is int or listing.price < 1 or not listing.get("listed") is bool:
				return false
			if listing.get("allow_preorders", false) is not bool:
				return false
	if state.next_store <= 0 or (not store_ids.is_empty() and state.next_store <= store_ids.keys().max()):
		return false
	if not valid_advertising(state):
		return false
	var inbound_ids := {}
	for batch in state.inbound:
		if not valid_lot(batch) or not valid_product(batch.get("product")):
			return false
		for field in ["id", "supplier", "units", "eta", "arrival"]:
			if not batch.get(field) is int:
				return false
		if batch.id < 1 or batch.id >= state.next_purchase or inbound_ids.has(batch.id) or batch.units < 1 or batch.eta > batch.arrival:
			return false
		if batch.supplier not in range(Catalog.SUPPLIERS.size()) or not batch.get("delayed") is bool:
			return false
		if batch.get("supplier_id", "") != Catalog.supplier_id(batch.supplier) or batch.get("supplier_name", "") != Catalog.SUPPLIERS[batch.supplier].name:
			return false
		inbound_ids[batch.id] = true
		committed_cost -= batch.units * batch.cost
	var active := {}
	var cases := {}
	var direct_commitments := 0
	for id in state.orders:
		var order: Variant = state.orders[id]
		if not id is int or id < 1 or id >= state.next_order or not valid_order(order, id):
			return false
		var order_store: int = int(order.get("store_id", order.channel))
		if not store_ids.has(order_store):
			return false
		var campaign_id: int = int(order.get("campaign_id", 0))
		if campaign_id > 0 and not state.advertising.campaigns.has(campaign_id):
			return false
		if order.case_status == "open":
			cases[id] = true
		if order.status in ["delivered", "cancelled"]:
			continue
		active[id] = true
		deposits -= order.total
		for item in order.items:
			if item.has("direct_supplier"):
				direct_commitments += item.cost
			else:
				committed_cost -= item.cost
	if committed_cost != 0 or goods_in_transit != direct_commitments or deposits != 0 or not matches_ids(active, state.active_orders) or not matches_ids(cases, state.open_cases):
		return false
	for product in state.offers:
		if not valid_product(product) or not state.offers[product] is Dictionary:
			return false
		var offers := Storefront.offers_for(state, product)
		for mode in offers:
			var offer: Variant = offers[mode]
			if mode not in [1, 2] or not offer is Dictionary or offer.get("mode") != mode:
				return false
			if not offer.get("discount") is int or offer.discount not in range(51) or not offer.get("enabled", true) is bool:
				return false
			if not offer.get("price", 0) is int or offer.get("price", 0) < 0:
				return false
			if mode == 1:
				if not offer.get("quantity") is int or offer.quantity not in range(2, 11):
					return false
			else:
				var add_ons: Variant = offer.get("items", [])
				if not add_ons is Array or add_ons.is_empty() or add_ons.size() > 2:
					return false
				for add_on in add_ons:
					if not valid_product(add_on) or add_on == product:
						return false
	for product in state.quotes:
		if not valid_product(product) or not state.quotes[product] is Dictionary:
			return false
		for supplier in state.quotes[product]:
			var quote: Variant = state.quotes[product][supplier]
			if not supplier is int or supplier not in range(Catalog.SUPPLIERS.size()) or not quote is Dictionary:
				return false
			for field in ["cost", "minimum", "expires", "discount"]:
				if not quote.get(field) is int or quote[field] < 1:
					return false
	return true

static func valid_advertising(state: Dictionary) -> bool:
	var ads: Dictionary = state.advertising
	for field in ["campaigns", "visitors", "conversions"]:
		if not ads.get(field) is Dictionary:
			return false
	if not ads.get("history") is Array or not ads.get("next_campaign") is int or ads.next_campaign < 1:
		return false
	for id in ads.campaigns:
		var campaign: Variant = ads.campaigns[id]
		if not id is int or id < 1 or id >= ads.next_campaign or not campaign is Dictionary or campaign.get("id") != id:
			return false
		for field in ["platform", "store_id", "channel", "product", "objective", "daily_budget", "start_day", "end_day", "audience", "bid_strategy", "bid", "creative", "created"]:
			if not campaign.get(field) is int:
				return false
		if not campaign.get("name") is String or not campaign.get("status") in ["draft", "active", "paused", "stopped", "completed"] or not campaign.get("learning") is float or not campaign.get("deleted") is bool:
			return false
		var store := Stores.get_store(state, campaign.store_id)
		if store.is_empty() or campaign.platform not in range(Advertising.PLATFORMS.size()) or not Advertising.platform_available(state.country, campaign.platform, store):
			return false
		if not valid_product(campaign.product) or campaign.objective not in range(Advertising.OBJECTIVES.size()) or campaign.audience not in range(Advertising.AUDIENCES.size()) or campaign.bid_strategy not in range(Advertising.BIDS.size()) or campaign.creative not in range(Advertising.CREATIVES.size()):
			return false
		if campaign.daily_budget < 1 or campaign.bid < 0 or campaign.start_day < 1 or campaign.created < 1 or campaign.learning < 0.8 or campaign.learning > 1.25 or (campaign.end_day > 0 and campaign.end_day < campaign.start_day):
			return false
	for record in ads.history:
		if not record is Dictionary or not record.get("campaign_id") is int or not record.get("day") is int or not ads.campaigns.has(record.campaign_id) or record.day < 1 or record.day > state.day:
			return false
		for field in Advertising.METRIC_FIELDS + ["estimated_profit"]:
			if not record.get(field) is int:
				return false
		for field in Advertising.METRIC_FIELDS:
			if field != "estimated_profit" and record[field] < 0:
				return false
	for field in ["visitors", "conversions"]:
		for store_id in ads[field]:
			if not store_id is int or not store_ids_for(state).has(store_id) or not ads[field][store_id] is int or ads[field][store_id] < 0:
				return false
	return true

static func store_ids_for(state: Dictionary) -> Dictionary:
	var ids := {}
	for store in state.stores:
		ids[store.id] = true
	return ids

static func matches_ids(expected: Dictionary, ids: Array) -> bool:
	if expected.size() != ids.size():
		return false
	for id in ids:
		if not expected.erase(id):
			return false
	return true

static func valid_order(order: Variant, id: int) -> bool:
	if not order is Dictionary or order.get("id") != id or not order.get("items") is Array or order.items.is_empty():
		return false
	for field in ["total", "channel", "placed", "method", "promise", "shipped", "eta", "arrival", "delivered", "case_day"]:
		if not order.get(field) is int:
			return false
	for field in ["delayed", "return_requested", "restockable", "escalated", "refunded"]:
		if not order.get(field) is bool:
			return false
	if order.total < 1 or order.channel not in [0, 1] or order.method not in range(Catalog.SHIPPING.size()):
		return false
	if order.get("status") not in ["queued", "shipped", "delivered", "cancelled"] or order.get("case_status") not in ["", "open", "resolved", "declined", "refunded"] or not order.get("reason") is String:
		return false
	if not order.get("preorder", false) is bool:
		return false
	if order.get("preorder", false) and (order.get("preorder_status") not in ["awaiting_stock", "stock_allocated", "ready_for_fulfillment", "shipped", "delivered", "cancelled"] or not order.get("expected_restock") is int or not order.get("fulfillment_delay") is int or order.expected_restock < 0 or order.fulfillment_delay < 0):
		return false
	var priced_lines := 0
	var order_revenue := 0
	for item in order.items:
		var waiting_stock: bool = bool(order.get("preorder", false)) and bool(item.get("awaiting_stock", false))
		if waiting_stock:
			if item.get("cost") != 0 or not valid_product(item.get("product")):
				return false
		elif not valid_lot(item) or not valid_product(item.get("product")):
			return false
		if item.has("direct_supplier"):
			var direct_supplier: Variant = item.direct_supplier
			if not direct_supplier is int or direct_supplier not in range(Catalog.SUPPLIERS.size()) or not Catalog.SUPPLIERS[direct_supplier].direct:
				return false
			if item.get("direct_supplier_id", "") != Catalog.supplier_id(direct_supplier):
				return false
			if not item.get("direct_supplier_name", "") is String or not item.get("supplier_lead", 0) is int or not item.get("supplier_reliability", -1.0) is float:
				return false
		if item.has("revenue") and (not item.revenue is int or item.revenue < 0 or item.revenue > order.total):
			return false
		if item.has("revenue"):
			priced_lines += 1
			order_revenue += item.revenue
	if priced_lines > 0 and (priced_lines != order.items.size() or order_revenue != order.total):
		return false
	for field in ["shipping_cost", "channel_fee"]:
		if order.has(field) and (not order[field] is int or order[field] < 0):
			return false
	return true

static func migrate(old: Dictionary) -> Dictionary:
	if not old.get("history") is Array or not old.get("listings") is Array:
		return {}
	var country := int(legacy_number(old.get("country"), -1))
	var difficulty := int(legacy_number(old.get("difficulty"), -1))
	var channel := int(legacy_number(old.get("channel"), -1))
	if country not in range(Catalog.COUNTRIES.size()) or difficulty not in range(3) or channel not in range(3):
		return {}
	var company := str(old.get("company", "My Online Store"))
	var data := Sim.register(str(old.get("owner", "")), company, company, country, difficulty, channel, randi())
	data.website_active = channel != 0
	data.stores = Stores.migration_defaults(data)
	var sim := Sim.new(data)
	data.ledger[0].capital = roundi(legacy_number(old.get("initial_cash")) * 100)
	data.cash = data.ledger[0].capital
	for past in old.history:
		if not past is Dictionary:
			return {}
		var row: Dictionary = data.ledger.back()
		row.sales = roundi(legacy_number(past.get("revenue")) * 100)
		row.legacy = roundi(legacy_number(past.get("costs")) * 100)
		row.channels[channel].sales = row.sales
		row.channels[channel].orders = int(legacy_number(past.get("orders")))
		data.cash += Sim.cash_change(row) - row.capital
		data.day += 1
		data.ledger.append(Sim.entry())
	for listing in old.listings:
		if not listing is Dictionary:
			return {}
		var product := int(legacy_number(listing.get("product"), -1))
		var supplier := int(legacy_number(listing.get("supplier"), -1))
		if product in range(Catalog.PRODUCTS.size()) and supplier in range(Catalog.SUPPLIERS.size()):
			sim.select_supplier(product, supplier)
			sim.list_product(product, maxi(1, roundi(legacy_number(listing.get("price"), 1) * 100)))
	return data if valid(data) else {}

static func legacy_number(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float or (value is String and value.is_valid_float()):
		var number := float(value)
		if is_finite(number):
			return number
	return fallback
