extends RefCounted

const Catalog = preload("res://catalog.gd")
const Ads = preload("res://advertising.gd")
const Stores = preload("res://store_manager.gd")
const Calendar = preload("res://game_calendar.gd")
const Style = preload("res://corporate_theme.gd")

static func overview(app: Control) -> void:
	var view: VBoxContainer = app.card("Advertising Overview")
	view.add_child(app.label("Simulated platforms · Local budgets · Campaign-attributed orders", 14, Style.MUTED))
	app.action(view, "Campaign Manager", app.navigate.bind("Campaign Manager"), true)
	var actions: HBoxContainer = app.row(view)
	app.action(actions, "Advertising Analytics", app.navigate.bind("Advertising Analytics"))
	app.action(actions, "Store Management", app.navigate.bind("Store Management"))
	var campaigns: Dictionary = app.sim.state.advertising.campaigns
	var active := 0
	var totals := Ads.empty_metrics()
	for id in campaigns:
		var campaign: Dictionary = campaigns[id]
		if campaign.status == "active": active += 1
		var metric: Dictionary = _lifetime(app.sim.state, id)
		for field in Ads.METRIC_FIELDS + ["estimated_profit"]: totals[field] += int(metric.get(field, 0))
	app.metric(view, "Active campaigns", str(active), Style.GOLD)
	app.metric(view, "Lifetime ad spend", app.money(totals.spend))
	app.metric(view, "Attributed revenue · net of refunds", app.money(totals.attributed_revenue - totals.attributed_refunds))
	var roas: float = float(totals.attributed_revenue - totals.attributed_refunds) / totals.spend if totals.spend > 0 else 0.0
	app.metric(view, "ROAS · CPA", "%.2f× · %s" % [roas, _average_cost(app, totals.spend, totals.purchases)])
	app.metric(view, "Estimated advertising profit", app.money(totals.attributed_revenue - totals.attributed_refunds - totals.estimated_costs + totals.estimated_costs_reversed - totals.spend), app.profit_color(totals.attributed_revenue - totals.attributed_refunds - totals.estimated_costs + totals.estimated_costs_reversed - totals.spend))
	view.add_child(app.label("Attributed revenue is measured when an order is placed. Income Statement revenue is recognized on delivery. A refund adds an attribution adjustment to its campaign history.", 13, Style.MUTED))
	var platform_card: VBoxContainer = app.card("Platforms")
	for platform in Ads.PLATFORMS:
		platform_card.add_child(app.label("%s · $%.2f CPM · %.1f%% baseline CTR" % [platform.name, platform.cpm, platform.ctr], 14, Style.MUTED))

static func manager(app: Control) -> void:
	var view: VBoxContainer = app.card("Campaign Manager")
	var links: HBoxContainer = app.row(view)
	app.action(links, "Overview", app.navigate.bind("Growth"))
	app.action(links, "Analytics", app.navigate.bind("Advertising Analytics"))
	app.action(view, "Create campaign", func():
		app.campaign_id = 0
		app.navigate("Campaign Details")
	, true)
	var ids: Array = app.sim.state.advertising.campaigns.keys()
	ids.sort()
	if ids.is_empty():
		view.add_child(app.label("No campaigns yet. Promote a published product in an active store.", 14, Style.MUTED))
	for id in ids:
		var campaign: Dictionary = app.sim.state.advertising.campaigns[id]
		var store := Stores.get_store(app.sim.state, campaign.store_id)
		var detail: VBoxContainer = app.stack(view, 6)
		app.divider(detail)
		app.metric(detail, campaign.name, campaign.status.capitalize(), Style.GOLD)
		detail.add_child(app.label("%s · %s · %s" % [Ads.PLATFORMS[campaign.platform].name,
			store.name if not store.is_empty() else "Missing store", Catalog.PRODUCTS[campaign.product].name], 13, Style.MUTED))
		app.metric(detail, "Daily budget", app.money(campaign.daily_budget))
		var button: Button = app.action(detail, "Manage campaign", func():
			app.campaign_id = id
			app.navigate("Campaign Details")
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func details(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var creating: bool = app.campaign_id == 0
	var existing: Dictionary = state.advertising.campaigns.get(app.campaign_id, {})
	if not creating and existing.is_empty():
		app.set_notice("Campaign not found.", true)
		app.navigate("Campaign Manager")
		return
	var view: VBoxContainer = app.card("Create campaign" if creating else existing.name)
	app.action(view, "Campaign Manager", app.navigate.bind("Campaign Manager"))
	if state.stores.is_empty():
		view.add_child(app.label("Create a store before setting up ads.", 14, Style.MUTED))
		app.action(view, "Store Management", app.navigate.bind("Store Management"))
		return
	var editable_destination: bool = creating or existing.get("status") == "draft"
	var platform_ids: Array[int] = []
	var platform_names: Array[String] = []
	for id in Ads.PLATFORMS.size():
		if id == 3 and existing.get("platform", -1) != id:
			continue
		platform_ids.append(id)
		platform_names.append(Ads.PLATFORMS[id].name)
	view.add_child(app.label("Advertising platform", 14, Style.MUTED))
	var platform_picker: OptionButton = app.dropdown(view, platform_names, maxi(0, platform_ids.find(existing.get("platform", 0))))
	view.add_child(app.label("Destination store", 14, Style.MUTED))
	var store_picker: OptionButton = app.dropdown(view, [], -1)
	view.add_child(app.label("Listed product", 14, Style.MUTED))
	var product_picker: OptionButton = app.dropdown(view, [], -1)
	var store_ids: Array[int] = []
	var product_ids: Array[int] = []
	var selected_store: int = existing.get("store_id", -1)
	var selected_product: int = existing.get("product", app.selected_product)
	var name: LineEdit = app.field(view, "Campaign name", str(existing.get("name", "")), 48)
	var update_products := func(_index: int):
		product_picker.clear()
		product_ids.clear()
		if store_picker.selected < 0:
			return
		var store_id: int = store_ids[store_picker.selected]
		for product in Catalog.PRODUCTS.size():
			var listing := Stores.listing(state, store_id, product)
			if listing.get("listed", false) or (store_id == selected_store and product == existing.get("product", -1)):
				product_ids.append(product)
				product_picker.add_item(Catalog.PRODUCTS[product].name)
		product_picker.select(maxi(0, product_ids.find(selected_product)) if not product_ids.is_empty() else -1)
	var update_destinations := func(_index: int):
		var previous: int = store_ids[store_picker.selected] if store_picker.selected >= 0 else selected_store
		store_picker.clear()
		store_ids.clear()
		for store in state.stores:
			if (store.id == selected_store and platform_ids[platform_picker.selected] == existing.get("platform", -1)) or (store.active and Ads.platform_available(state.country, platform_ids[platform_picker.selected], store)):
				store_ids.append(store.id)
				store_picker.add_item(store.name)
		store_picker.select(maxi(0, store_ids.find(previous)) if not store_ids.is_empty() else -1)
		update_products.call(store_picker.selected)
	update_destinations.call(platform_picker.selected)
	for picker in [platform_picker, store_picker, product_picker]:
		picker.disabled = not editable_destination
	var objective_picker: OptionButton = app.dropdown(view, Ads.OBJECTIVES, int(existing.get("objective", 3)))
	var budget: LineEdit = app.field(view, "Daily budget (%s)" % Catalog.CURRENCIES[state.country], _money_field(app, int(existing.get("daily_budget", Catalog.local_cents(state.country, 20.0)))), 16)
	budget.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	var audience_picker: OptionButton = app.dropdown(view, Ads.AUDIENCES, int(existing.get("audience", 0)))
	var bidding_picker: OptionButton = app.dropdown(view, Ads.BIDS, int(existing.get("bid_strategy", 0)))
	var bid: LineEdit = app.field(view, "Bid limit (%s · 0 if Lowest cost)" % Catalog.CURRENCIES[state.country], _money_field(app, int(existing.get("bid", 0))), 16)
	bid.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	var creative_picker: OptionButton = app.dropdown(view, Ads.CREATIVES, int(existing.get("creative", 0)))
	var start: LineEdit = app.field(view, "Start game day", str(existing.get("start_day", state.day)), 8)
	start.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	start.editable = creating or existing.get("status") == "draft"
	var end: LineEdit = app.field(view, "End game day (optional, 0 means no end)", str(existing.get("end_day", 0)), 8)
	end.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	if not creating:
		view.add_child(app.label("Availability: %s · Store channel: %s" % [
			"Eligible now" if Ads.audience_ready(state, existing.store_id, existing.audience) else "Audience threshold not met",
			Catalog.CHANNELS[existing.channel]], 13, Style.MUTED))
	var form: Array = [name, store_picker, product_picker, platform_picker, objective_picker, budget, audience_picker, bidding_picker, bid, creative_picker, start, end]
	var saved: Callable = app.watch_edits(form)
	var update_audiences := func():
		for id in range(3, Ads.AUDIENCES.size()):
			audience_picker.set_item_disabled(id, store_picker.selected < 0 or not Ads.audience_ready(state, store_ids[store_picker.selected], id))
	platform_picker.item_selected.connect(func(index: int):
		update_destinations.call(index)
		update_audiences.call()
	)
	store_picker.item_selected.connect(func(index: int):
		update_products.call(index)
		update_audiences.call()
	)
	update_audiences.call()
	var save_campaign := func(draft: bool):
		if product_picker.selected < 0 or store_picker.selected < 0:
			app.set_notice("This store needs an eligible listing and platform before campaign creation.", true)
			return
		var budget_cents: int = app.price_cents(budget.text)
		var bid_cents: int = app.price_cents(bid.text)
		var config := {
			"name": name.text.strip_edges(), "store_id": store_ids[store_picker.selected],
			"product": product_ids[product_picker.selected], "platform": platform_ids[platform_picker.selected],
			"objective": objective_picker.selected, "daily_budget": budget_cents,
			"audience": audience_picker.selected, "bid_strategy": bidding_picker.selected,
			"bid": bid_cents, "creative": creative_picker.selected,
			"draft": draft, "start_day": _integer(start.text, -1), "end_day": _integer(end.text, 0),
		}
		var error := Ads.create(state, config) if creating else Ads.edit(state, app.campaign_id, config)
		if not error.is_empty():
			app.set_notice(error, true)
			return
		saved.call()
		if creating:
			app.campaign_id = state.advertising.next_campaign - 1
		app.persist("Campaign saved. New settings apply from future simulated days.")
		app.navigate("Campaign Manager")
	if creating or existing.status != "stopped":
		app.action(view, "Create campaign" if creating else "Save campaign", save_campaign.bind(false), true)
	if creating:
		app.action(view, "Save Draft", save_campaign.bind(true))
	if not creating:
		var control_row: HBoxContainer = app.row(view)
		view.add_child(app.label("Drafts do not spend. Paused campaigns can resume. Stopped campaigns retain their history and can be duplicated.", 14, Style.MUTED))
		var next_status: String = {"active": "Pause", "draft": "Launch", "paused": "Resume"}.get(existing.status, "")
		if existing.status != "stopped":
			app.action(control_row, next_status, func():
				var error := Ads.set_status(state, app.campaign_id, "paused" if next_status == "Pause" else "active")
				if not error.is_empty():
					app.set_notice(error, true)
					return
				app.persist("Campaign is %s." % state.advertising.campaigns[app.campaign_id].status)
				app.refresh_view()
			)
			app.action(control_row, "Stop", func():
				app.confirm_action("Stop campaign?", "This campaign cannot be resumed. Its history will be retained.", "Stop campaign", func():
					Ads.set_status(state, app.campaign_id, "stopped")
					app.persist("Campaign stopped.")
					app.refresh_view()
				)
			)
		else:
			app.action(control_row, "Duplicate", func():
				var error := Ads.duplicate_stopped(state, app.campaign_id)
				if not error.is_empty():
					app.set_notice(error, true)
					return
				app.campaign_id = state.advertising.next_campaign - 1
				app.persist("Campaign duplicated as a draft.")
				app.refresh_view()
			)
		var metrics: Dictionary = _lifetime(state, app.campaign_id)
		app.metric(view, "Lifetime ad spend", app.money(metrics.spend))
		app.metric(view, "Attributed purchases · revenue", "%d · %s" % [metrics.purchases, app.money(metrics.attributed_revenue - metrics.attributed_refunds)])
		app.metric(view, "ROAS · CPA", "%.2f× · %s" % [metrics.roas, _average_cost(app, metrics.spend, metrics.purchases)])
		app.action(view, "Advertising Analytics", app.navigate.bind("Advertising Analytics"))

static func analytics(app: Control) -> void:
	var view: VBoxContainer = app.card("Advertising Analytics")
	var nav: HBoxContainer = app.row(view)
	app.action(nav, "Overview", app.navigate.bind("Growth"))
	app.action(nav, "Campaigns", app.navigate.bind("Campaign Manager"))
	var periods: OptionButton = app.dropdown(view, Calendar.PERIODS, app.ad_period)
	periods.item_selected.connect(func(index: int):
		app.ad_period = index
		app.render()
	)
	var anchor: int = app.ad_period_end if app.ad_period_end > 0 else app.sim.state.day
	var bounds := Calendar.bounds(app.ad_period, anchor)
	view.add_child(app.label(Calendar.format_range(bounds.x, bounds.y), 14, Style.GOLD))
	var navigate_period: HBoxContainer = app.row(view)
	var previous: Button = app.action(navigate_period, "Previous", func():
		app.ad_period_end = bounds.x - 1
		app.render()
	)
	previous.disabled = bounds.x <= 1
	var next: Button = app.action(navigate_period, "Next", func():
		app.ad_period_end = bounds.y + 1
		app.render()
	)
	next.disabled = bounds.y >= app.sim.state.day
	var campaigns: Dictionary = app.sim.state.advertising.campaigns
	var ids: Array = campaigns.keys()
	ids.sort()
	var filter_choices := ["All"]
	for platform in Ads.PLATFORMS: filter_choices.append(platform.name)
	var platform_filter: OptionButton = app.dropdown(view, filter_choices, app.ad_platform_filter + 1)
	platform_filter.item_selected.connect(func(index: int): app.ad_platform_filter = index - 1; app.render())
	var stores: Array[String] = ["All"]
	for store in app.sim.state.stores: stores.append(store.name)
	var store_filter: OptionButton = app.dropdown(view, stores, 0 if app.ad_store_filter < 0 else _store_index(app.sim.state, app.ad_store_filter) + 1)
	store_filter.item_selected.connect(func(index: int):
		app.ad_store_filter = -1 if index == 0 else app.sim.state.stores[index - 1].id
		app.render()
	)
	var products: Array[String] = ["All"]
	for item in Catalog.PRODUCTS: products.append(item.name)
	var product_filter: OptionButton = app.dropdown(view, products, app.ad_product_filter + 1)
	product_filter.item_selected.connect(func(index: int): app.ad_product_filter = index - 1; app.render())
	var statuses := ["All statuses", "Active", "Paused", "Stopped", "Draft"]
	var status_filter: OptionButton = app.dropdown(view, statuses, app.ad_status_filter + 1)
	status_filter.item_selected.connect(func(index: int): app.ad_status_filter = index - 1; app.render())
	var total := Ads.empty_metrics()
	var count := 0
	for id in ids:
		var campaign: Dictionary = campaigns[id]
		if app.ad_platform_filter >= 0 and campaign.platform != app.ad_platform_filter: continue
		if app.ad_store_filter >= 0 and campaign.store_id != app.ad_store_filter: continue
		if app.ad_product_filter >= 0 and campaign.product != app.ad_product_filter: continue
		if app.ad_status_filter >= 0 and campaign.status != ["active", "paused", "stopped", "draft"][app.ad_status_filter]: continue
		var metric: Dictionary = Ads.aggregate(app.sim.state, id, app.ad_period, anchor)
		count += 1
		for field in Ads.METRIC_FIELDS + ["estimated_profit"]: total[field] += int(metric.get(field, 0))
	var roas: float = float(total.attributed_revenue - total.attributed_refunds) / total.spend if total.spend > 0 else 0.0
	app.metric(view, "Campaigns compared", str(count))
	app.metric(view, "Ad spend · attributed net revenue", "%s · %s" % [app.money(total.spend), app.money(total.attributed_revenue - total.attributed_refunds)])
	app.metric(view, "ROAS · CPA", "%.2f× · %s" % [roas, _average_cost(app, total.spend, total.purchases)])
	app.metric(view, "Estimated advertising profit", app.money(total.attributed_revenue - total.attributed_refunds - total.estimated_costs + total.estimated_costs_reversed - total.spend), app.profit_color(total.attributed_revenue - total.attributed_refunds - total.estimated_costs + total.estimated_costs_reversed - total.spend))
	for id in ids:
		var campaign: Dictionary = campaigns[id]
		if app.ad_platform_filter >= 0 and campaign.platform != app.ad_platform_filter: continue
		if app.ad_store_filter >= 0 and campaign.store_id != app.ad_store_filter: continue
		if app.ad_product_filter >= 0 and campaign.product != app.ad_product_filter: continue
		if app.ad_status_filter >= 0 and campaign.status != ["active", "paused", "stopped", "draft"][app.ad_status_filter]: continue
		var metric: Dictionary = Ads.aggregate(app.sim.state, id, app.ad_period, anchor)
		var detail: VBoxContainer = app.card(campaign.name)
		app.metric(detail, "Platform · Status", "%s · %s" % [Ads.PLATFORMS[campaign.platform].name, campaign.status.capitalize()])
		app.metric(detail, "Store · Product", "%s · %s" % [Stores.get_store(app.sim.state, campaign.store_id).name, Catalog.PRODUCTS[campaign.product].name])
		app.metric(detail, "Spend", app.money(metric.spend))
		app.metric(detail, "CPM", app.money(roundi(metric.cpm)))
		app.metric(detail, "Impressions · Reach", "%s · %s" % [_count(metric.impressions), _count(metric.reach)])
		app.metric(detail, "Clicks · CTR · CPC", "%d · %.2f%% · %s" % [metric.clicks, metric.ctr, _average_cost(app, metric.spend, metric.clicks)])
		app.metric(detail, "Add to cart · Checkouts", "%d · %d" % [metric.add_to_cart, metric.checkouts])
		app.metric(detail, "Purchases · Conversion · CPA", "%d · %.2f%% · %s" % [metric.purchases, metric.conversion_rate, _average_cost(app, metric.spend, metric.purchases)])
		app.metric(detail, "Attributed revenue · ROAS", "%s · %.2f×" % [app.money(metric.attributed_revenue - metric.attributed_refunds), metric.roas], Style.GOLD)
		var trend: Dictionary = _seven_day_trend(app.sim.state, int(id))
		detail.add_child(app.label("7-day spend  %s" % _sparkline(trend.spend), 13, Style.MUTED))
		detail.add_child(app.label("7-day net revenue  %s" % _sparkline(trend.revenue), 13, Style.MUTED))
		app.action(detail, "Manage campaign", func():
			app.campaign_id = id
			app.navigate("Campaign Details")
		)

static func _lifetime(state: Dictionary, campaign_id: int) -> Dictionary:
	var result := Ads.empty_metrics()
	for record in state.advertising.history:
		if record.campaign_id != campaign_id: continue
		for field in Ads.METRIC_FIELDS: result[field] += int(record.get(field, 0))
	result.roas = float(result.attributed_revenue - result.attributed_refunds) / result.spend if result.spend > 0 else 0.0
	result.estimated_profit = result.attributed_revenue - result.attributed_refunds - result.estimated_costs + result.estimated_costs_reversed - result.spend
	return result

static func _seven_day_trend(state: Dictionary, campaign_id: int) -> Dictionary:
	var spend := [0, 0, 0, 0, 0, 0, 0]
	var revenue := [0, 0, 0, 0, 0, 0, 0]
	var first_day: int = maxi(1, state.day - 7)
	for record in state.advertising.history:
		if record.campaign_id != campaign_id or record.day < first_day or record.day >= state.day: continue
		var index: int = int(record.day) - first_day
		if index < 0 or index >= 7: continue
		spend[index] += int(record.spend)
		revenue[index] += int(record.attributed_revenue) - int(record.attributed_refunds)
	return {"spend": spend, "revenue": revenue}

static func _sparkline(values: Array) -> String:
	var glyphs := ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
	var peak := 0
	for value in values: peak = maxi(peak, int(value))
	if peak <= 0: return "No recorded activity"
	var line := ""
	for value in values:
		line += glyphs[clampi(roundi(float(value) / peak * 7.0), 0, 7)]
	return line

static func _average_cost(app: Control, spend: int, count: int) -> String:
	return app.money(roundi(float(spend) / count)) if count > 0 else app.money(0)

static func _money_field(app: Control, cents: int) -> String:
	return app.amount_text(cents, true).replace(",", "")

static func _integer(value: String, fallback: int) -> int:
	var text := value.strip_edges()
	return text.to_int() if text.is_valid_int() else fallback

static func _store_index(state: Dictionary, store_id: int) -> int:
	for i in state.stores.size():
		if state.stores[i].id == store_id: return i
	return -1

static func _count(value: int) -> String:
	return str(value)
