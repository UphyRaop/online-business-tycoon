extends RefCounted

const Catalog = preload("res://catalog.gd")
const Stores = preload("res://store_manager.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Calendar = preload("res://game_calendar.gd")
const Style = preload("res://corporate_theme.gd")
const Offers = preload("res://offer_view.gd")
const Finance = preload("res://finance_management.gd")

static func management(app: Control) -> void:
	var intro: VBoxContainer = app.card("Store Management · %s" % app.sim.state.company)
	intro.add_child(app.label("Manage marketplace stores and websites here. Inventory is shared, while each destination keeps its own listings, costs, sales, and campaigns.", 14, Style.MUTED))
	var stores: VBoxContainer = app.card("Owned stores · %d" % app.sim.state.stores.size())
	for store in app.sim.state.stores:
		var id: int = store.id
		var card: VBoxContainer = app.stack(stores, 7)
		app.divider(card)
		var market: int = store.get("platform", -1)
		var detail: String = Stores.MARKETPLACES[market] if store.type == 0 and market >= 0 else ("Marketplace" if store.type == 0 else _website_summary(store))
		app.metric(card, str(store.name), detail + (" · Active" if store.active else " · Paused"))
		app.metric(card, "Brand", store.brand)
		app.metric(card, "Additional daily store cost", app.money(store.daily_cost))
		var result: Dictionary = Stores.report(app.sim.state, id)
		var profit: int = result.sales - result.refunds - result.cogs - result.fees - result.shipping - result.advertising - result.setup - result.operating
		app.metric(card, "Lifetime store sales", app.money(result.sales - result.refunds))
		app.metric(card, "Advertising · Setup · Operations", "%s · %s · %s" % [
			app.money(result.advertising), app.money(result.setup), app.money(result.operating)], Style.MUTED)
		app.metric(card, "Store profit", app.money(profit), app.profit_color(profit))
		var actions: HBoxContainer = app.row(card)
		app.action(actions, "Inventory Management", func():
			app.navigate("My Products")
		)
		var status: String = "Deactivate" if store.active else "Activate"
		app.action(actions, status, app.set_store_active.bind(id, not store.active))
	var open_form: Button = app.action(intro, "Open New Store", func():
		app.show_new_store_form = true
		app.refresh_view()
	, true)
	open_form.visible = not app.show_new_store_form
	if app.show_new_store_form:
		var setup: VBoxContainer = app.card("Open a new store")
		var name: LineEdit = app.field(setup, "Store name", "", 40)
		var brand: LineEdit = app.field(setup, "Brand name", app.sim.state.brand, 40)
		var kind: OptionButton = app.dropdown(setup, ["Marketplace", "Website"], 0)
		var domain: LineEdit = app.field(setup, "Website domain (required for Website)", "", 64)
		var domain_label := setup.get_child(setup.get_child_count() - 2) as Label
		var platform: OptionButton = app.dropdown(setup, Stores.MARKETPLACES, 0)
		var website_platform_names: Array[String] = []
		website_platform_names.append("Select Website Platform")
		for value in Stores.WEBSITE_PLATFORMS: website_platform_names.append(value.name)
		var website_platform_label: Label = app.label("Website platform", 14, Style.MUTED)
		setup.add_child(website_platform_label)
		website_platform_label.visible = false
		var website_platform: OptionButton = app.dropdown(setup, website_platform_names, 0)
		var website_platform_note: Label = app.label("Website platform values are simulated for gameplay and do not represent current real-world prices.", 13, Style.MUTED)
		setup.add_child(website_platform_note)
		website_platform_note.visible = kind.selected == 1
		var cost: Label = app.label("", 14, Style.GOLD)
		setup.add_child(cost)
		var update_cost := func(_index: int = 0):
			platform.visible = kind.selected == 0
			website_platform.visible = kind.selected == 1
			website_platform_label.visible = kind.selected == 1
			website_platform_note.visible = kind.selected == 1
			domain_label.visible = kind.selected == 1
			domain.visible = kind.selected == 1
			var setup_platform := website_platform.selected - 1 if kind.selected == 1 and website_platform.selected > 0 else -1
			if kind.selected == 1 and setup_platform < 0:
				cost.text = "Select a website platform to see its simulated costs."
				return
			cost.text = "Setup %s · Recurring %s per game day · Transaction fee %.1f%%" % [
				app.money(Stores.setup_cost(app.sim.state.country, kind.selected, setup_platform)),
				app.money(Stores.daily_cost(app.sim.state.country, kind.selected, setup_platform)),
				float(Stores.WEBSITE_PLATFORMS[setup_platform].fee_bps) / 100.0 if setup_platform >= 0 else Stores.MARKET_FEES[platform.selected]]
		kind.item_selected.connect(update_cost)
		website_platform.item_selected.connect(update_cost)
		platform.item_selected.connect(update_cost)
		update_cost.call()
		var saved: Callable = app.watch_edits([name, brand, kind, domain, platform, website_platform])
		var create_store := func():
			var selected_website_platform := website_platform.selected - 1 if website_platform.selected > 0 else -1
			var result := Stores.create(app.sim.state, name.text, kind.selected, brand.text, domain.text, platform.selected, selected_website_platform if kind.selected == 1 else -1)
			if not result.is_empty():
				app.set_notice(result, true)
				return
			saved.call()
			app.show_new_store_form = false
			app.persist("Store opened. Setup cost recorded in Finance.")
			app.refresh_view()
		app.action(setup, "Create store", func():
			if kind.selected == 1:
				if website_platform.selected <= 0:
					app.set_notice("Select a website platform before creating the website.", true)
					return
				var website_index := website_platform.selected - 1
				var selected_platform: Dictionary = Stores.WEBSITE_PLATFORMS[website_index]
				app.confirm_action("Open %s website?" % selected_platform.name, "%s · One-time setup %s · Recurring %s per game day · Transaction fee %.1f%%." % [
					selected_platform.feature, app.money(Stores.setup_cost(app.sim.state.country, 1, website_index)),
					app.money(Stores.daily_cost(app.sim.state.country, 1, website_index)), float(selected_platform.fee_bps) / 100.0], "Open website", create_store)
			else:
				create_store.call()
		, true)
		app.action(setup, "Cancel", func():
			app.show_new_store_form = false
			app.refresh_view()
		)

static func _website_summary(store: Dictionary) -> String:
	var platform_id := str(store.get("website_platform", "legacy"))
	var index := Stores.website_platform_index(platform_id)
	return (Stores.WEBSITE_PLATFORMS[index].name if index >= 0 else "Legacy website") + " · " + str(store.domain)

static func profitability(app: Control) -> void:
	var summary: VBoxContainer = app.card("Store Profitability")
	summary.add_child(app.label("Completed-day results for each marketplace store and website. Inventory costs follow the units consumed by orders.", 14, Style.MUTED))
	if app.sim.state.stores.is_empty():
		summary.add_child(app.label("No stores or websites have been created yet.", 14, Style.MUTED))
		app.secondary_tab(summary, "Open Store Management", app.navigate.bind("Management"), false)
		return
	var selection: OptionButton = app.dropdown(summary, Calendar.PERIODS, app.period)
	selection.item_selected.connect(func(index: int):
		app.period = index
		app.report_end = 0
		app.refresh_view()
	)
	var anchor := int(app.report_end) if int(app.report_end) > 0 else int(app.sim.state.day)
	var selected_bounds := Calendar.bounds(app.period, clampi(anchor, 1, int(app.sim.state.day)))
	var period_report := Finance.completed_period_report(app.sim, app.period, anchor)
	var start_day := int(period_report.get("start", 0))
	var end_day := int(period_report.get("end", 0))
	var has_completed_days := start_day > 0 and end_day >= start_day
	if not has_completed_days:
		start_day = int(app.sim.state.day)
		end_day = int(app.sim.state.day) - 1
	var date_label := Calendar.format_range(start_day, end_day) if has_completed_days else Calendar.format_range(selected_bounds.x, selected_bounds.y)
	summary.add_child(app.label(date_label, Style.FONT_BODY, Style.GOLD))
	var dates: HBoxContainer = app.row(summary)
	var previous: Button = app.action(dates, "Previous", change_profitability_period.bind(app, selected_bounds.x - 1))
	previous.disabled = selected_bounds.x <= 1
	var next: Button = app.action(dates, "Next", change_profitability_period.bind(app, selected_bounds.y + 1))
	next.disabled = selected_bounds.y >= int(app.sim.state.day) - 1
	if not has_completed_days:
		summary.add_child(app.label("No completed days are available for this period yet. Current-day activity remains live but is not included in historical reports.", 14, Style.MUTED))
	var total_profit := 0
	var expanded_id := int(app.get_meta("expanded_profitability_store_id", -1))
	for store in app.sim.state.stores:
		var result: Dictionary = Stores.report(app.sim.state, int(store.id), end_day, start_day)
		var profit := int(result.sales) - int(result.refunds) - int(result.cogs) - int(result.fees) - int(result.shipping) - int(result.advertising) - int(result.setup) - int(result.operating)
		total_profit += profit
		var card: VBoxContainer = app.card(str(store.name))
		var kind: String = Stores.MARKETPLACES[int(store.platform)] if int(store.type) == 0 and int(store.get("platform", -1)) in range(Stores.MARKETPLACES.size()) else _website_summary(store)
		var is_expanded := int(store.id) == expanded_id
		var toggle: Button = app.action(card, "Hide Breakdown" if is_expanded else "Expand Breakdown", func():
			app.set_meta("expanded_profitability_store_id", -1 if is_expanded else int(store.id))
			app.refresh_view()
		)
		toggle.custom_minimum_size.y = 44
		app.metric(card, "Platform · Status", "%s · %s" % [kind, "Active" if store.active else "Inactive"])
		app.metric(card, "Net Sales", app.money(int(result.sales) - int(result.refunds)))
		app.metric(card, "Net Store Profit", app.money(profit), app.profit_color(profit))
		if is_expanded:
			app.divider(card)
			app.metric(card, "Product & Fulfilment Costs", app.money(-(int(result.cogs) + int(result.fees) + int(result.shipping))))
			app.metric(card, "Product Cost", app.money(-int(result.cogs)))
			app.metric(card, "Channel Fees", app.money(-int(result.fees)))
			app.metric(card, "Delivery Costs", app.money(-int(result.shipping)))
			app.metric(card, "Advertising", app.money(-int(result.advertising)))
			app.metric(card, "Setup Costs", app.money(-int(result.setup)))
			app.metric(card, "Operating Costs", app.money(-int(result.operating)))
	app.divider(summary)
	app.metric(summary, "Total Store Profitability", app.money(total_profit), app.profit_color(total_profit))

static func change_profitability_period(app: Control, day: int) -> void:
	app.report_end = day
	app.refresh_view()

static func listings(app: Control) -> void:
	var store := Stores.get_store(app.sim.state, app.selected_store_id)
	if store.is_empty():
		app.set_notice("Select an owned store before managing its listings.", true)
		app.navigate("Management")
		return
	var heading: VBoxContainer = app.card("%s · Product listings" % store.name)
	var website_index := Stores.website_platform_index(str(store.get("website_platform", "legacy")))
	var website_name: String = Stores.WEBSITE_PLATFORMS[website_index].name if website_index >= 0 else "Website"
	var subtitle: String = "Shared company inventory · Marketplace" if store.type == 0 else "Shared company inventory · %s · %s" % [website_name, store.domain]
	heading.add_child(app.label(subtitle, 14, Style.MUTED))
	app.secondary_tab(heading, "Store Management", app.navigate.bind("Management"), true)
	var products := Catalog.PRODUCTS.map(func(item): return item.name)
	var picker: OptionButton = app.dropdown(heading, products, app.selected_product)
	picker.custom_minimum_size.y = 44
	picker.add_theme_font_size_override("font_size", 13)
	var item: Dictionary = app.sim.product_state(app.selected_product)
	var listing := Stores.listing(app.sim.state, int(store.id), app.selected_product)
	var outstanding := Fulfillment.outstanding_preorders(app.sim.state, app.selected_product, int(store.id))
	app.metric(heading, "Company inventory", "%d available · %d inbound" % [app.sim.stock(app.selected_product), Stores.incoming(app.sim.state, app.selected_product)])
	app.metric(heading, "Outstanding pre-order quantity", str(outstanding))
	var product_supplier: int = int(item.get("supplier", Catalog.DEFAULT_SUPPLIER))
	var expected_restock := 0
	for batch in app.sim.state.inbound:
		if int(batch.product) == app.selected_product and (expected_restock == 0 or int(batch.eta) < expected_restock): expected_restock = int(batch.arrival if batch.get("delayed", false) else batch.eta)
	if expected_restock > 0:
		app.metric(heading, "Estimated replenishment", Calendar.format(expected_restock) + " · shipment confirmed")
	else:
		app.metric(heading, "Estimated replenishment", Calendar.format(app.sim.state.day + int(Catalog.SUPPLIERS[product_supplier].lead)) + " · estimate only")
	picker.item_selected.connect(func(index: int):
		app.discard_form_then(func():
			app.selected_product = index
			app.store_listing_editing = false
			app.refresh_view()
		)
	)
	if app.store_listing_editing:
		var price: LineEdit = app.field(heading, "Store Selling Price (%s)" % Catalog.CURRENCIES[app.sim.state.country], app.amount_text(listing.price, true).replace(",", ""), 16)
		price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		var status: OptionButton = app.dropdown(heading, ["Draft", "Listed"], 1 if listing.listed else 0)
		heading.add_child(app.label("Allow Pre-orders", 14, Style.MUTED))
		var preorders: OptionButton = app.dropdown(heading, ["Off", "On"], 1 if listing.get("allow_preorders", false) else 0)
		preorders.tooltip_text = "Accept new orders while this listing is out of stock. Existing pre-orders remain accepted if switched off."
		app.watch_edits([price, status, preorders])
		app.action(heading, "Save Changes", func():
			var cents: int = app.price_cents(price.text)
			var error := Stores.set_listing(app.sim.state, int(store.id), app.selected_product, cents, status.selected == 1, preorders.selected == 1)
			if not error.is_empty():
				app.set_notice(error, true)
				return
			app.store_listing_editing = false
			app.persist("%s listing saved." % Catalog.PRODUCTS[app.selected_product].name)
			app.refresh_view()
		, true)
		app.action(heading, "Cancel", func():
			app.store_listing_editing = false
			app.edit_checks.clear()
			app.set_notice("")
			app.refresh_view()
		)
	else:
		app.metric(heading, "Product", Catalog.PRODUCTS[app.selected_product].name)
		app.metric(heading, "Selling Price", app.money(int(listing.price)))
		app.metric(heading, "Listing Status", "Listed" if listing.listed else "Draft")
		app.metric(heading, "Pre-orders", "Enabled" if listing.get("allow_preorders", false) else "Off")
		app.action(heading, "Edit Listing", func():
			app.store_listing_editing = true
			app.refresh_view()
		)
	var cost: Dictionary = app.sim.unit_cost(app.selected_product, item.supplier)
	var contribution: int = listing.price - cost.landed - Stores.store_fee(store, Stores.channel(store), listing.price) - Catalog.local_cents(app.sim.state.country, Catalog.SHIPPING[app.sim.state.shipping].cost)
	app.metric(heading, "Landed cost per unit", app.money(cost.landed))
	app.metric(heading, "Estimated contribution after channel fee and delivery", app.money(contribution), app.profit_color(contribution))
	app.metric(heading, "Offer eligibility", "Listed products in this store can be advertised here.")
	Offers.show(app, app.selected_product, int(store.id))
