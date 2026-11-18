extends RefCounted

const Catalog = preload("res://catalog.gd")
const Stores = preload("res://store_manager.gd")
const Storefront = preload("res://storefront.gd")
const Calendar = preload("res://game_calendar.gd")
const Supply = preload("res://supply.gd")

const PLATFORMS := [
	{"name": "Meta Ads", "cpm": 8.0, "ctr": 2.3, "cart": 0.27, "checkout": 0.48, "purchase": 0.07, "competition": 1.08, "reach": 1.0},
	{"name": "Google Ads", "cpm": 12.0, "ctr": 4.1, "cart": 0.33, "checkout": 0.57, "purchase": 0.08, "competition": 1.2, "reach": 0.72},
	{"name": "TikTok Ads", "cpm": 5.5, "ctr": 1.9, "cart": 0.21, "checkout": 0.41, "purchase": 0.06, "competition": 0.95, "reach": 1.25},
	{"name": "Marketplace Sponsored Ads", "cpm": 10.0, "ctr": 3.4, "cart": 0.38, "checkout": 0.65, "purchase": 0.08, "competition": 1.28, "reach": 0.62},
	{"name": "Shopee Sponsored Ads", "cpm": 9.2, "ctr": 3.7, "cart": 0.39, "checkout": 0.66, "purchase": 0.09, "competition": 1.22, "reach": 0.68},
	{"name": "Lazada Sponsored Ads", "cpm": 9.8, "ctr": 3.3, "cart": 0.37, "checkout": 0.63, "purchase": 0.08, "competition": 1.25, "reach": 0.65},
]
const AUDIENCES := ["Broad", "Interest", "Demographic", "Retargeting", "Lookalike"]
const AUDIENCE_COST := [1.0, 1.12, 1.2, 1.42, 1.27]
const AUDIENCE_REACH := [1.0, 0.78, 0.58, 0.2, 0.62]
const AUDIENCE_CONVERSION := [0.82, 1.08, 1.15, 1.85, 1.42]
const OBJECTIVES := ["Awareness", "Traffic", "Conversions", "Sales"]
const OBJECTIVE_CLICK := [0.72, 1.3, 0.92, 0.8]
const OBJECTIVE_CONVERSION := [0.45, 0.62, 1.22, 1.55]
const BIDS := ["Lowest cost", "Cost cap", "Bid cap"]
const CREATIVES := ["Image", "Video", "Carousel", "Search text", "Product listing"]
const CREATIVE_CLICK := [1.0, 1.12, 1.08, 0.95, 1.0]
const CREATIVE_CONVERSION := [1.0, 0.88, 1.04, 1.1, 1.18]
const METRIC_FIELDS := ["spend", "impressions", "reach", "clicks", "add_to_cart", "checkouts", "purchases", "preorders", "preorders_cancelled", "attributed_revenue", "attributed_refunds", "estimated_costs", "estimated_costs_reversed"]

static func initial_state() -> Dictionary:
	return {"campaigns": {}, "next_campaign": 1, "history": [], "visitors": {}, "conversions": {}}

static func ensure_state(state: Dictionary) -> void:
	if not state.get("advertising") is Dictionary:
		state.advertising = initial_state()
	var ads: Dictionary = state.advertising
	ads.merge(initial_state())
	if not ads.get("campaigns") is Dictionary: ads.campaigns = {}
	if not ads.get("history") is Array: ads.history = []
	for record in ads.history:
		if not record is Dictionary: continue
		for field in METRIC_FIELDS:
			if not record.has(field): record[field] = 0
		if not record.has("estimated_profit"): record.estimated_profit = 0
	if not ads.get("visitors") is Dictionary: ads.visitors = {}
	if not ads.get("conversions") is Dictionary: ads.conversions = {}
	if not ads.get("next_campaign") is int or ads.next_campaign < 1: ads.next_campaign = 1
	state.advertising = ads

static func platform_available(country: int, platform: int, store: Dictionary) -> bool:
	if platform not in range(PLATFORMS.size()) or store.is_empty(): return false
	if platform == 3: return int(store.type) == 0
	if platform == 4: return int(store.type) == 0 and int(store.get("platform", -1)) == 0
	if platform == 5: return int(store.type) == 0 and int(store.get("platform", -1)) == 2
	# Mainland China blocks Meta and TikTok ad inventory in this simulation.
	if country == 5 and platform in [0, 2]: return false
	return true

static func effective_cpm(state: Dictionary, product_id: int, platform_id: int, audience_id: int) -> int:
	if product_id not in range(Catalog.PRODUCTS.size()) or platform_id not in range(PLATFORMS.size()) or audience_id not in range(AUDIENCES.size()): return 0
	var product: Dictionary = Catalog.PRODUCTS[product_id]
	var season: float = Catalog.product_seasonality(product_id, int(state.day))
	var difficulty: float = [0.90, 1.0, 1.16][int(state.difficulty)]
	var competitive_market := sqrt(float(product.competition) * season)
	var platform: Dictionary = PLATFORMS[platform_id]
	return Catalog.local_cents(int(state.country), float(platform.cpm) * AUDIENCE_COST[audience_id] * float(platform.competition) * competitive_market * difficulty)

static func purchase_probability(sim: RefCounted, campaign: Dictionary, listing: Dictionary) -> float:
	var state: Dictionary = sim.state
	var product_id := int(campaign.product)
	var product: Dictionary = Catalog.PRODUCTS[product_id]
	var platform: Dictionary = PLATFORMS[int(campaign.platform)]
	var audience_id := int(campaign.audience)
	var objective_id := int(campaign.objective)
	var creative_id := int(campaign.creative)
	var conversion: float = float(platform.purchase) * AUDIENCE_CONVERSION[audience_id] * OBJECTIVE_CONVERSION[objective_id] * float(campaign.learning)
	conversion *= CREATIVE_CONVERSION[creative_id] * (0.88 + float(state.reputation) / 500.0)
	var reference_price := Catalog.local_cents(int(state.country), float(product.cost) * 2.7)
	var price_factor := clampf(float(reference_price) / maxf(1.0, float(listing.price)), 0.25, 1.25)
	var seasonal_market: float = Catalog.product_seasonality(product_id, int(state.day))
	var difficulty: float = [1.18, 1.0, 0.78][int(state.difficulty)]
	conversion *= clampf(float(product.demand) * seasonal_market, 0.4, 1.5) * price_factor * difficulty
	if sim.stock(product_id) <= 0:
		var source: int = int(sim.product_state(product_id).get("supplier", Catalog.DEFAULT_SUPPLIER))
		var direct_ready: bool = Supply.supplier_unlocked(state, source) and Catalog.SUPPLIERS[source].direct
		if listing.get("allow_preorders", false):
			var wait_days := int(Catalog.SUPPLIERS[source].lead)
			for batch in state.inbound:
				if int(batch.product) == product_id:
					wait_days = maxi(0, int(batch.eta) - int(state.day))
					break
			conversion *= clampf(1.0 - float(wait_days) * 0.035, 0.25, 1.0)
		elif not direct_ready:
			conversion = 0.0
	return clampf(conversion, 0.0, 0.94)

static func available_platforms(country: int, store: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for id in PLATFORMS.size():
		if platform_available(country, id, store): names.append(PLATFORMS[id].name)
	return names

static func audience_ready(state: Dictionary, store_id: int, audience: int) -> bool:
	if audience == 3: return int(state.advertising.visitors.get(store_id, 0)) >= 15
	if audience == 4: return int(state.advertising.conversions.get(store_id, 0)) >= 5
	return audience in range(AUDIENCES.size())

static func create(state: Dictionary, config: Dictionary) -> String:
	ensure_state(state)
	var name := str(config.get("name", "")).strip_edges()
	var store_id := int(config.get("store_id", -1))
	var store := Stores.get_store(state, store_id)
	var platform := int(config.get("platform", -1))
	var product := int(config.get("product", -1))
	var listing := Stores.listing(state, store_id, product) if product in range(Catalog.PRODUCTS.size()) else {}
	var budget := int(config.get("daily_budget", 0))
	var audience := int(config.get("audience", 0))
	var objective := int(config.get("objective", 0))
	var bid_strategy := int(config.get("bid_strategy", 0))
	var creative := int(config.get("creative", 0))
	var bid := int(config.get("bid", 0))
	if name.is_empty() or store.is_empty() or not store.active: return "Choose a name and an active store."
	if not listing.get("listed", false): return "This product is not listed in the selected store. Publish it before advertising."
	if not platform_available(state.country, platform, store): return "That platform is unavailable in this country or for this store type."
	if budget < 1 or budget > Catalog.local_cents(state.country, 10000.0): return "Daily budget must be positive and no more than 10,000 in local currency."
	if audience not in range(AUDIENCES.size()) or objective not in range(OBJECTIVES.size()) or bid_strategy not in range(BIDS.size()) or creative not in range(CREATIVES.size()):
		return "Choose a valid objective, audience, bidding strategy, and creative."
	if bid_strategy != 0 and bid < 1: return "Enter a positive bid limit for Cost cap or Bid cap."
	if not audience_ready(state, store_id, audience): return "Retargeting needs 15 store visits. Lookalike audiences need 5 historical purchases."
	var start := int(config.get("start_day", state.day))
	var end := int(config.get("end_day", 0))
	if start < state.day or (end > 0 and end < start): return "Start date must be today or later, and the optional end date must follow it."
	var id: int = state.advertising.next_campaign
	state.advertising.next_campaign += 1
	state.advertising.campaigns[id] = {
		"id": id, "name": name, "platform": platform, "store_id": store_id,
		"channel": Stores.channel(store), "product": product, "objective": objective,
		"daily_budget": budget, "start_day": start, "end_day": end,
		"audience": audience, "bid_strategy": bid_strategy, "bid": bid,
		"creative": creative, "status": "draft" if config.get("draft", false) else "active", "learning": 1.0,
		"created": state.day,
	}
	return ""

static func edit(state: Dictionary, id: int, changes: Dictionary) -> String:
	var campaign: Dictionary = state.advertising.campaigns.get(id, {}).duplicate(true)
	if campaign.is_empty() or campaign.status == "stopped": return "This campaign cannot be edited."
	for key in changes:
		if key in ["name", "platform", "store_id", "product", "objective", "daily_budget", "end_day", "audience", "bid_strategy", "bid", "creative"]:
			campaign[key] = changes[key]
	var store := Stores.get_store(state, campaign.store_id)
	var listing := Stores.listing(state, campaign.store_id, campaign.product)
	if str(campaign.name).strip_edges().is_empty() or store.is_empty() or not store.active or not platform_available(state.country, campaign.platform, store): return "Choose an active destination store and a compatible advertising platform."
	campaign.channel = Stores.channel(store)
	if not listing.get("listed", false): return "Publish the promoted product in this store before saving changes."
	if campaign.audience not in range(AUDIENCES.size()) or not audience_ready(state, campaign.store_id, campaign.audience): return "This audience is unavailable until its activity requirement is met."
	if campaign.objective not in range(OBJECTIVES.size()) or campaign.bid_strategy not in range(BIDS.size()) or campaign.creative not in range(CREATIVES.size()): return "Choose valid campaign settings."
	if campaign.daily_budget < 1 or campaign.daily_budget > Catalog.local_cents(state.country, 10000.0): return "Daily budget must be positive and no more than 10,000 in local currency."
	if campaign.bid_strategy != 0 and campaign.bid < 1: return "Enter a positive bid limit for Cost cap or Bid cap."
	if bool(changes.get("save_as_draft", false)):
		campaign.status = "draft"
	if campaign.end_day > 0 and campaign.end_day < state.day: campaign.status = "stopped"
	state.advertising.campaigns[id] = campaign
	return ""

static func set_status(state: Dictionary, id: int, status: String) -> String:
	if status not in ["draft", "active", "paused", "stopped"]: return "Choose a valid campaign status."
	var campaign: Dictionary = state.advertising.campaigns.get(id, {})
	if campaign.is_empty() or campaign.status == "stopped": return "This campaign cannot be resumed."
	if campaign.status == "draft" and status == "paused":
		return "Launch a draft before pausing it."
	if campaign.status == "active" and status == "active":
		return "This campaign is already active."
	if campaign.status == "paused" and status == "paused":
		return "This campaign is already paused."
	if status == "active":
		var store := Stores.get_store(state, campaign.store_id)
		if store.is_empty() or not store.active or not Stores.listing(state, campaign.store_id, campaign.product).get("listed", false):
			return "Campaign launch requires an active store and listed product."
		if campaign.end_day > 0 and campaign.end_day < state.day:
			return "Campaign end date has passed."
		campaign.start_day = maxi(campaign.start_day, state.day)
	campaign.status = status
	state.advertising.campaigns[id] = campaign
	return ""

static func duplicate_stopped(state: Dictionary, id: int) -> String:
	var source: Dictionary = state.advertising.campaigns.get(id, {})
	if source.get("status") != "stopped":
		return "Only stopped campaigns can be duplicated."
	var campaign := source.duplicate(true)
	campaign.id = state.advertising.next_campaign
	campaign.name += " (copy)"
	campaign.status = "draft"
	campaign.start_day = state.day
	campaign.end_day = 0
	campaign.learning = 1.0
	campaign.created = state.day
	state.advertising.campaigns[campaign.id] = campaign
	state.advertising.next_campaign += 1
	return ""

static func simulate_day(sim: RefCounted, rng: RandomNumberGenerator) -> void:
	var state: Dictionary = sim.state
	ensure_state(state)
	var ids: Array = state.advertising.campaigns.keys()
	ids.sort()
	for id in ids:
		var campaign: Dictionary = state.advertising.campaigns[id]
		if campaign.status != "active" or campaign.start_day > state.day or (campaign.end_day > 0 and state.day > campaign.end_day): continue
		var store := Stores.get_store(state, campaign.store_id)
		var listing := Stores.listing(state, campaign.store_id, campaign.product)
		if store.is_empty() or not store.active or not listing.get("listed", false): continue
		if not platform_available(state.country, campaign.platform, store) or not audience_ready(state, campaign.store_id, campaign.audience): continue
		var platform: Dictionary = PLATFORMS[campaign.platform]
		var audience_id: int = campaign.audience
		var cpm: int = effective_cpm(state, int(campaign.product), int(campaign.platform), audience_id)
		var ctr: float = clampf(platform.ctr * OBJECTIVE_CLICK[campaign.objective] * CREATIVE_CLICK[campaign.creative], 0.15, 12.0)
		var expected_cpc := maxi(1, roundi(cpm / (ctr * 10.0)))
		var delivery := 1.0
		if campaign.bid_strategy == 1: delivery = clampf(float(campaign.bid) / expected_cpc, 0.2, 1.0)
		elif campaign.bid_strategy == 2: delivery = clampf(0.5 + float(campaign.bid) / expected_cpc * 0.5, 0.2, 1.2)
		var spend := mini(int(campaign.daily_budget * delivery), maxi(0, state.cash))
		var metrics := empty_metrics()
		metrics.day = state.day
		metrics.campaign_id = id
		metrics.spend = spend
		state.cash -= spend
		state.ledger.back().advertising += spend
		var activity := Stores.store_activity(state.ledger.back(), int(campaign.store_id))
		activity.advertising += spend
		state.ledger.back().store_activity[campaign.store_id] = activity
		if spend > 0:
			var effective_cpm: float = float(cpm) / platform.reach * AUDIENCE_REACH[audience_id]
			metrics.impressions = maxi(1, roundi(float(spend) * 1000.0 / effective_cpm))
			metrics.reach = mini(metrics.impressions, maxi(1, roundi(metrics.impressions * (0.72 * AUDIENCE_REACH[audience_id]))))
			var adjusted_ctr := ctr / 100.0 * (0.85 if campaign.objective == 0 else 1.0)
			metrics.clicks = stochastic_count(metrics.impressions * adjusted_ctr, rng)
			metrics.add_to_cart = stochastic_count(metrics.clicks * platform.cart * AUDIENCE_CONVERSION[audience_id], rng)
			metrics.checkouts = stochastic_count(metrics.add_to_cart * platform.checkout, rng)
			var conversion := purchase_probability(sim, campaign, listing)
			var purchase_attempts := stochastic_count(metrics.checkouts * conversion, rng)
			var offers := Storefront.offers_for(state, campaign.product)
			for _attempt in purchase_attempts:
				var order_id: int = Storefront.complete_checkout(sim, campaign.product, int(listing.price), int(campaign.channel), offers, rng, int(campaign.store_id), int(id))
				if order_id <= 0: continue
				var order: Dictionary = state.orders[order_id]
				if order.get("preorder", false):
					metrics.preorders += 1
				else:
					metrics.purchases += 1
					metrics.attributed_revenue += order.total
					for line in order.items: metrics.estimated_costs += line.cost
					metrics.estimated_costs += Stores.store_fee(Stores.get_store(state, int(order.store_id)), int(order.channel), int(order.total))
					for line in order.items:
						if not line.has("direct_supplier"):
							metrics.estimated_costs += Catalog.local_cents(state.country, Catalog.SHIPPING[state.shipping].cost)
							break
		metrics.estimated_profit = metrics.attributed_revenue - metrics.estimated_costs - spend
		state.advertising.history.append(metrics)
		state.advertising.visitors[campaign.store_id] = int(state.advertising.visitors.get(campaign.store_id, 0)) + metrics.clicks
		var updated: Dictionary = campaign.duplicate(true)
		updated.learning = clampf(float(campaign.learning) + (0.008 if metrics.purchases + metrics.preorders > 0 else -0.002), 0.85, 1.2)
		state.advertising.campaigns[id] = updated

static func note_delivery(state: Dictionary, order: Dictionary) -> void:
	var store_id: int = int(order.get("store_id", order.get("channel", 0)))
	state.advertising.conversions[store_id] = int(state.advertising.conversions.get(store_id, 0)) + 1
	if not order.get("preorder", false): return
	var campaign_id := int(order.get("campaign_id", 0))
	if campaign_id <= 0 or not state.advertising.campaigns.has(campaign_id): return
	var adjustment := empty_metrics()
	adjustment.day = state.day
	adjustment.campaign_id = campaign_id
	adjustment.attributed_revenue = int(order.total)
	for line in order.items: adjustment.estimated_costs += int(line.cost)
	adjustment.estimated_costs += int(order.get("channel_fee", 0)) + int(order.get("shipping_cost", 0))
	state.advertising.history.append(adjustment)

static func note_preorder_cancel(state: Dictionary, order: Dictionary) -> void:
	var campaign_id := int(order.get("campaign_id", 0))
	if campaign_id <= 0 or not state.advertising.campaigns.has(campaign_id): return
	var adjustment := empty_metrics()
	adjustment.day = state.day
	adjustment.campaign_id = campaign_id
	adjustment.preorders_cancelled = 1
	state.advertising.history.append(adjustment)

static func note_refund(state: Dictionary, campaign_id: int, _store_id: int, amount: int, costs_reversed: int) -> void:
	if campaign_id <= 0 or not state.advertising.campaigns.has(campaign_id): return
	var adjustment := empty_metrics()
	adjustment.day = state.day
	adjustment.campaign_id = campaign_id
	adjustment.attributed_refunds = amount
	adjustment.estimated_costs_reversed = costs_reversed
	state.advertising.history.append(adjustment)

static func empty_metrics() -> Dictionary:
	var value := {"campaign_id": 0, "day": 0}
	for field in METRIC_FIELDS: value[field] = 0
	value.estimated_profit = 0
	return value

static func stochastic_count(expected: float, rng: RandomNumberGenerator) -> int:
	var count := floori(expected)
	if rng.randf() < expected - count: count += 1
	return count

static func aggregate(state: Dictionary, campaign_id: int, period: int, anchor: int) -> Dictionary:
	var range_days := Calendar.bounds(period, maxi(1, anchor))
	return aggregate_range(state, campaign_id, maxi(1, range_days.x), mini(range_days.y, state.day))

static func aggregate_range(state: Dictionary, campaign_id: int, first_day: int, last_day: int) -> Dictionary:
	var result := empty_metrics()
	result.campaign_id = campaign_id
	result.day = last_day
	result.start_day = maxi(1, first_day)
	result.end_day = maxi(0, last_day)
	for record in state.advertising.history:
		if int(record.campaign_id) != campaign_id or int(record.day) < result.start_day or int(record.day) > result.end_day: continue
		for field in METRIC_FIELDS: result[field] += int(record.get(field, 0))
	result.ctr = 100.0 * result.clicks / result.impressions if result.impressions > 0 else 0.0
	result.cpc = float(result.spend) / result.clicks if result.clicks > 0 else 0.0
	result.cpm = float(result.spend) / result.impressions * 1000.0 if result.impressions > 0 else 0.0
	var conversions: int = result.purchases + result.preorders - result.preorders_cancelled
	result.conversions = maxi(0, conversions)
	result.conversion_rate = 100.0 * float(result.conversions) / result.clicks if result.clicks > 0 else 0.0
	result.cpa = float(result.spend) / result.conversions if result.conversions > 0 else 0.0
	result.roas = float(result.attributed_revenue) / result.spend if result.spend > 0 else 0.0
	result.net_attributed_revenue = result.attributed_revenue - result.attributed_refunds
	result.estimated_profit = result.net_attributed_revenue - result.estimated_costs + result.estimated_costs_reversed - result.spend
	return result
