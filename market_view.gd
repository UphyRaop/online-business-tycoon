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
	listing_form(app, product, item)
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
		# The listing estimate uses the active supplier quote when stock is empty.
		update_listing_cost(app)
	)
	app.action(supply, "Negotiate quote", func():
		var result := Supply.negotiate(state, product, supplier.selected, units_from(quantity.text))
		if not result.is_empty():
			app.set_notice(result, true)
			return
		app.persist("Negotiated quote received.")
		refresh.call()
		update_listing_cost(app)
	)
	app.action(supply, "Purchase stock", func():
		var result: String = app.sim.buy(product, supplier.selected, units_from(quantity.text))
		if not result.is_empty():
			app.set_notice(result, true)
			return
		app.persist("Purchase order placed. Track it below.")
		refresh.call()
		refresh_inbound(app, product, inbound, shipments)
		update_listing_cost(app)
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

static func update_listing_cost(app: Control) -> void:
	var listing: Node = app.body.find_child("ListingPrice", true, false)
	if listing != null:
		listing.text_changed.emit(listing.text)

static func listing_form(app: Control, product: int, item: Dictionary) -> void:
	var state: Dictionary = app.sim.state
	var listing: VBoxContainer = app.card("Store listing")
	listing.add_child(app.label("%s · Marketplace: %s · Brand: %s\nWebsite: %s · %s" % [
		"Published" if item.listed else "Unpublished", state.store, state.brand, state.website_domain,
		"Active" if state.website_active else "Inactive"], 15, Style.MUTED))
	var currency: String = Catalog.CURRENCIES[state.country]
	var price: LineEdit = app.field(listing, "Selling price per unit (%s)" % currency,
		app.amount_text(item.price, true).replace(",", ""), 16)
	price.name = "ListingPrice"
	price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	listing.add_child(app.label("Sales channels for this listing", 14, Style.MUTED))
	var channels: OptionButton = app.dropdown(listing, Catalog.CHANNELS, int(item.get("channel_mask", 3)) - 1)
	var listing_saved: Callable = app.watch_edits([price, channels])
	var cost_label: Label = app.label("", 14, Style.MUTED)
	listing.add_child(cost_label)
	var estimates: Array[Label] = []
	for channel in Catalog.FEES.size():
		var estimate: Label = app.label("", 14)
		listing.add_child(estimate)
		estimates.append(estimate)
	listing.add_child(app.label("Estimated contribution includes the channel fee and default outbound customer delivery.", 13, Style.MUTED))
	var refresh := func(_value: String):
		var supplier: int = app.sim.product_state(product).supplier
		var unit: Dictionary = app.sim.unit_cost(product, supplier)
		var cost: int = unit.landed
		cost_label.text = "%s · Landed unit cost %s" % [unit.source, app.money(cost)]
		var cents: int = app.price_cents(price.text)
		var freight := Catalog.local_cents(state.country, Catalog.SHIPPING[state.shipping].cost)
		for channel in estimates.size():
			estimates[channel].visible = app.sim.channel_enabled(channel) and ((channels.selected + 1) & (1 << channel)) != 0
			var profit := cents - cost - Catalog.fee(channel, cents) - freight
			estimates[channel].text = "%s unit profit  %s" % [Catalog.CHANNELS[channel], app.money(profit) if cents > 0 else "—"]
			estimates[channel].add_theme_color_override("font_color", app.profit_color(profit) if cents > 0 else Style.MUTED)
	price.text_changed.connect(refresh)
	channels.item_selected.connect(func(_index: int): refresh.call(price.text))
	refresh.call(price.text)
	var save_listing := func(publish: bool):
		var cents: int = app.price_cents(price.text)
		if cents < 1:
			app.set_notice("Enter a selling price from 0.01 to 100,000,000.", true)
			return
		app.sim.list_product(product, cents, channels.selected + 1, publish)
		listing_saved.call()
		app.persist("Listing saved at %s." % app.money(cents) if publish else "Product draft saved.")
		app.refresh_view()
	app.action(listing, "Update listing" if item.listed else "Publish listing", save_listing.bind(true), true)
	if item.listed:
		var pause := func():
			app.sim.unlist(product)
			app.persist("Listing paused. Stock remains available.")
			app.refresh_view()
		app.action(listing, "Pause listing", app.discard_form_then.bind(pause))
	else:
		app.action(listing, "Save draft", save_listing.bind(false))
