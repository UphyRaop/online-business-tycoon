extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Summary = preload("res://product_summary.gd")
const Stores = preload("res://store_manager.gd")
const Offers = preload("res://offer_view.gd")
const Style = preload("res://corporate_theme.gd")

const FILTERS := ["All Products", "Active", "Draft", "Out of Stock"]
const FILTER_META := "my_products_filter"
const DETAIL_META := "my_products_selected_product"

static func show(app: Control) -> void:
	var sim: RefCounted = app.sim
	var state: Dictionary = sim.state
	var overview: VBoxContainer = app.wide_card("My Products")
	overview.add_child(app.label("Product portfolio", Style.FONT_BODY, Style.MUTED))
	app.metric(overview, "Active products", str(sim.active_product_count()), Style.GOLD)
	app.metric(overview, "Default outbound delivery", app.money(Catalog.local_cents(state.country, Catalog.SHIPPING[state.shipping].cost)) + " / order")
	var filter_row := FlowContainer.new()
	filter_row.add_theme_constant_override("h_separation", 6)
	filter_row.add_theme_constant_override("v_separation", 4)
	overview.add_child(filter_row)
	var selected_filter := int(app.get_meta(FILTER_META, 0))
	for index in FILTERS.size():
		app.secondary_tab(filter_row, FILTERS[index], func():
			app.set_meta(FILTER_META, index)
			app.refresh_view()
		, selected_filter == index)

	var activity := Summary.collect(state)
	var owned: Array[int] = owned_products(state)
	var shown := 0
	for id in owned:
		var current_status := product_status(state, id, int(sim.stock(id)))
		if selected_filter > 0 and current_status != FILTERS[selected_filter]:
			continue
		shown += 1
		var item: Dictionary = sim.product_state(id)
		var view: VBoxContainer = app.card(Catalog.PRODUCTS[id].name)
		var selected_id := int(app.get_meta(DETAIL_META, -1))
		if selected_id == id:
			view.add_child(app.label("Selected product", 13, Style.GOLD))
		var status_color := Style.GREEN if current_status == "Active" else (Style.MUTED if current_status == "Draft" else Style.GOLD)
		view.add_child(app.label(current_status, Style.FONT_BODY, status_color))
		var available: int = sim.stock(id)
		app.metric(view, "Inventory", "%d available · %d inbound" % [available, Supply.incoming(state, id)])
		var listings := listed_store_names(state, id)
		app.metric(view, "Store listings", str(listings.size()))
		app.metric(view, "Supplier", Catalog.SUPPLIERS[int(item.supplier)].name)
		var totals: Dictionary = activity.get(id, {"units": 0, "revenue": 0, "profit": 0})
		app.metric(view, "Units sold · Net revenue", "%s · %s" % [format_count(int(totals.units)), app.money(int(totals.revenue))])
		app.action(view, "Manage " + Catalog.PRODUCTS[id].name, func():
			app.set_meta(DETAIL_META, id)
			app.refresh_view()
		)
	if shown == 0:
		var empty := "No products match this status. Choose another filter or browse the Product Catalogue."
		if owned.is_empty(): empty = "Your product portfolio is empty. Browse the Product Catalogue to view supplier offers and prepare inventory."
		overview.add_child(app.label(empty, 14, Style.MUTED))
		app.secondary_tab(overview, "Product Catalogue", app.navigate.bind("Market"), false)
	else:
		app.secondary_tab(overview, "Product Catalogue", app.navigate.bind("Market"), false)

	var selected_product := int(app.get_meta(DETAIL_META, -1))
	if selected_product in owned:
		product_details(app, selected_product, activity.get(selected_product, {"units": 0, "revenue": 0, "profit": 0}))
	var notes: VBoxContainer = app.card("About Product Profit")
	notes.add_child(app.label("Estimated gross profit uses landed cost. Historical product profit also deducts customer delivery and channel fees, and reflects refunds.", 14, Style.MUTED))

static func owned_products(state: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for id in Catalog.PRODUCTS.size():
		var owned: bool = state.get("products", {}).has(id) or state.get("quotes", {}).has(id) or state.get("offers", {}).has(id)
		for store in state.get("stores", []):
			if store.get("listings", {}).has(id):
				owned = true
				break
		if owned: result.append(id)
	return result

static func product_status(state: Dictionary, product: int, available: int = -1) -> String:
	var is_listed := false
	for store in state.get("stores", []):
		if Stores.listing(state, int(store.id), product).get("listed", false):
			is_listed = true
			break
	if not is_listed: return "Draft"
	if available < 0:
		available = 0
		for lot in state.get("products", {}).get(product, {}).get("lots", []):
			available += int(lot.get("units", 0))
	return "Active" if available > 0 else "Out of Stock"

static func listed_store_names(state: Dictionary, product: int) -> Array[String]:
	var result: Array[String] = []
	for store in state.get("stores", []):
		if Stores.listing(state, int(store.id), product).get("listed", false): result.append(str(store.name))
	return result

static func product_details(app: Control, product: int, totals: Dictionary) -> void:
	var sim: RefCounted = app.sim
	var state: Dictionary = sim.state
	var item: Dictionary = sim.product_state(product)
	var detail: VBoxContainer = app.wide_card("Product Details · " + Catalog.PRODUCTS[product].name)
	detail.name = "SelectedProductDetails"
	app.metric(detail, "Category", Catalog.PRODUCTS[product].category)
	app.metric(detail, "Company Inventory", "%d available · %d inbound" % [sim.stock(product), Supply.incoming(state, product)])
	var cost: Dictionary = sim.unit_cost(product, int(item.supplier))
	app.metric(detail, "Supplier", Catalog.SUPPLIERS[int(item.supplier)].name)
	app.metric(detail, "Landed Unit Cost", app.money(int(cost.landed)))
	app.metric(detail, "Default Selling Price", app.money(int(item.price)))
	app.metric(detail, "Units Sold · Net Revenue", "%s · %s" % [format_count(int(totals.get("units", 0))), app.money(int(totals.get("revenue", 0)))])
	app.metric(detail, "Product Profit", app.money(int(totals.get("profit", 0))), app.profit_color(int(totals.get("profit", 0))))
	app.secondary_tab(detail, "Open Product Catalogue", app.navigate.bind("Market"), false)

	var stores_card: VBoxContainer = app.wide_card("Store Listings")
	stores_card.name = "ProductStoreListings"
	stores_card.add_child(app.label("Each store has an independent price and listing status. Company inventory remains shared.", 13, Style.MUTED))
	var store_count := 0
	for store in state.get("stores", []):
		store_count += 1
		listing_editor(app, product, store)
	if store_count == 0:
		stores_card.add_child(app.label("Create a marketplace store or website in Store Management before publishing a listing.", 14, Style.MUTED))
		app.secondary_tab(stores_card, "Open Store Management", app.navigate.bind("Management"), false)

static func listing_editor(app: Control, product: int, store: Dictionary) -> void:
	var store_id := int(store.id)
	var listing := Stores.listing(app.sim.state, store_id, product)
	var activity: VBoxContainer = app.card("%s · %s" % [str(store.name), "Marketplace" if int(store.type) == 0 else "Website"])
	activity.name = "ProductListingStore%d" % store_id
	app.metric(activity, "Status", "Listed" if bool(listing.get("listed", false)) else "Draft")
	app.metric(activity, "Store Price", app.money(int(listing.get("price", 0))))
	app.metric(activity, "Store Activity", "Active" if bool(store.get("active", false)) else "Inactive")
	var edit_meta := "product_listing_edit_%d_%d" % [product, store_id]
	var editing := bool(app.get_meta(edit_meta, false))
	if editing:
		var price: LineEdit = app.field(activity, "Store Selling Price (%s)" % Catalog.CURRENCIES[app.sim.state.country], app.amount_text(int(listing.price), true).replace(",", ""), 16)
		price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		var status: OptionButton = app.dropdown(activity, ["Draft", "Listed"], 1 if listing.listed else 0)
		var preorder: OptionButton = app.dropdown(activity, ["Pre-orders Off", "Pre-orders On"], 1 if listing.get("allow_preorders", false) else 0)
		app.watch_edits([price, status, preorder])
		app.action(activity, "Save Listing", func():
			var err := Stores.set_listing(app.sim.state, store_id, product, app.price_cents(price.text), status.selected == 1, preorder.selected == 1)
			if not err.is_empty():
				app.set_notice(err, true)
				return
			app.set_meta(edit_meta, false)
			if app.persist("Store listing saved."):
				app.refresh_view()
		, true)
		app.action(activity, "Cancel", func():
			app.set_meta(edit_meta, false)
			app.edit_checks.clear()
			app.refresh_view()
		)
	else:
		app.action(activity, "Edit Listing", func():
			app.set_meta(edit_meta, true)
			app.refresh_view()
		)
		if bool(listing.get("listed", false)):
			app.action(activity, "Unpublish", func():
				var err := Stores.set_listing(app.sim.state, store_id, product, int(listing.price), false, listing.get("allow_preorders", false))
				if not err.is_empty():
					app.set_notice(err, true)
					return
				app.persist("Listing unpublished.")
				app.refresh_view()
			)
		else:
			app.action(activity, "Publish", func():
				var err := Stores.set_listing(app.sim.state, store_id, product, maxi(1, int(listing.price)), true, listing.get("allow_preorders", false))
				if not err.is_empty():
					app.set_notice(err, true)
					return
				app.persist("Listing published.")
				app.refresh_view()
			, true)
	app.metric(activity, "Pre-order Setting", "Enabled" if listing.get("allow_preorders", false) else "Off", Style.MUTED)
	if store.get("listings", {}).has(product):
		Offers.show(app, product, store_id)

static func format_count(value: int) -> String:
	var absolute := absi(value)
	var whole := str(absolute)
	var grouped := ""
	for index in whole.length():
		if index > 0 and (whole.length() - index) % 3 == 0: grouped += ","
		grouped += whole[index]
	return ("-" if value < 0 else "") + grouped
