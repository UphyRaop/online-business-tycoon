extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Offers = preload("res://offer_view.gd")
const Calendar = preload("res://game_calendar.gd")
const Style = preload("res://corporate_theme.gd")

static func show(app: Control) -> void:
	var product: int = app.selected_product
	var item: Dictionary = app.sim.product_state(product)
	var catalog: VBoxContainer = app.card("Product catalog")
	var picker: OptionButton = app.dropdown(catalog, Catalog.PRODUCTS.map(func(entry): return entry.name), product)
	picker.item_selected.connect(func(id: int):
		picker.select(product)
		app.open_product(id)
	)
	var links: HBoxContainer = app.row(catalog)
	app.action(links, "My Products", app.navigate.bind("My Products"))
	var stock_label: Label = app.label("", 15, Style.MUTED)
	catalog.add_child(stock_label)
	supplier_form(app, product, item, stock_label)
	var listings: VBoxContainer = app.card("Store listings")
	listings.add_child(app.label("Product listings belong to individual stores. Create a marketplace or website and manage its listings under Business → Stores.", 14, Style.MUTED))
	app.action(listings, "Manage stores", app.navigate.bind("Store Management"), true)
	var offers := Offers.show(app, product)
	app.action(links, "Offers", func():
		var scroll: ScrollContainer = app.body.get_parent()
		scroll.scroll_vertical += roundi(offers.get_parent().global_position.y - scroll.global_position.y)
	)

static func supplier_form(app: Control, product: int, item: Dictionary, stock_label: Label) -> void:
	var state: Dictionary = app.sim.state
	var supply: VBoxContainer = app.card("Supplier quotation")
	var supplier: OptionButton = app.dropdown(supply, Catalog.SUPPLIERS.map(func(provider): return provider.name), item.supplier)
	var quote_label: Label = app.label("", 17, Style.GOLD)
	var terms: Label = app.label("", 14, Style.MUTED)
	supply.add_child(quote_label)
	supply.add_child(terms)
	var freight_label: Label = app.label("", 14, Style.MUTED)
	supply.add_child(freight_label)
	var quantity: LineEdit = app.field(supply, "Order quantity", "10", 3)
	quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var total: Label = app.label("", 16)
	var forecast_label: Label = app.label("", 14, Style.MUTED)
	supply.add_child(total)
	supply.add_child(forecast_label)
	var forecast_button: Button = app.action(supply, "Use forecast quantity", func():
		var forecast := Supply.forecast(app.sim, product, supplier.selected)
		quantity.text = str(forecast.suggested)
		quantity.text_changed.emit(quantity.text)
	)
	var inbound: VBoxContainer = app.card("Inbound stock")
	var shipments: VBoxContainer = app.stack(inbound)
	var refresh := func():
		var provider: Dictionary = Catalog.SUPPLIERS[supplier.selected]
		var standard := Catalog.quote(state.country, product, supplier.selected)
		var quote := Supply.quote(state, product, supplier.selected)
		var qty := units_from(quantity.text)
		var effective: int = quote.cost if qty >= quote.minimum else standard
		var freight := Catalog.inbound_freight(state.country, supplier.selected)
		var forecast := Supply.forecast(app.sim, product, supplier.selected)
		stock_label.text = "%d available · %d inbound\n%s cash available" % [
			app.sim.stock(product), Supply.incoming(state, product), app.money(state.cash)]
		quote_label.text = "%s per unit" % app.money(standard)
		if quote.discount > 0:
			quote_label.text = "%s per unit at %d+ units · Through %s" % [
				app.money(quote.cost), quote.minimum, Calendar.format(quote.expires)]
		terms.text = "Minimum %d · %s quality · %d%% on-time · %d-day lead\nNegotiate from %d units" % [
			provider.minimum, ["Standard", "High", "Premium"][supplier.selected],
			roundi(provider.reliability * 100), provider.lead, Supply.negotiation_minimum(supplier.selected)]
		freight_label.text = "Inbound freight per unit  " + app.money(freight)
		total.text = "Landed order total  " + (app.money((effective + freight) * qty) if qty > 0 else "—")
		var demand_source := "catalog estimate" if forecast.days == 0 else "%d recent days" % forecast.days
		forecast_label.text = "Demand %.1f units/day (%s)\nTarget %d units · Restock %d" % [
			forecast.daily, demand_source, forecast.target, forecast.suggested]
		forecast_button.disabled = forecast.suggested == 0
	quantity.text_changed.connect(func(_value: String): refresh.call())
	supplier.item_selected.connect(func(index: int):
		app.sim.select_supplier(product, index)
		app.persist("Supplier selected.")
		refresh.call()
	)
	app.action(supply, "Negotiate quote", func():
		var result := Supply.negotiate(state, product, supplier.selected, units_from(quantity.text))
		if not result.is_empty():
			app.set_notice(result, true)
			return
		app.persist("Negotiated quote received.")
		refresh.call()
	)
	app.action(supply, "Purchase stock", func():
		var result: String = app.sim.buy(product, supplier.selected, units_from(quantity.text))
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
