extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Offers = preload("res://offer_view.gd")
const Calendar = preload("res://game_calendar.gd")
const Style = preload("res://corporate_theme.gd")

static func show(app: Control) -> void:
	var product: int = app.selected_product
	var item: Dictionary = app.sim.product_state(product)
	var catalog: VBoxContainer = app.card("Product Catalogue")
	var category_filter := MenuButton.new()
	category_filter.text = Catalog.CATEGORIES[app.catalog_category] if app.catalog_category >= 0 else "All Categories"
	category_filter.custom_minimum_size.y = app.TOUCH_HEIGHT
	category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog.add_child(category_filter)
	var category_menu: PopupMenu = category_filter.get_popup()
	category_menu.add_item("All Categories", -1)
	for category_id in Catalog.CATEGORIES.size(): category_menu.add_item(Catalog.CATEGORIES[category_id], category_id)
	var search: LineEdit = app.field(catalog, "Search products", app.catalog_search, 64)
	var picker: OptionButton = app.dropdown(catalog, [], 0)
	var visible_products: Array[int] = []
	var refresh_picker := func():
		picker.clear()
		visible_products.clear()
		var needle := search.text.strip_edges().to_lower()
		for id in Catalog.PRODUCTS.size():
			var entry: Dictionary = Catalog.PRODUCTS[id]
			if app.catalog_category >= 0 and entry.category != Catalog.CATEGORIES[app.catalog_category]: continue
			if not needle.is_empty() and not entry.name.to_lower().contains(needle) and not entry.id.to_lower().contains(needle): continue
			visible_products.append(id)
			picker.add_item("%s · %s" % [entry.name, entry.category])
		if visible_products.is_empty():
			picker.add_item("No products match these filters")
			picker.disabled = true
			return
		picker.disabled = false
		var current := visible_products.find(app.selected_product)
		picker.select(maxi(0, current))
	category_menu.id_pressed.connect(func(category_id: int):
		app.catalog_category = category_id
		category_filter.text = Catalog.CATEGORIES[category_id] if category_id >= 0 else "All Categories"
		refresh_picker.call()
	)
	search.text_changed.connect(func(value: String):
		app.catalog_search = value
		refresh_picker.call()
	)
	picker.item_selected.connect(func(index: int):
		if index in range(visible_products.size()): app.open_product(visible_products[index])
	)
	refresh_picker.call()
	var links: HBoxContainer = app.row(catalog)
	app.action(links, "My Products", app.navigate.bind("My Products"))
	var stock_label: Label = app.label("", 15, Style.MUTED)
	catalog.add_child(stock_label)
	app.metric(catalog, "Category · Estimated supplier cost", "%s · %s" % [Catalog.PRODUCTS[product].category, app.money(Catalog.quote(app.sim.state.country, product, int(item.supplier)))])
	app.metric(catalog, "Demand · Competition", "%.2f · %.2f" % [Catalog.PRODUCTS[product].demand, Catalog.PRODUCTS[product].competition])
	supplier_form(app, product, item, stock_label)
	var listings: VBoxContainer = app.card("Store listings")
	listings.add_child(app.label("Product listings belong to individual stores. Create a marketplace or website and manage its listings under Market / Management.", 14, Style.MUTED))
	app.action(listings, "Management", app.navigate.bind("Management"), true)
	var offers := Offers.show(app, product)
	app.action(links, "Offers", func():
		var scroll: ScrollContainer = app.body.get_parent()
		scroll.scroll_vertical += roundi(offers.get_parent().global_position.y - scroll.global_position.y)
	)

static func supplier_form(app: Control, product: int, item: Dictionary, stock_label: Label) -> void:
	var state: Dictionary = app.sim.state
	var supply: VBoxContainer = app.card("Supplier quotation")
	var supplier_indices: Array[int] = []
	for supplier_id in Catalog.SUPPLIER_SELECTION_INDICES:
		supplier_indices.append(int(supplier_id))
	var supplier_names: Array[String] = []
	for supplier_id in supplier_indices:
		supplier_names.append(Catalog.SUPPLIERS[supplier_id].name)
	var selected_supplier: int = supplier_indices.find(int(item.supplier))
	if selected_supplier < 0: selected_supplier = 0
	if item.has("legacy_supplier"):
		supply.add_child(app.label("Historical supplier: %s · Choose a retained supplier to change future replenishment." % item.legacy_supplier.name, 13, Style.MUTED))
	var supplier: OptionButton = app.dropdown(supply, supplier_names, selected_supplier)
	var quote_label: Label = app.label("", 17, Style.GOLD)
	var terms: Label = app.label("", 14, Style.MUTED)
	supply.add_child(quote_label)
	supply.add_child(terms)
	var freight_label: Label = app.label("", 14, Style.MUTED)
	supply.add_child(freight_label)
	var quantity: LineEdit = app.field(supply, "Order quantity", "10", 10)
	quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var total: Label = app.label("", 16)
	var forecast_label: Label = app.label("", 14, Style.MUTED)
	supply.add_child(total)
	supply.add_child(forecast_label)
	var forecast_button: Button = app.action(supply, "Use forecast quantity", func():
		var forecast := Supply.forecast(app.sim, product, supplier_indices[supplier.selected])
		quantity.text = str(forecast.suggested)
		quantity.text_changed.emit(quantity.text)
	)
	var inbound: VBoxContainer = app.card("Inbound stock")
	var shipments: VBoxContainer = app.stack(inbound)
	var refresh := func():
		var supplier_index: int = supplier_indices[supplier.selected]
		var provider: Dictionary = Catalog.SUPPLIERS[supplier_index]
		var standard := Catalog.quote(state.country, product, supplier_index)
		var quote := Supply.quote(state, product, supplier_index)
		var qty := units_from(quantity.text)
		var effective: int = quote.cost if qty >= quote.minimum else standard
		var freight := Catalog.inbound_freight(state.country, supplier_index)
		var forecast := Supply.forecast(app.sim, product, supplier_index)
		stock_label.text = "%d available · %d inbound\n%s cash available" % [
			app.sim.stock(product), Supply.incoming(state, product), app.money(state.cash)]
		quote_label.text = "%s per unit" % app.money(standard)
		if quote.discount > 0:
			quote_label.text = "%s per unit at %d+ units · Through %s" % [
				app.money(quote.cost), quote.minimum, Calendar.format(quote.expires)]
		terms.text = "Order quantity %s–%s · %s quality · %d%% on-time · %d-day lead\nNegotiate from %s units" % [
			_format_quantity(provider.minimum), _format_quantity(Supply.maximum_order_quantity(supplier_index)),
			"High" if provider.quality >= 0.95 else "Standard",
			roundi(provider.reliability * 100), provider.lead, _format_quantity(Supply.negotiation_minimum(supplier_index))]
		freight_label.text = "Inbound freight per unit  " + app.money(freight)
		total.text = "Landed order total  " + (app.money((effective + freight) * qty) if qty > 0 else "—")
		var demand_source := "catalog estimate" if forecast.days == 0 else "%d recent days" % forecast.days
		forecast_label.text = "Demand %.1f units/day (%s)\nTarget %d units · Restock %d" % [
			forecast.daily, demand_source, forecast.target, forecast.suggested]
		forecast_button.disabled = forecast.suggested == 0
	quantity.text_changed.connect(func(_value: String): refresh.call())
	supplier.item_selected.connect(func(index: int):
		app.sim.select_supplier(product, supplier_indices[index])
		app.persist("Supplier selected.")
		refresh.call()
	)
	app.action(supply, "Negotiate quote", func():
		var result := Supply.negotiate(state, product, supplier_indices[supplier.selected], units_from(quantity.text))
		if not result.is_empty():
			app.set_notice(result, true)
			return
		app.persist("Negotiated quote received.")
		refresh.call()
	)
	app.action(supply, "Purchase stock", func():
		var result: String = app.sim.buy(product, supplier_indices[supplier.selected], units_from(quantity.text))
		if not result.is_empty():
			app.set_notice(result, true)
			return
		app.persist("Purchase order placed. Track it below.")
		refresh.call()
		refresh_inbound(app, product, inbound, shipments)
	, true)
	refresh.call()
	refresh_inbound(app, product, inbound, shipments)

static func refresh_inbound(app: Control, product: int, inbound: VBoxContainer, shipments: VBoxContainer) -> void:
	var state: Dictionary = app.sim.state
	for child in shipments.get_children():
		shipments.remove_child(child)
		child.queue_free()
	inbound.get_parent().visible = Supply.incoming(state, product) > 0
	for batch in state.inbound:
		if batch.product != product:
			continue
		var estimate: int = batch.arrival if batch.delayed else batch.eta
		app.metric(shipments, "PO-%04d · %d units" % [batch.id, batch.units], "%s%s" % [
			Calendar.format(estimate), " · delayed" if batch.delayed else ""])

static func units_from(value: String) -> int:
	var text := value.strip_edges()
	return text.to_int() if text.is_valid_int() else 0

static func _format_quantity(value: int) -> String:
	var text := str(value)
	var result := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0: result += ","
		result += text[i]
	return result
