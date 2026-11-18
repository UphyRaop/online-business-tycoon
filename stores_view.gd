extends RefCounted

const Catalog = preload("res://catalog.gd")
const Stores = preload("res://store_manager.gd")
const Style = preload("res://corporate_theme.gd")

static func management(app: Control) -> void:
	var intro: VBoxContainer = app.card("Stores under %s" % app.sim.state.company)
	intro.add_child(app.label("Stores share company inventory. Listings, sales, operating costs, and campaigns are tracked by store.", 14, Style.MUTED))
	app.action(intro, "Growth Overview", app.navigate.bind("Growth"))
	var setup: VBoxContainer = app.card("Open a new store")
	var name: LineEdit = app.field(setup, "Store name", "", 40)
	var brand: LineEdit = app.field(setup, "Brand name", app.sim.state.brand, 40)
	var kind: OptionButton = app.dropdown(setup, ["Marketplace", "Own Website"], 0)
	var domain: LineEdit = app.field(setup, "Website domain (required for Own Website)", "", 64)
	var platform: OptionButton = app.dropdown(setup, Stores.MARKETPLACES, 0)
	var cost: Label = app.label("", 14, Style.GOLD)
	setup.add_child(cost)
	var update_cost := func(_index: int = 0):
		platform.visible = kind.selected == 0
		domain.editable = kind.selected == 1
		cost.text = "Setup %s · Recurring %s per game day" % [
			app.money(Stores.setup_cost(app.sim.state.country, kind.selected)),
			app.money(Stores.daily_cost(app.sim.state.country, kind.selected))]
	kind.item_selected.connect(update_cost)
	update_cost.call()
	var saved: Callable = app.watch_edits([name, brand, kind, domain, platform])
	var create_store := func():
		var result := Stores.create(app.sim.state, name.text, kind.selected, brand.text, domain.text, platform.selected)
		if not result.is_empty():
			app.set_notice(result, true)
			return
		saved.call()
		app.persist("Store opened. Setup cost recorded in Finance.")
		app.refresh_view()
	app.action(setup, "Create store", func():
		if kind.selected == 1:
			app.confirm_action("Open website?", "One-time setup %s. Recurring %s per game day." % [
				app.money(Stores.setup_cost(app.sim.state.country, 1)),
				app.money(Stores.daily_cost(app.sim.state.country, 1))], "Open website", create_store)
		else:
			create_store.call()
	, true)
	var stores: VBoxContainer = app.card("Owned stores · %d" % app.sim.state.stores.size())
	for store in app.sim.state.stores:
		var id: int = store.id
		var card: VBoxContainer = app.stack(stores, 7)
		app.divider(card)
		var market: int = store.get("platform", -1)
		var detail: String = Stores.MARKETPLACES[market] if store.type == 0 and market >= 0 else ("Marketplace" if store.type == 0 else "Own Website · " + store.domain)
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
		app.action(actions, "Manage listings", func():
			app.selected_store_id = id
			app.navigate("Store Listings")
		)
		var status: String = "Deactivate" if store.active else "Activate"
		app.action(actions, status, func():
			Stores.set_active(app.sim.state, id, not store.active)
			app.persist("%s is now %s." % [store.name, "active" if not store.active else "inactive"])
			app.refresh_view()
		)

static func listings(app: Control) -> void:
	var store := Stores.get_store(app.sim.state, app.selected_store_id)
	if store.is_empty():
		app.set_notice("Select an owned store before managing its listings.", true)
		app.navigate("Store Management")
		return
	var heading: VBoxContainer = app.card("%s · Product listings" % store.name)
	var subtitle: String = "Shared company inventory · Marketplace" if store.type == 0 else "Shared company inventory · %s" % store.domain
	heading.add_child(app.label(subtitle, 14, Style.MUTED))
	app.action(heading, "Store Management", app.navigate.bind("Store Management"))
	var products := Catalog.PRODUCTS.map(func(item): return item.name)
	var picker: OptionButton = app.dropdown(heading, products, app.selected_product)
	var item: Dictionary = app.sim.product_state(app.selected_product)
	var listing := Stores.listing(app.sim.state, int(store.id), app.selected_product)
	app.metric(heading, "Company inventory", "%d available · %d reserved / inbound" % [app.sim.stock(app.selected_product), Stores.incoming(app.sim.state, app.selected_product)])
	var price: LineEdit = app.field(heading, "Store selling price (%s)" % Catalog.CURRENCIES[app.sim.state.country], app.amount_text(listing.price, true).replace(",", ""), 16)
	price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	var status: OptionButton = app.dropdown(heading, ["Draft", "Listed"], 1 if listing.listed else 0)
	var mark_saved: Callable = app.watch_edits([picker, price, status])
	picker.item_selected.connect(func(index: int):
		app.discard_form_then(func():
			app.selected_product = index
			app.refresh_view()
		)
	)
	app.action(heading, "Save store listing", func():
		var cents: int = app.price_cents(price.text)
		var error := Stores.set_listing(app.sim.state, int(store.id), app.selected_product, cents, status.selected == 1)
		if not error.is_empty():
			app.set_notice(error, true)
			return
		mark_saved.call()
		app.persist("%s listing saved." % Catalog.PRODUCTS[app.selected_product].name)
		app.refresh_view()
	, true)
	var cost: Dictionary = app.sim.unit_cost(app.selected_product, item.supplier)
	var contribution: int = listing.price - cost.landed - Catalog.fee(Stores.channel(store), listing.price) - Catalog.local_cents(app.sim.state.country, Catalog.SHIPPING[app.sim.state.shipping].cost)
	app.metric(heading, "Landed cost per unit", app.money(cost.landed))
	app.metric(heading, "Estimated contribution after channel fee and delivery", app.money(contribution), app.profit_color(contribution))
	app.metric(heading, "Offer eligibility", "Listed products in this store can be advertised here.")
