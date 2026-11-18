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
	var roas: String = "%.2f×" % (float(totals.attributed_revenue) / totals.spend) if totals.spend > 0 else "—"
	var lifetime_conversions: int = maxi(0, totals.purchases + totals.preorders - totals.preorders_cancelled)
	app.metric(view, "ROAS · CPA", "%s · %s" % [roas, _unit_cost(app, totals.spend, lifetime_conversions)])
	view.add_child(app.label("ROAS uses gross attributed revenue divided by ad spend. Refunds are reported separately.", 13, Style.MUTED))
	app.metric(view, "Estimated advertising profit", app.money(totals.attributed_revenue - totals.attributed_refunds - totals.estimated_costs + totals.estimated_costs_reversed - totals.spend), app.profit_color(totals.attributed_revenue - totals.attributed_refunds - totals.estimated_costs + totals.estimated_costs_reversed - totals.spend))
	view.add_child(app.label("Standard order attribution is recorded at checkout. Pre-order revenue attribution waits until delivery; the Income Statement recognizes all sales on delivery.", 13, Style.MUTED))
	var platform_card: VBoxContainer = app.card("Platforms")
	for platform in Ads.PLATFORMS:
		platform_card.add_child(app.label("%s · $%.2f CPM · %.1f%% baseline CTR" % [platform.name, platform.cpm, platform.ctr], 14, Style.MUTED))

static func manager(app: Control) -> void:
	var view: VBoxContainer = app.card("Campaign Manager")
	var links: HBoxContainer = app.row(view)
	app.action(links, "Overview", app.navigate.bind("Advertising"))
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
	if not creating and existing.status == "stopped":
		view.add_child(app.label("Stopped campaigns are read-only. Duplicate this campaign to create a new Draft.", 14, Style.MUTED))
		var stopped_metrics: Dictionary = _lifetime(state, app.campaign_id)
		app.metric(view, "Lifetime ad spend", app.money(stopped_metrics.spend))
		app.metric(view, "Attributed purchases · revenue", "%d · %s" % [stopped_metrics.purchases, app.money(stopped_metrics.attributed_revenue - stopped_metrics.attributed_refunds)])
		app.action(view, "Duplicate", func():
			var error := Ads.duplicate_stopped(state, app.campaign_id)
			if not error.is_empty():
				app.set_notice(error, true)
				return
			app.campaign_id = state.advertising.next_campaign - 1
			app.persist("Campaign duplicated as a draft.")
			app.refresh_view()
		)
		return
	var store_ids: Array[int] = []
	var store_names: Array[String] = []
	for store in state.stores:
		if store.active:
			store_ids.append(int(store.id))
			store_names.append(str(store.name))
	if store_ids.is_empty():
		view.add_child(app.label("Create a store before launching an advertising campaign.", 14, Style.MUTED))
		app.action(view, "Store Management", app.navigate.bind("Store Management"))
		return
	var selected_store: int = int(existing.get("store_id", store_ids[0])) if not creating else store_ids[0]
	if selected_store not in store_ids:
		view.add_child(app.label("This campaign's destination is inactive. Activate an eligible store before editing it.", 14, Style.MUTED))
		app.action(view, "Store Management", app.navigate.bind("Store Management"))
		return
	var store_index := maxi(0, store_ids.find(selected_store))
	view.add_child(app.label("Destination store", 14, Style.MUTED))
	var store_picker: OptionButton = app.dropdown(view, store_names, store_index)
	var name: LineEdit = app.field(view, "Campaign name", str(existing.get("name", "")), 48)
	var product_ids: Array[int] = []
	var product_names: Array[String] = []
	var platform_ids: Array[int] = []
	var platform_names: Array[String] = []
	var selected_product: int = int(existing.get("product", app.selected_product))
	var selected_platform: int = int(existing.get("platform", 0))
	_fill_store_choices(state, store_ids[store_picker.selected], product_ids, product_names, platform_ids, platform_names)
	if not product_ids.has(selected_product) and not product_ids.is_empty(): selected_product = product_ids[0]
	if not platform_ids.has(selected_platform) and not platform_ids.is_empty(): selected_platform = platform_ids[0]
	if product_names.is_empty(): product_names.append("Select Product")
	if platform_names.is_empty(): platform_names.append("Select Advertising Platform")
	view.add_child(app.label("Listed product in selected store", 14, Style.MUTED))
	var product_picker: OptionButton = app.dropdown(view, product_names, maxi(0, product_ids.find(selected_product)))
	product_picker.disabled = product_ids.is_empty()
	view.add_child(app.label("Compatible advertising platform", 14, Style.MUTED))
	var platform_picker: OptionButton = app.dropdown(view, platform_names, maxi(0, platform_ids.find(selected_platform)))
	platform_picker.disabled = platform_ids.is_empty()
	if product_ids.is_empty():
		view.add_child(app.label("List a product in an active store before creating a product campaign.", 14, Style.MUTED))
	if platform_ids.is_empty():
		view.add_child(app.label("No advertising platform is compatible with this destination store.", 14, Style.MUTED))
	view.add_child(app.label("Campaign objective", 14, Style.MUTED))
	var objective_picker: OptionButton = app.dropdown(view, Ads.OBJECTIVES, int(existing.get("objective", 3)))
	var budget: LineEdit = app.field(view, "Daily budget (%s)" % Catalog.CURRENCIES[state.country], _money_field(app, int(existing.get("daily_budget", Catalog.local_cents(state.country, 20.0)))), 16)
	budget.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	view.add_child(app.label("Audience", 14, Style.MUTED))
	var audience_picker: OptionButton = app.dropdown(view, Ads.AUDIENCES, int(existing.get("audience", 0)))
	for audience_id in Ads.AUDIENCES.size():
		if audience_id >= 3 and not Ads.audience_ready(state, store_ids[store_picker.selected], audience_id):
			audience_picker.set_item_disabled(audience_id, true)
	view.add_child(app.label("Bidding strategy", 14, Style.MUTED))
	var bidding_picker: OptionButton = app.dropdown(view, Ads.BIDS, int(existing.get("bid_strategy", 0)))
	var bid: LineEdit = app.field(view, "Bid limit (%s · 0 if Lowest cost)" % Catalog.CURRENCIES[state.country], _money_field(app, int(existing.get("bid", 0))), 16)
	bid.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	view.add_child(app.label("Creative format", 14, Style.MUTED))
	var creative_picker: OptionButton = app.dropdown(view, Ads.CREATIVES, int(existing.get("creative", 0)))
	var start: LineEdit = app.field(view, "Start game day", str(existing.get("start_day", state.day)), 8)
	start.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	start.editable = creating
	var end: LineEdit = app.field(view, "End game day (optional, 0 means no end)", str(existing.get("end_day", 0)), 8)
	end.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	if not creating:
		view.add_child(app.label("Availability: %s · Store channel: %s" % [
			"Eligible now" if Ads.audience_ready(state, existing.store_id, existing.audience) else "Audience threshold not met",
			Catalog.CHANNELS[existing.channel]], 13, Style.MUTED))
	var form: Array = [name, store_picker, product_picker, platform_picker, objective_picker, budget, audience_picker, bidding_picker, bid, creative_picker, start, end]
	var saved: Callable = app.watch_edits(form)
	var update_store := func(_index: int):
		var old_product: int = product_ids[product_picker.selected] if not product_ids.is_empty() else selected_product
		product_ids.clear()
		product_names.clear()
		platform_ids.clear()
		platform_names.clear()
		_fill_store_choices(state, store_ids[store_picker.selected], product_ids, product_names, platform_ids, platform_names)
		product_picker.clear()
		if product_names.is_empty():
			product_picker.add_item("Select Product")
			product_picker.disabled = true
		else:
			for item_name in product_names: product_picker.add_item(item_name)
			product_picker.disabled = false
		product_picker.select(maxi(0, product_ids.find(old_product)))
		platform_picker.clear()
		if platform_names.is_empty():
			platform_picker.add_item("Select Advertising Platform")
			platform_picker.disabled = true
		else:
			for platform_name in platform_names: platform_picker.add_item(platform_name)
			platform_picker.disabled = false
		platform_picker.select(maxi(0, platform_ids.find(selected_platform)))
		product_picker.tooltip_text = "List a product in an active store before creating a product campaign." if product_ids.is_empty() else ""
		platform_picker.tooltip_text = "No advertising platform is compatible with this destination store." if platform_ids.is_empty() else ""
	store_picker.item_selected.connect(update_store)
	var save_campaign := func(as_draft: bool):
		if product_ids.is_empty() or platform_ids.is_empty():
			app.set_notice("This store needs an eligible listing and platform before campaign creation.", true)
			return
		var budget_cents: int = app.price_cents(budget.text)
		var bid_cents: int = app.price_cents(bid.text)
		var config := {
			"name": name.text.strip_edges(), "store_id": store_ids[store_picker.selected],
			"product": product_ids[product_picker.selected], "platform": platform_ids[platform_picker.selected],
			"objective": objective_picker.selected, "daily_budget": budget_cents,
			"audience": audience_picker.selected, "bid_strategy": bidding_picker.selected,
			"bid": bid_cents, "creative": creative_picker.selected, "draft": as_draft,
			"save_as_draft": as_draft,
			"start_day": _integer(start.text, -1), "end_day": _integer(end.text, 0),
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
	if creating:
		app.action(view, "Create campaign", save_campaign.bind(false), true)
		app.action(view, "Save Draft", save_campaign.bind(true))
	else:
		app.action(view, "Save campaign", save_campaign.bind(existing.status == "draft"), true)
		if existing.status != "stopped":
			app.action(view, "Save as Draft", save_campaign.bind(true))
	var cancel_edit := func(return_to_manager: bool):
		if app.has_form_edits():
			app.confirm_action("Discard unsaved changes?", "Your campaign settings have not been saved.", "Discard Changes", func():
				app.edit_checks.clear()
				if return_to_manager: app.navigate("Campaign Manager")
				else: app.refresh_view()
			)
		else:
			app.edit_checks.clear()
			if return_to_manager: app.navigate("Campaign Manager")
			else: app.refresh_view()
	app.action(view, "Cancel", cancel_edit.bind(true))
	app.action(view, "Discard Changes", func(): cancel_edit.call(false))
	if not creating:
		var control_row: HBoxContainer = app.row(view)
		var next_status: String = "Pause" if existing.status == "active" else ("Launch" if existing.status == "draft" else "Resume")
		if existing.status != "stopped":
			app.action(control_row, next_status, func():
				Ads.set_status(state, app.campaign_id, "paused" if existing.status == "active" else "active")
				app.persist("Campaign %s." % ("paused" if existing.status == "active" else "resumed"))
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
	var state: Dictionary = app.sim.state
	var view: VBoxContainer = app.card("Advertising Analytics")
	var nav: HBoxContainer = app.row(view)
	app.action(nav, "Overview", app.navigate.bind("Advertising"))
	app.action(nav, "Campaigns", app.navigate.bind("Campaign Manager"))
	var period_choices := ["Today", "Last 7 Days", "Last 30 Days", "All Time"]
	view.add_child(app.label("Reporting Period", 14, Style.MUTED))
	var periods: OptionButton = app.dropdown(view, period_choices, clampi(app.ad_period, 0, 3))
	periods.item_selected.connect(func(index: int):
		app.ad_period = index
		app.render()
	)
	var last_day: int = state.day
	var first_day: int = state.day
	match app.ad_period:
		1: first_day = maxi(1, state.day - 6)
		2: first_day = maxi(1, state.day - 29)
		3: first_day = 1
	view.add_child(app.label(Calendar.format_range(first_day, last_day), 14, Style.GOLD))
	var campaigns: Dictionary = state.advertising.campaigns
	var ids: Array = campaigns.keys()
	ids.sort()
	var platform_choices := ["All Platforms"]
	for platform in Ads.PLATFORMS: platform_choices.append(platform.name)
	view.add_child(app.label("Advertising Platform", 14, Style.MUTED))
	var platform_filter: OptionButton = app.dropdown(view, platform_choices, app.ad_platform_filter + 1)
	platform_filter.item_selected.connect(func(index: int): app.ad_platform_filter = index - 1; app.render())
	var status_choices := ["All Statuses", "Draft", "Active", "Paused", "Stopped"]
	view.add_child(app.label("Campaign Status", 14, Style.MUTED))
	var status_filter: OptionButton = app.dropdown(view, status_choices, app.ad_status_filter + 1)
	status_filter.item_selected.connect(func(index: int): app.ad_status_filter = index - 1; app.render())
	var destination_ids: Array[int] = [-1]
	var destination_names: Array[String] = ["All Destinations"]
	for store in state.stores:
		destination_ids.append(int(store.id))
		var kind: String = Stores.MARKETPLACES[int(store.platform)] if int(store.type) == 0 and int(store.get("platform", -1)) in range(Stores.MARKETPLACES.size()) else "Website"
		var suffix: String = str(store.domain) if int(store.type) == 1 else kind
		destination_names.append("%s · %s" % [store.name, suffix])
	view.add_child(app.label("Destination", 14, Style.MUTED))
	var destination_index: int = destination_ids.find(app.ad_store_filter)
	var destination_filter: OptionButton = app.dropdown(view, destination_names, maxi(0, destination_index))
	destination_filter.item_selected.connect(func(index: int):
		app.ad_store_filter = destination_ids[index]
		app.render()
	)
	var product_choices: Array[String] = ["All Products"]
	for item in Catalog.PRODUCTS: product_choices.append(item.name)
	view.add_child(app.label("Product", 14, Style.MUTED))
	var product_filter: OptionButton = app.dropdown(view, product_choices, app.ad_product_filter + 1)
	product_filter.item_selected.connect(func(index: int): app.ad_product_filter = index - 1; app.render())
	var matched: Array = []
	var totals := Ads.empty_metrics()
	for id in ids:
		var campaign: Dictionary = campaigns[id]
		if app.ad_platform_filter >= 0 and int(campaign.platform) != app.ad_platform_filter: continue
		if app.ad_status_filter >= 0 and campaign.status != ["draft", "active", "paused", "stopped"][app.ad_status_filter]: continue
		if app.ad_store_filter >= 0 and int(campaign.store_id) != app.ad_store_filter: continue
		if app.ad_product_filter >= 0 and int(campaign.product) != app.ad_product_filter: continue
		matched.append(id)
		var metrics: Dictionary = Ads.aggregate_range(state, int(id), first_day, last_day)
		for field in Ads.METRIC_FIELDS: totals[field] += int(metrics.get(field, 0))
	var total_conversions: int = maxi(0, totals.purchases + totals.preorders - totals.preorders_cancelled)
	var total_ctr := _ratio(totals.clicks, totals.impressions, 100.0)
	var total_cpc := _unit_cost(app, totals.spend, totals.clicks)
	var total_cpm := _unit_cost(app, totals.spend * 1000, totals.impressions)
	var total_conversion_rate := _ratio(total_conversions, totals.clicks, 100.0)
	var total_cpa := _unit_cost(app, totals.spend, total_conversions)
	var total_roas: String = "%.2f×" % (float(totals.attributed_revenue) / totals.spend) if totals.spend > 0 else "—"
	app.metric(view, "Campaigns matched", str(matched.size()))
	app.metric(view, "Advertising Spend", app.money(totals.spend))
	app.metric(view, "Impressions · Clicks", "%s · %s" % [_count(totals.impressions), _count(totals.clicks)])
	app.metric(view, "CTR · CPC · CPM", "%s · %s · %s" % [total_ctr, total_cpc, total_cpm])
	app.metric(view, "Conversions · Conversion Rate · CPA", "%d · %s · %s" % [total_conversions, total_conversion_rate, total_cpa])
	app.metric(view, "Attributed Revenue · ROAS", "%s · %s" % [app.money(totals.attributed_revenue - totals.attributed_refunds), total_roas], Style.GOLD)
	var outstanding := 0
	for order in state.orders.values():
		if not order.get("preorder", false) or order.status in ["delivered", "cancelled"]: continue
		if int(order.get("campaign_id", 0)) <= 0: continue
		var campaign: Dictionary = campaigns.get(int(order.campaign_id), {})
		if campaign.is_empty(): continue
		if app.ad_platform_filter >= 0 and int(campaign.platform) != app.ad_platform_filter: continue
		if app.ad_status_filter >= 0 and campaign.status != ["draft", "active", "paused", "stopped"][app.ad_status_filter]: continue
		if app.ad_store_filter >= 0 and int(order.store_id) != app.ad_store_filter: continue
		if app.ad_product_filter >= 0 and int(campaign.product) != app.ad_product_filter: continue
		outstanding += 1
	app.metric(view, "Outstanding Pre-orders", str(outstanding))
	view.add_child(app.label("Revenue is attributed to pre-order campaigns only when delivery recognizes the sale. Pre-order placements and cancellations are shown separately in campaign history.", 13, Style.MUTED))
	if matched.is_empty():
		view.add_child(app.label("No campaigns match these filters.", 14, Style.MUTED))
		return
	for id in matched:
		var campaign: Dictionary = campaigns[id]
		var metrics: Dictionary = Ads.aggregate_range(state, int(id), first_day, last_day)
		var detail: VBoxContainer = app.card(campaign.name)
		var store: Dictionary = Stores.get_store(state, int(campaign.store_id))
		app.metric(detail, "Platform · Status", "%s · %s" % [Ads.PLATFORMS[campaign.platform].name, campaign.status.capitalize()])
		app.metric(detail, "Destination · Product", "%s · %s" % [store.get("name", "Unknown store"), Catalog.PRODUCTS[campaign.product].name])
		app.metric(detail, "Advertising Spend", app.money(metrics.spend))
		app.metric(detail, "Impressions", _count(metrics.impressions))
		app.metric(detail, "Clicks", _count(metrics.clicks))
		app.metric(detail, "CTR", _ratio(metrics.clicks, metrics.impressions, 100.0))
		app.metric(detail, "CPC", _unit_cost(app, metrics.spend, metrics.clicks))
		app.metric(detail, "CPM", _unit_cost(app, metrics.spend * 1000, metrics.impressions))
		var conversions: int = maxi(0, metrics.purchases + metrics.preorders - metrics.preorders_cancelled)
		app.metric(detail, "Conversions", str(conversions))
		app.metric(detail, "Conversion Rate", _ratio(conversions, metrics.clicks, 100.0))
		app.metric(detail, "CPA", _unit_cost(app, metrics.spend, conversions))
		app.metric(detail, "Attributed Revenue", app.money(metrics.attributed_revenue - metrics.attributed_refunds))
		app.metric(detail, "ROAS", "%.2f×" % metrics.roas if metrics.spend > 0 else "—", Style.GOLD)
		app.metric(detail, "Pre-orders Placed · Cancelled", "%d · %d" % [metrics.preorders, metrics.preorders_cancelled])
		if metrics.spend == 0 and metrics.impressions == 0:
			detail.add_child(app.label("No delivery data is available for this campaign in the selected period.", 13, Style.MUTED))
		var profit: int = metrics.attributed_revenue - metrics.attributed_refunds - metrics.estimated_costs + metrics.estimated_costs_reversed - metrics.spend
		app.metric(detail, "Estimated Advertising Profit", app.money(profit), app.profit_color(profit))
		app.action(detail, "Manage Campaign", func():
			app.campaign_id = id
			app.navigate("Campaign Details")
		)

static func _ratio(numerator: int, denominator: int, scale: float) -> String:
	return "%.2f%%" % (float(numerator) / denominator * scale) if denominator > 0 else "—"

static func _unit_cost(app: Control, amount: int, denominator: int) -> String:
	return app.money(roundi(float(amount) / denominator)) if denominator > 0 else "—"

static func _fill_store_choices(state: Dictionary, store_id: int, product_ids: Array[int], product_names: Array[String], platform_ids: Array[int], platform_names: Array[String]) -> void:
	var store := Stores.get_store(state, store_id)
	if store.is_empty() or not store.active: return
	for product in Catalog.PRODUCTS.size():
		var listing := Stores.listing(state, store_id, product)
		if listing.get("listed", false):
			product_ids.append(product)
			product_names.append(Catalog.PRODUCTS[product].name + (" · unpublished" if not listing.get("listed", false) else ""))
	for id in Ads.PLATFORMS.size():
		if Ads.platform_available(state.country, id, store):
			platform_ids.append(id)
			platform_names.append(Ads.PLATFORMS[id].name)

static func _lifetime(state: Dictionary, campaign_id: int) -> Dictionary:
	var result := Ads.empty_metrics()
	for record in state.advertising.history:
		if record.campaign_id != campaign_id: continue
		for field in Ads.METRIC_FIELDS: result[field] += int(record.get(field, 0))
	result.roas = float(result.attributed_revenue) / result.spend if result.spend > 0 else 0.0
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
