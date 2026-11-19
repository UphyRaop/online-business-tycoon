extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Calendar = preload("res://game_calendar.gd")
const Style = preload("res://corporate_theme.gd")

static func show(app: Control) -> void:
	var product: int = app.selected_product
	var item: Dictionary = app.sim.product_state(product)
	var search_panel: VBoxContainer = app.wide_card("Product Search")
	search_panel.name = "ProductSearchPanel"
	var search: LineEdit = app.field(search_panel, "Search Product", app.catalog_search, 64)
	var catalog: VBoxContainer = app.card("Product Catalogue")
	catalog.name = "ProductCataloguePanel"
	var category_choices: Array[String] = ["Select Category · All Products"]
	category_choices.append_array(Catalog.CATEGORIES)
	catalog.add_child(app.label("Browse by Category", 14, Style.MUTED))
	var category_filter: OptionButton = app.dropdown(catalog, category_choices, app.catalog_category + 1)
	category_filter.name = "ProductCategorySelection"
	catalog.add_child(app.label("Select Product", 14, Style.MUTED))
	var picker: OptionButton = app.dropdown(catalog, [], 0)
	picker.name = "ProductSelection"
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
			picker.add_item("No matching products")
			picker.disabled = true
			return
		picker.disabled = false
		var current := visible_products.find(app.selected_product)
		picker.select(maxi(0, current))
	category_filter.item_selected.connect(func(selected_index: int):
		app.catalog_category = selected_index - 1
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
	var empty_state: Label = app.label("No products match this category and search. Choose another category or clear the search.", 14, Style.MUTED)
	empty_state.name = "ProductSearchEmptyState"
	empty_state.visible = visible_products.is_empty()
	catalog.add_child(empty_state)
	search.text_changed.connect(func(_value: String): empty_state.visible = visible_products.is_empty())
	category_filter.item_selected.connect(func(_index: int): empty_state.visible = visible_products.is_empty())
	var links: HBoxContainer = app.row(catalog)
	app.secondary_tab(links, "My Products", app.navigate.bind("My Products"), app.page == "My Products")
	var stock_label: Label = app.label("", 15, Style.MUTED)
	catalog.add_child(stock_label)
	app.metric(catalog, "Category · Estimated supplier cost", "%s · %s" % [Catalog.PRODUCTS[product].category, app.money(Catalog.quote(app.sim.state.country, product, int(item.supplier)))])
	app.metric(catalog, "Demand · Competition", "%.2f · %.2f" % [Catalog.PRODUCTS[product].demand, Catalog.PRODUCTS[product].competition])
	supplier_form(app, product, item, stock_label)

static func supplier_form(app: Control, product: int, item: Dictionary, stock_label: Label) -> void:
	var state: Dictionary = app.sim.state
	var supply: VBoxContainer = app.card("Suppliers and Quotations · %s" % Catalog.PRODUCTS[product].name)
	supply.add_child(app.label("Compare sourcing terms for the selected product. Quotations remain attached to this product in your saved company.", 13, Style.MUTED))
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
	var quote_comparison: VBoxContainer = app.stack(supply, 8)
	quote_comparison.name = "SupplierQuoteComparison"
	var purchase_button: Button
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
		for child in quote_comparison.get_children():
			quote_comparison.remove_child(child)
			child.queue_free()
		quote_comparison.add_child(app.label("Compare Supplier Offers", 17, Style.GOLD))
		for candidate in supplier_indices:
			var row_supplier := int(candidate)
			var source: Dictionary = Catalog.SUPPLIERS[row_supplier]
			var available := Supply.supplier_unlocked(state, row_supplier)
			var offer := Supply.quote(state, product, row_supplier)
			var has_negotiated := int(offer.get("discount", 0)) > 0 and int(offer.get("expires", 0)) >= int(state.day)
			var row_box: VBoxContainer = app.stack(quote_comparison, 5)
			row_box.name = "SupplierOffer%d" % row_supplier
			var status_text := "Level %d locked" % int(source.level) if not available else ("Negotiated · expires %s" % Calendar.format(int(offer.expires)) if has_negotiated else "Standard quotation")
			app.metric(row_box, str(source.name), status_text, Style.GOLD if available else Style.MUTED)
			var goods_cost := int(offer.cost) if has_negotiated else Catalog.quote(state.country, product, row_supplier)
			var freight_cost := Catalog.inbound_freight(state.country, row_supplier)
			app.metric(row_box, "Buying · Landed Unit Price", "%s · %s" % [app.money(goods_cost), app.money(goods_cost + freight_cost)])
			app.metric(row_box, "MOQ · Max Per Order", "%s · %s" % [_format_quantity(int(source.minimum)), _format_quantity(Supply.maximum_order_quantity(row_supplier))])
			app.metric(row_box, "Lead Time · Reliability · Quality", "%d days · %d%% · %d%%" % [int(source.lead), roundi(float(source.reliability) * 100.0), roundi(float(source.quality) * 100.0)])
			if not available:
				row_box.add_child(app.label("Unlock this supplier platform through company sales progression.", 12, Style.MUTED))
			else:
				var actions: HBoxContainer = app.row(row_box)
				app.action(actions, "Request Quotation", func():
					var result := Supply.negotiate(state, product, row_supplier, units_from(quantity.text))
					if not result.is_empty():
						app.set_notice(result, true)
						return
					app.persist("Product quotation received.")
					app.refresh_view()
				)
				app.action(actions, "Accept Quotation", func():
					app.sim.select_supplier(product, row_supplier)
					supplier.select(supplier_indices.find(row_supplier))
					app.set_meta("accepted_quote_supplier_%d" % product, row_supplier)
					app.persist("Supplier quotation accepted for this product.")
					app.refresh_view()
				, true)
		if is_instance_valid(purchase_button):
			purchase_button.disabled = int(app.get_meta("accepted_quote_supplier_%d" % product, -1)) != supplier_index
	quantity.text_changed.connect(func(_value: String): refresh.call())
	supplier.item_selected.connect(func(index: int):
		app.set_meta("accepted_quote_supplier_%d" % product, -1)
		app.sim.select_supplier(product, supplier_indices[index])
		app.persist("Supplier selected.")
		refresh.call()
	)
	app.action(supply, "Request Quotation", func():
		var result := Supply.negotiate(state, product, supplier_indices[supplier.selected], units_from(quantity.text))
		if not result.is_empty():
			app.set_notice(result, true)
			return
		app.persist("Product quotation received.")
		refresh.call()
	)
	purchase_button = app.action(supply, "Purchase Inventory", func():
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
	supplier_returns(app, product)

static func supplier_returns(app: Control, product: int) -> void:
	var state: Dictionary = app.sim.state
	Fulfillment.allocate_preorders(app.sim)
	var view: VBoxContainer = app.card("Return Inventory to Supplier")
	view.add_child(app.label("Only available, unreserved warehouse stock can be returned. Refunds are 50% of original goods cost; inbound freight is not refunded.", 13, Style.MUTED))
	var sources := Supply.return_sources(state, product)
	if sources.is_empty():
		view.add_child(app.label("No unreserved purchased stock is eligible to return.", 14, Style.MUTED))
	else:
		var supplier_ids: Array[int] = []
		var supplier_choices: Array[String] = []
		for source in sources:
			supplier_ids.append(int(source.supplier))
			supplier_choices.append("%s · %d available" % [str(source.name), int(source.units)])
		var supplier: OptionButton = app.dropdown(view, supplier_choices, 0)
		var quantity: LineEdit = app.field(view, "Quantity to Return", "1", 10)
		quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		var preview_label: Label = app.label("", 14, Style.GOLD)
		view.add_child(preview_label)
		var refresh_preview := func():
			var preview := Supply.preview_return(state, product, supplier_ids[supplier.selected], units_from(quantity.text))
			if not str(preview.get("error", "")).is_empty():
				preview_label.text = str(preview.error)
				return
			preview_label.text = "Original goods cost %s · Landed inventory removed %s · Supplier refund %s" % [
				app.money(int(preview.original_purchase_cost)), app.money(int(preview.landed_cost)), app.money(int(preview.refund))]
		quantity.text_changed.connect(func(_value: String): refresh_preview.call())
		supplier.item_selected.connect(func(_index: int): refresh_preview.call())
		refresh_preview.call()
		app.action(view, "Return Stock", func():
			var preview := Supply.preview_return(state, product, supplier_ids[supplier.selected], units_from(quantity.text))
			if not str(preview.get("error", "")).is_empty():
				app.set_notice(str(preview.error), true)
				return
			app.confirm_action("Return %d units to %s?" % [int(preview.units), str(preview.supplier_name)],
				"This permanently removes unreserved stock. The refund is %s; inbound freight is not refunded." % app.money(int(preview.refund)),
				"Confirm Return", func():
					var result: Dictionary = app.sim.return_stock(product, supplier_ids[supplier.selected], units_from(quantity.text))
					if not str(result.get("error", "")).is_empty():
						app.set_notice(str(result.error), true)
						return
					app.persist("Supplier return recorded in company cash and the financial ledger.")
					app.refresh_view()
			)
		, true)
	var history: VBoxContainer = app.card("Supplier Return History")
	var records: Array = []
	for record in state.get("supplier_returns", []):
		if int(record.get("product", -1)) == product: records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) > int(b.id))
	if records.is_empty():
		history.add_child(app.label("No supplier returns have been recorded for this product.", 13, Style.MUTED))
	else:
		for record in records.slice(0, mini(5, records.size())):
			app.metric(history, "%s · %d units · %s" % [str(record.date), int(record.units), str(record.supplier_name)],
				"Goods cost %s · Refund %s" % [app.money(int(record.original_purchase_cost)), app.money(int(record.refund))])

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
