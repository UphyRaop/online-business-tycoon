extends RefCounted

const Catalog = preload("res://catalog.gd")
const Ads = preload("res://advertising.gd")
const Stores = preload("res://store_manager.gd")
const Calendar = preload("res://game_calendar.gd")
const Style = preload("res://corporate_theme.gd")
const AdsChart = preload("res://ads_chart.gd")
const ChartLegend = preload("res://chart_legend.gd")

static func overview(app: Control) -> void:
	var view: VBoxContainer = app.card("Advertising Overview")
	var campaigns: Dictionary = app.sim.state.advertising.campaigns
	var active := 0
	var totals := Ads.empty_metrics()
	for id in campaigns:
		var campaign: Dictionary = campaigns[id]
		if campaign.status == "active" and not bool(campaign.get("deleted", false)): active += 1
		var metric: Dictionary = _lifetime(app.sim.state, id)
		for field in Ads.METRIC_FIELDS + ["estimated_profit"]: totals[field] += int(metric.get(field, 0))
	var kpis := GridContainer.new()
	kpis.columns = 3 if app.size.x >= 900.0 else 2
	kpis.add_theme_constant_override("h_separation", 8)
	kpis.add_theme_constant_override("v_separation", 8)
	view.add_child(kpis)
	_analytics_kpi(app, kpis, "Active Campaigns", str(active))
	_analytics_kpi(app, kpis, "Ad Spend", app.money(totals.spend))
	_analytics_kpi(app, kpis, "Attributed Revenue", app.money(totals.attributed_revenue - totals.attributed_refunds))
	var roas: String = "%.2f×" % (float(totals.attributed_revenue) / totals.spend) if totals.spend > 0 else "—"
	var lifetime_conversions: int = maxi(0, totals.purchases + totals.preorders - totals.preorders_cancelled)
	_analytics_pair_kpi(app, kpis, "ROAS · CPA", "ROAS", roas, "CPA", _unit_cost(app, totals.spend, lifetime_conversions), "MarketingKPI_ROAS_CPA")
	_analytics_kpi(app, kpis, "Purchases", _count(totals.purchases))
	_analytics_pair_kpi(app, kpis, "CTR · CPM", "CTR", "%.2f%%" % Ads.ctr_percent(totals.clicks, totals.impressions), "CPM", app.money(roundi(Ads.cpm_cents(totals.spend, totals.impressions))), "MarketingKPI_CTR_CPM")
	var profit: int = int(totals.attributed_revenue) - int(totals.attributed_refunds) - int(totals.estimated_costs) + int(totals.estimated_costs_reversed) - int(totals.spend)
	app.metric(view, "Estimated Advertising Profit", app.money(profit), app.profit_color(profit))
	var platform_card: VBoxContainer = app.card("Platforms")
	for platform in Ads.PLATFORMS:
		var baseline_cpm: String = app.money(Catalog.local_cents(int(app.sim.state.country), float(platform.cpm)))
		platform_card.add_child(app.label("%s · %s CPM · %.1f%% baseline CTR" % [platform.name, baseline_cpm, platform.ctr], 14, Style.MUTED))

static func manager(app: Control) -> void:
	var view: VBoxContainer = app.card("")
	app.action(view, "Create campaign", func():
		app.campaign_id = 0
		app.navigate("Campaign Details")
	, true)
	var ids: Array = app.sim.state.advertising.campaigns.keys()
	ids.sort()
	var visible_campaigns := 0
	for id in ids:
		var campaign: Dictionary = app.sim.state.advertising.campaigns[id]
		if bool(campaign.get("deleted", false)): continue
		visible_campaigns += 1
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
	if visible_campaigns == 0:
		view.add_child(app.label("No campaigns are available in Ads Manager. Create a campaign to promote a published product in an active store.", 14, Style.MUTED))

static func details(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var creating: bool = app.campaign_id == 0
	var existing: Dictionary = state.advertising.campaigns.get(app.campaign_id, {})
	if not creating and (existing.is_empty() or bool(existing.get("deleted", false))):
		app.set_notice("Campaign not found.", true)
		app.navigate("Campaign Manager")
		return
	var view: VBoxContainer = app.card("Create Campaign" if creating else existing.name)
	if not creating and not app.campaign_editing:
		_campaign_summary(app, view, state, existing)
		return
	var store_ids: Array[int] = []
	var store_names: Array[String] = []
	for store in state.stores:
		if store.active:
			store_ids.append(int(store.id))
			store_names.append(str(store.name))
	if store_ids.is_empty():
		view.add_child(app.label("Create a store before launching an advertising campaign.", 14, Style.MUTED))
		return
	var selected_store: int = int(existing.get("store_id", store_ids[0])) if not creating else store_ids[0]
	if selected_store not in store_ids:
		view.add_child(app.label("This campaign's destination is inactive. Activate an eligible store before editing it.", 14, Style.MUTED))
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
		app.action(view, "Save Changes", save_campaign.bind(existing.status == "draft"), true)
		if existing.status != "stopped":
			app.action(view, "Save as Draft", save_campaign.bind(true))
	app.action(view, "Cancel", func():
		app.edit_checks.clear()
		app.campaign_editing = false
		app.set_notice("")
		if creating:
			app.campaign_id = 0
			app.page = "Campaign Manager"
			app.category_last_page["Business"] = "Campaign Manager"
			app.render()
		else:
			app.refresh_view()
	)
	if not creating:
		_campaign_controls(app, view, state, existing)

static func _campaign_summary(app: Control, view: VBoxContainer, state: Dictionary, existing: Dictionary) -> void:
	var store := Stores.get_store(state, int(existing.store_id))
	var product_index := int(existing.get("product", 0))
	var platform_index := int(existing.get("platform", 0))
	app.metric(view, "Status", str(existing.status).capitalize(), Style.GOLD)
	app.metric(view, "Destination Store", str(store.get("name", "Missing store")))
	app.metric(view, "Product", Catalog.PRODUCTS[product_index].name if product_index in range(Catalog.PRODUCTS.size()) else "Unavailable")
	app.metric(view, "Advertising Platform", Ads.PLATFORMS[platform_index].name if platform_index in range(Ads.PLATFORMS.size()) else "Unavailable")
	app.metric(view, "Objective", Ads.OBJECTIVES[int(existing.objective)])
	app.metric(view, "Daily Budget", app.money(int(existing.daily_budget)))
	app.metric(view, "Audience", Ads.AUDIENCES[int(existing.audience)])
	app.metric(view, "Bidding Strategy", Ads.BIDS[int(existing.bid_strategy)])
	app.metric(view, "Bid Limit", app.money(int(existing.bid)))
	app.metric(view, "Creative Format", Ads.CREATIVES[int(existing.creative)])
	app.metric(view, "Campaign Schedule", "Day %d%s" % [int(existing.start_day), " · End day %d" % int(existing.end_day) if int(existing.end_day) > 0 else " · No end date"])
	if existing.status in ["stopped", "completed"]:
		var stopped_schedule_expired: bool = existing.status == "stopped" and int(existing.get("end_day", 0)) > 0 and int(existing.end_day) < state.day
		var explanation := "This campaign's scheduled end date has passed. Duplicate it to create a new campaign; its history is retained." if stopped_schedule_expired else ("This campaign was stopped. It can be reactivated while its schedule remains valid; its history is retained." if existing.status == "stopped" else "This campaign's schedule is complete. Its history is retained.")
		view.add_child(app.label(explanation, 14, Style.MUTED))
		app.action(view, "Duplicate", func():
			var error := Ads.duplicate_stopped(state, app.campaign_id)
			if not error.is_empty():
				app.set_notice(error, true)
				return
			app.campaign_id = state.advertising.next_campaign - 1
			app.campaign_editing = false
			app.persist("Campaign duplicated as a draft.")
			app.refresh_view()
		)
	else:
		app.action(view, "Edit Campaign", func():
			app.campaign_editing = true
			app.refresh_view()
		)
	_campaign_controls(app, view, state, existing)
	var metrics: Dictionary = _lifetime(state, app.campaign_id)
	app.metric(view, "Lifetime Ad Spend", app.money(metrics.spend))
	app.metric(view, "Attributed Purchases · Revenue", "%s · %s" % [_count(metrics.purchases), app.money(metrics.attributed_revenue - metrics.attributed_refunds)])
	app.metric(view, "ROAS · CPA", "%.2f× · %s" % [metrics.roas, _average_cost(app, metrics.spend, metrics.purchases)])

static func _campaign_controls(app: Control, view: VBoxContainer, state: Dictionary, existing: Dictionary) -> void:
	var schedule_expired: bool = int(existing.get("end_day", 0)) > 0 and int(existing.end_day) < state.day
	if existing.status != "completed" and not (existing.status == "stopped" and schedule_expired):
		var control_row: HBoxContainer = app.row(view)
		var next_status := "Pause" if existing.status == "active" else ("Launch" if existing.status == "draft" else ("Reactivate Campaign" if existing.status == "stopped" else "Resume"))
		app.action(control_row, next_status, func():
			var error := Ads.set_status(state, app.campaign_id, "paused" if existing.status == "active" else "active")
			if not error.is_empty():
				app.set_notice(error, true)
				return
			app.campaign_editing = false
			app.persist("Campaign %s." % ("paused" if existing.status == "active" else ("reactivated" if existing.status == "stopped" else "resumed")))
			app.refresh_view()
		)
		if existing.status != "stopped":
			app.action(control_row, "Stop", func():
				app.confirm_action("Stop campaign?", "You can reactivate it before its schedule ends. Its history remains available.", "Stop Campaign", func():
					var error := Ads.set_status(state, app.campaign_id, "stopped")
					if not error.is_empty():
						app.set_notice(error, true)
						return
					app.campaign_editing = false
					app.persist("Campaign stopped.")
					app.refresh_view()
				)
			)
	app.action(view, "Delete Campaign", func():
		app.confirm_action("Archive This Campaign?", "It will stop spending and disappear from Ads Manager. Its ad spend, attributed sales and analytics history will remain available.", "Archive Campaign", func():
			var error := Ads.archive(state, app.campaign_id)
			if not error.is_empty():
				app.set_notice(error, true)
				return
			app.campaign_editing = false
			app.persist("Campaign archived. Historical reporting is preserved.")
			app.navigate("Campaign Manager")
		)
	)

static func analytics(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var campaigns: Dictionary = state.advertising.campaigns
	var ids: Array = campaigns.keys()
	ids.sort()
	# The page heading already labels this route. Keep the analytics surface focused
	# on its reporting controls instead of repeating the same heading inside the card.
	var view: VBoxContainer = app.wide_card("")
	var period_choices := ["Daily · Last 7 Days", "Weekly · Last 8 Weeks", "Monthly · Last 12 Months", "All Time"]
	view.add_child(app.label("Reporting Period", 14, Style.MUTED))
	var periods: OptionButton = app.dropdown(view, period_choices, clampi(app.ad_period, 0, 3))
	periods.item_selected.connect(func(index: int): app.ad_period = index; app.render())
	var buckets: Array[Dictionary] = _analytics_buckets(state, app.ad_period)
	var first_day := int(buckets.front().start) if not buckets.is_empty() else 1
	var last_day: int = int(buckets.back().end) if not buckets.is_empty() else 0
	view.add_child(app.label("No completed days" if last_day == 0 else Calendar.format_range(first_day, last_day), 14, Style.GOLD))
	var filters: VBoxContainer = _analytics_card(app, view, "Filters")
	var platform_choices := ["All Platforms"]
	for platform in Ads.PLATFORMS: platform_choices.append(platform.name)
	filters.add_child(app.label("Advertising Platform", 13, Style.MUTED))
	var platform_filter: OptionButton = app.dropdown(filters, platform_choices, app.ad_platform_filter + 1)
	platform_filter.item_selected.connect(func(index: int): app.ad_platform_filter = index - 1; app.render())
	var campaign_statuses := ["draft", "active", "paused", "stopped", "completed"]
	var status_choices := ["All Status", "Draft", "Active", "Paused", "Stopped", "Completed", "Archived"]
	filters.add_child(app.label("Campaign Status", 13, Style.MUTED))
	var status_filter: OptionButton = app.dropdown(filters, status_choices, app.ad_status_filter + 1)
	status_filter.item_selected.connect(func(index: int): app.ad_status_filter = index - 1; app.render())
	var store_ids: Array[int] = [-1]
	var store_names: Array[String] = ["All Stores"]
	for store in state.stores:
		store_ids.append(int(store.id))
		store_names.append(str(store.name))
	filters.add_child(app.label("Destination Store", 13, Style.MUTED))
	var store_filter: OptionButton = app.dropdown(filters, store_names, maxi(0, store_ids.find(app.ad_store_filter)))
	store_filter.item_selected.connect(func(index: int): app.ad_store_filter = store_ids[index]; app.render())
	var matched: Array[int] = []
	var totals := Ads.empty_metrics()
	for raw_id in ids:
		var id := int(raw_id)
		var campaign: Dictionary = campaigns[id]
		if app.ad_platform_filter >= 0 and int(campaign.platform) != app.ad_platform_filter: continue
		if app.ad_status_filter == campaign_statuses.size():
			if not bool(campaign.get("deleted", false)): continue
		elif app.ad_status_filter >= 0:
			if bool(campaign.get("deleted", false)) or campaign.status != campaign_statuses[app.ad_status_filter]: continue
		if app.ad_store_filter >= 0 and int(campaign.store_id) != app.ad_store_filter: continue
		matched.append(id)
		var metrics := Ads.aggregate_range(state, id, first_day, last_day)
		for field in Ads.METRIC_FIELDS: totals[field] += int(metrics.get(field, 0))
	var roas := "%.2f×" % (float(totals.attributed_revenue) / totals.spend) if totals.spend > 0 else "Unavailable"
	var ctr := "%.2f%%" % Ads.ctr_percent(totals.clicks, totals.impressions) if totals.impressions > 0 else "Unavailable"
	var cpm: String = app.money(roundi(Ads.cpm_cents(totals.spend, totals.impressions))) if totals.impressions > 0 else "Unavailable"
	var kpis := GridContainer.new()
	kpis.columns = 3 if app.size.x >= 700.0 else 2
	kpis.add_theme_constant_override("h_separation", 10)
	kpis.add_theme_constant_override("v_separation", 10)
	view.add_child(kpis)
	_analytics_kpi(app, kpis, "Total Ad Spend", app.money(totals.spend))
	_analytics_kpi(app, kpis, "Attributed Revenue", app.money(totals.attributed_revenue - totals.attributed_refunds))
	_analytics_kpi(app, kpis, "ROAS", roas)
	_analytics_kpi(app, kpis, "Impressions", _count(totals.impressions))
	_analytics_kpi(app, kpis, "Clicks", _count(totals.clicks))
	_analytics_kpi(app, kpis, "Purchases", _count(totals.purchases))
	_analytics_kpi(app, kpis, "CTR", ctr)
	_analytics_kpi(app, kpis, "CPM", cpm)
	var daily_spend: Array[float] = []
	var daily_revenue: Array[float] = []
	var daily_roas: Array[float] = []
	var daily_clicks: Array[float] = []
	var daily_purchases: Array[float] = []
	var bucket_labels: Array[String] = []
	for bucket in buckets:
		var summary := Ads.empty_metrics()
		for campaign_id in matched:
			var item := Ads.aggregate_range(state, campaign_id, int(bucket.start), int(bucket.end))
			for field in Ads.METRIC_FIELDS: summary[field] += int(item.get(field, 0))
		daily_spend.append(float(summary.spend))
		daily_revenue.append(float(summary.attributed_revenue - summary.attributed_refunds))
		daily_roas.append(float(summary.attributed_revenue) / float(summary.spend) if summary.spend > 0 else 0.0)
		daily_clicks.append(float(summary.clicks))
		daily_purchases.append(float(summary.purchases))
		bucket_labels.append(str(bucket.label))
	_add_analytics_chart(app, view, "Ad Spend vs. Attributed Revenue", bucket_labels, [
		{"name": "Ad Spend", "values": daily_spend, "color": Style.GOLD},
		{"name": "Revenue", "values": daily_revenue, "color": Style.GREEN}])
	_add_analytics_chart(app, view, "ROAS Trend", bucket_labels, [{"name": "ROAS", "values": daily_roas, "color": Color("#83b7ff")}])
	_add_analytics_chart(app, view, "Clicks and Purchases", bucket_labels, [
		{"name": "Clicks", "values": daily_clicks, "color": Color("#83b7ff")},
		{"name": "Purchases", "values": daily_purchases, "color": Style.GREEN}])
	view.add_child(app.label("Revenue follows existing campaign attribution and refund records. Pre-order revenue is counted when delivery recognizes the sale; unavailable activity is shown as zero for recorded periods.", 13, Style.MUTED))
	var by_platform: VBoxContainer = _analytics_card(app, view, "Performance by Platform")
	for platform_id in Ads.PLATFORMS.size():
		var platform_metrics := Ads.empty_metrics()
		for campaign_id in matched:
			if int(campaigns[campaign_id].platform) != platform_id: continue
			var item := Ads.aggregate_range(state, campaign_id, first_day, last_day)
			for field in Ads.METRIC_FIELDS: platform_metrics[field] += int(item.get(field, 0))
		if platform_metrics.spend == 0 and platform_metrics.impressions == 0 and platform_metrics.attributed_revenue == 0: continue
		var platform_roas := "%.2f×" % (float(platform_metrics.attributed_revenue) / platform_metrics.spend) if platform_metrics.spend > 0 else "Unavailable"
		app.metric(by_platform, str(Ads.PLATFORMS[platform_id].name), "%s spend · %s revenue · %s ROAS" % [app.money(platform_metrics.spend), app.money(platform_metrics.attributed_revenue - platform_metrics.attributed_refunds), platform_roas])
	var by_store: VBoxContainer = _analytics_card(app, view, "Performance by Store")
	var populated_stores := 0
	for store in state.stores:
		var store_metrics := Ads.empty_metrics()
		for campaign_id in matched:
			if int(campaigns[campaign_id].store_id) != int(store.id): continue
			var item := Ads.aggregate_range(state, campaign_id, first_day, last_day)
			for field in Ads.METRIC_FIELDS: store_metrics[field] += int(item.get(field, 0))
		if store_metrics.spend == 0 and store_metrics.attributed_revenue == 0 and store_metrics.clicks == 0: continue
		populated_stores += 1
		var store_roas := "%.2f×" % (float(store_metrics.attributed_revenue) / store_metrics.spend) if store_metrics.spend > 0 else "Unavailable"
		app.metric(by_store, str(store.name), "%s spend · %s net revenue · %s ROAS" % [app.money(store_metrics.spend), app.money(store_metrics.attributed_revenue - store_metrics.attributed_refunds), store_roas])
	if populated_stores == 0:
		by_store.add_child(app.label("No store activity was recorded for the selected period.", 13, Style.MUTED))
	view.add_child(app.label("ROAS uses gross attributed revenue divided by ad spend. Revenue shown in KPIs and store breakdowns deducts recorded refunds.", 13, Style.MUTED))
	var table: VBoxContainer = _analytics_card(app, view, "Campaign Performance")
	if matched.is_empty():
		table.add_child(app.empty_state("No Matching Campaigns", "Change the filters to view campaign activity."))
		return
	for campaign_id in matched:
		var campaign: Dictionary = campaigns[campaign_id]
		var metrics := Ads.aggregate_range(state, campaign_id, first_day, last_day)
		var campaign_ctr := "%.2f%%" % Ads.ctr_percent(metrics.clicks, metrics.impressions) if metrics.impressions > 0 else "Unavailable"
		var campaign_cpm: String = app.money(roundi(Ads.cpm_cents(metrics.spend, metrics.impressions))) if metrics.impressions > 0 else "Unavailable"
		var campaign_cpc: String = app.money(roundi(metrics.cpc)) if metrics.clicks > 0 else "Unavailable"
		var conversions: int = maxi(0, int(metrics.purchases) + int(metrics.preorders) - int(metrics.preorders_cancelled))
		var campaign_cpa: String = app.money(roundi(float(metrics.spend) / conversions)) if conversions > 0 else "Unavailable"
		var campaign_status := "Archived" if bool(campaign.get("deleted", false)) else str(campaign.status).capitalize()
		var detail: VBoxContainer = _analytics_card(app, table, str(campaign.name))
		var summary: HBoxContainer = app.row(detail)
		var summary_label: Label = app.label("%s · %s" % [str(Ads.PLATFORMS[int(campaign.platform)].name), campaign_status], 13, Style.MUTED)
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_child(summary_label)
		var expanded := bool(app.ad_expanded_campaigns.get(campaign_id, false))
		app.action(summary, "Hide Metrics" if expanded else "Metrics", func():
			app.ad_expanded_campaigns[campaign_id] = not bool(app.ad_expanded_campaigns.get(campaign_id, false))
			app.render()
		)
		app.metric(detail, "Spend", app.money(int(metrics.spend)))
		app.metric(detail, "Net Attributed Revenue", app.money(int(metrics.attributed_revenue) - int(metrics.attributed_refunds)))
		app.metric(detail, "ROAS", "%.2f×" % float(metrics.roas) if metrics.spend > 0 else "Unavailable")
		if expanded:
			for data in [
				["Impressions", _count(metrics.impressions)], ["Reach", _count(metrics.reach)],
				["Clicks", _count(metrics.clicks)], ["CTR", campaign_ctr], ["CPC", campaign_cpc], ["CPM", campaign_cpm],
				["Add to Cart", _count(metrics.add_to_cart)], ["Checkouts", _count(metrics.checkouts)],
				["Purchases", _count(metrics.purchases)], ["Conversions", _count(conversions)], ["CPA", campaign_cpa],
				["Status", campaign_status],
			]:
				app.metric(detail, str(data[0]), str(data[1]))

static func _analytics_kpi(app: Control, parent: Control, title: String, value: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 10, 12))
	var content := VBoxContainer.new()
	content.add_child(app.label(title, 13, Style.MUTED))
	content.add_child(app.label(value, 18, Style.GOLD))
	panel.add_child(content)
	parent.add_child(panel)

static func _analytics_pair_kpi(app: Control, parent: Control, title: String, first_name: String, first_value: String, second_name: String, second_value: String, control_name: String) -> void:
	var panel := PanelContainer.new()
	panel.name = control_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 10, 12))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.add_child(app.label(title, 13, Style.MUTED))
	for metric in [[first_name, first_value], [second_name, second_value]]:
		var metric_row := HBoxContainer.new()
		metric_row.add_theme_constant_override("separation", 6)
		var metric_label: Label = app.label(str(metric[0]), 11, Style.MUTED)
		metric_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metric_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var value_label: Label = app.label(str(metric[1]), 14, Style.GOLD)
		value_label.name = "%sValue" % str(metric[0]).replace(" ", "")
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		metric_row.add_child(metric_label)
		metric_row.add_child(value_label)
		content.add_child(metric_row)
	panel.add_child(content)
	parent.add_child(panel)

static func _analytics_card(app: Control, parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.LINE, 12, 14))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.add_child(app.label(title, 18))
	panel.add_child(content)
	parent.add_child(panel)
	return content

static func _add_analytics_chart(app: Control, parent: Control, title: String, labels: Array[String], series: Array[Dictionary]) -> void:
	var chart_card: VBoxContainer = _analytics_card(app, parent, title)
	var chart: Control = AdsChart.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.configure(labels, series)
	chart_card.add_child(chart)
	chart_card.add_child(ChartLegend.build(series))

static func _analytics_buckets(state: Dictionary, selected_period: int) -> Array[Dictionary]:
	var buckets: Array[Dictionary] = []
	var last_completed := int(state.get("day", 1)) - 1
	if last_completed <= 0: return buckets
	if selected_period == 0:
		for day in range(maxi(1, last_completed - 6), last_completed + 1): buckets.append({"start": day, "end": day, "label": "Day %d" % day})
	elif selected_period == 1:
		var first := maxi(1, last_completed - 55)
		var cursor := first
		while cursor <= last_completed:
			var last := mini(last_completed, cursor + 6)
			buckets.append({"start": cursor, "end": last, "label": "W%d" % (buckets.size() + 1)})
			cursor = last + 1
	elif selected_period == 2:
		var current := Calendar.date_at(last_completed)
		var year := int(current.year)
		var month := int(current.month) - 11
		while month <= 0:
			month += 12
			year -= 1
		for _index in 12:
			var start := maxi(1, Calendar.day_at(year, month, 1))
			var next_year := year + (1 if month == 12 else 0)
			var next_month := 1 if month == 12 else month + 1
			var finish := mini(last_completed, Calendar.day_at(next_year, next_month, 1) - 1)
			if start <= last_completed: buckets.append({"start": start, "end": maxi(start, finish), "label": "%s %02d" % [Calendar.MONTHS[month - 1], year % 100]})
			month += 1
			if month > 12:
				month = 1
				year += 1
	else:
		var first_month := Calendar.date_at(1)
		var last_month := Calendar.date_at(last_completed)
		var month_count := (int(last_month.year) - int(first_month.year)) * 12 + int(last_month.month) - int(first_month.month) + 1
		var year := int(first_month.year)
		var month := int(first_month.month)
		for _index in mini(month_count, 120):
			var start := maxi(1, Calendar.day_at(year, month, 1))
			var next_year := year + (1 if month == 12 else 0)
			var next_month := 1 if month == 12 else month + 1
			var finish := mini(last_completed, Calendar.day_at(next_year, next_month, 1) - 1)
			buckets.append({"start": start, "end": finish, "label": "%s %02d" % [Calendar.MONTHS[month - 1], year % 100]})
			month += 1
			if month > 12:
				month = 1
				year += 1
	return buckets

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
			product_names.append(Catalog.PRODUCTS[product].name)
	for id in Ads.PLATFORMS.size():
		if Ads.platform_available(state.country, id, store):
			platform_ids.append(id)
			platform_names.append(Ads.PLATFORMS[id].name)

static func _lifetime(state: Dictionary, campaign_id: int) -> Dictionary:
	return Ads.aggregate_range(state, campaign_id, 1, int(state.get("day", 1)) - 1)

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
	var absolute := str(absi(value))
	var grouped := ""
	for index in absolute.length():
		if index > 0 and (absolute.length() - index) % 3 == 0: grouped += ","
		grouped += absolute.substr(index, 1)
	return ("−" if value < 0 else "") + grouped
