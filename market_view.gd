extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Calendar = preload("res://game_calendar.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
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
	app.metric(catalog, "Category · Estimated supplier cost", "%s · %s" % [Catalog.PRODUCTS[product].category, app.money(Catalog.quote(app.sim.state.country, product, int(item.supplier)))])
	app.metric(catalog, "Demand · Competition", "%.2f · %.2f" % [Catalog.PRODUCTS[product].demand, Catalog.PRODUCTS[product].competition])
	supplier_form(app, product, item, stock_label)

static func supplier_form(app: Control, product: int, item: Dictionary, stock_label: Label) -> void:
	var state: Dictionary = app.sim.state
	SupplierCredit.ensure(state)
	var company_key := str(state.get("company_id", "legacy-company"))
	var safe_company_key := company_key.replace("-", "_")
	var route_key := "catalog_supplier_%s_%d" % [safe_company_key, product]
	var accepted_key := "accepted_quote_%s_%d" % [safe_company_key, product]
	var last_supplier_key := "last_catalog_supplier_%s_%d" % [safe_company_key, product]
	var selected_supplier := int(app.get_meta(route_key, -1))
	var supplier_indices: Array[int] = []
	for supplier_id in Catalog.SUPPLIER_SELECTION_INDICES:
		supplier_indices.append(int(supplier_id))
	var supply: VBoxContainer = app.card("Product Catalogue · Suppliers · %s" % Catalog.PRODUCTS[product].name)
	supply.add_child(app.label("Select a supplier for this product, review the terms, negotiate, then accept an offer before ordering.", 13, Style.MUTED))
	var inbound: VBoxContainer = app.card("Inbound Stock")
	var shipments: VBoxContainer = app.stack(inbound)
	var quantity: LineEdit
	var payment: OptionButton
	if selected_supplier < 0 or selected_supplier not in supplier_indices:
		var list: VBoxContainer = app.stack(supply, 6)
		list.name = "CompactSupplierList"
		for candidate in supplier_indices:
			var row_supplier := int(candidate)
			var provider: Dictionary = Catalog.SUPPLIERS[row_supplier]
			var available := Supply.supplier_unlocked(state, row_supplier)
			var price := Catalog.quote(state.country, product, row_supplier) + Catalog.inbound_freight(state.country, row_supplier)
			var entry: HBoxContainer = app.row(list)
			entry.name = "SupplierChoice%d" % row_supplier
			var summary := "%s · %s landed · MOQ %s · %d days%s" % [str(provider.name), app.money(price), _format_quantity(int(provider.minimum)), int(provider.lead), " · locked" if not available else ""]
			var last_selected := int(app.get_meta(last_supplier_key, -1)) == row_supplier
			if last_selected: summary = "Selected · " + summary
			var text: Label = app.label(summary, 13, Style.GOLD if last_selected else (Style.TEXT if available else Style.MUTED))
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.add_child(text)
			var choose: Button = app.action(entry, "View Details", func():
				app.set_meta(route_key, row_supplier)
				app.set_meta(last_supplier_key, row_supplier)
				app.refresh_view()
			)
			choose.disabled = not available
			choose.custom_minimum_size = Vector2(116, 44)
		if item.has("legacy_supplier"):
			supply.add_child(app.label("Existing purchases from %s remain in your history. Choose a currently available supplier for new orders." % str(item.legacy_supplier.name), 12, Style.MUTED))
	else:
		var provider: Dictionary = Catalog.SUPPLIERS[selected_supplier]
		var quantity_key := "%s_quantity_%d" % [route_key, selected_supplier]
		var title: VBoxContainer = app.card("Supplier Details · %s" % str(provider.name))
		title.name = "SelectedSupplierDetails"
		var terms: Dictionary = Supply.quote(state, product, selected_supplier)
		var has_negotiated := int(terms.get("discount", 0)) > 0 and int(terms.get("expires", 0)) >= int(state.day)
		app.metric(title, "Fulfillment Capability", "Direct-to-customer available" if provider.direct else "Warehouse inventory only")
		app.metric(title, "Quality · Reliability", "%d%% · %d%%" % [roundi(float(provider.quality) * 100.0), roundi(float(provider.reliability) * 100.0)])
		app.metric(title, "Lead Time · MOQ · Maximum Order", "%d days · %s · %s" % [int(provider.lead), _format_quantity(int(provider.minimum)), _format_quantity(Supply.maximum_order_quantity(selected_supplier))])
		app.metric(title, "Landed Cost Per Unit", app.money(Catalog.quote(state.country, product, selected_supplier) + Catalog.inbound_freight(state.country, selected_supplier)))
		var quote_status: Label = app.label("", 14, Style.GOLD)
		title.add_child(quote_status)
		quantity = app.field(title, "Purchase Quantity", str(app.get_meta(quantity_key, str(int(provider.minimum)))), 10)
		quantity.name = "SupplierPurchaseQuantity"
		quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		var total_label: Label = app.label("", 16, Style.TEXT)
		title.add_child(total_label)
		payment = app.dropdown(title, ["Pay Upfront", "Supplier Credit"], 0)
		var credit_label: Label = app.label("", 13, Style.MUTED)
		title.add_child(credit_label)
		var accepted := int(app.get_meta(accepted_key, -1)) == selected_supplier
		var accepted_label: Label = app.label("Offer accepted" if accepted else "Accept an offer before placing a purchase order.", 13, Style.GREEN if accepted else Style.MUTED)
		title.add_child(accepted_label)
		var buy_state := {"button": null}
		var update_detail := func():
			var qty := units_from(quantity.text)
			var breakdown := Supply.purchase_breakdown(state, product, selected_supplier, qty)
			var current_quote := Supply.quote(state, product, selected_supplier)
			var negotiated_valid := int(current_quote.get("discount", 0)) > 0 and int(current_quote.get("expires", 0)) >= int(state.day)
			var use_negotiated := negotiated_valid and qty >= int(current_quote.get("minimum", 0))
			var goods := int(current_quote.cost) if use_negotiated else Catalog.quote(state.country, product, selected_supplier)
			var freight := Catalog.inbound_freight(state.country, selected_supplier)
			if use_negotiated:
				quote_status.text = "Negotiated offer: %d%% off at %s+ units, expires %s." % [int(current_quote.discount), _format_quantity(int(current_quote.minimum)), Calendar.format(int(current_quote.expires))]
			elif negotiated_valid:
				quote_status.text = "Negotiated offer starts at %s units. Standard rate applies below the minimum." % _format_quantity(int(current_quote.minimum))
			else:
				quote_status.text = "Standard simulated supplier terms."
			var breakdown_error := not str(breakdown.get("error", "")).is_empty()
			if breakdown_error:
				total_label.text = str(breakdown.error)
			else:
				total_label.text = "Goods %s · Freight %s · Total %s" % [app.money(goods * qty), app.money(freight * qty), app.money((goods + freight) * qty)]
			var eligibility := SupplierCredit.eligibility(state, selected_supplier)
			credit_label.text = "Trust %d/100 · Settled purchases %d · Credit limit %s · Available %s\n" % [int(eligibility.trust), int(eligibility.settled_purchases), app.money(int(eligibility.credit_limit)), app.money(int(eligibility.available))]
			credit_label.text += "%d-day terms · Due %s" % [SupplierCredit.PAYMENT_TERM_DAYS, Calendar.format(int(eligibility.due_day))] if eligibility.eligible else str(eligibility.reason)
			payment.set_item_disabled(1, not eligibility.eligible)
			if payment.selected == 1 and not eligibility.eligible: payment.select(0)
			var accepted_now := int(app.get_meta(accepted_key, -1)) == selected_supplier
			accepted_label.text = "Offer accepted" if accepted_now else "Accept an offer before placing a purchase order."
			accepted_label.add_theme_color_override("font_color", Style.GREEN if accepted_now else Style.MUTED)
			if breakdown_error:
				buy_state.button.disabled = true
			elif payment.selected == 1:
				buy_state.button.disabled = not accepted_now or int(breakdown.total) > int(eligibility.available)
			else:
				buy_state.button.disabled = not accepted_now
		quantity.text_changed.connect(func(value: String):
			app.set_meta(quantity_key, value)
			update_detail.call()
		)
		payment.item_selected.connect(func(_index: int): update_detail.call())
		app.action(title, "Negotiate", func():
			var result := Supply.negotiate(state, product, selected_supplier, units_from(quantity.text))
			if not result.is_empty():
				app.set_notice(result, true)
				return
			app.set_meta(accepted_key, -1)
			app.persist("Negotiation complete. Review the updated offer before accepting.")
			app.refresh_view()
		)
		var actions: HBoxContainer = app.row(title)
		app.action(actions, "Accept Offer", func():
			app.sim.select_supplier(product, selected_supplier)
			app.set_meta(accepted_key, selected_supplier)
			app.persist("Supplier offer accepted for this product.")
			app.refresh_view()
		, true)
		buy_state.button = app.action(actions, "Purchase", func():
			if int(app.get_meta(accepted_key, -1)) != selected_supplier:
				app.set_notice("Accept the supplier offer before purchasing inventory.", true)
				return
			var result: Dictionary
			if payment.selected == 1:
				result = SupplierCredit.purchase_on_credit(state, product, selected_supplier, units_from(quantity.text))
				if str(result.get("error", "")).is_empty():
					app.remove_meta(quantity_key)
					app.persist("Inventory purchased on supplier credit. Repayment is due %s." % str(result.obligation.due_date))
			else:
				var cash_error: String = app.sim.buy(product, selected_supplier, units_from(quantity.text))
				result = {"error": cash_error}
				if cash_error.is_empty():
					app.remove_meta(quantity_key)
					app.persist("Purchase order placed. Track it below.")
			if not str(result.get("error", "")).is_empty():
				app.set_notice(str(result.error), true)
				return
			app.refresh_view()
		, true)
		app.action(actions, "Back", func():
			app.set_meta(route_key, -1)
			app.refresh_view()
		)
		update_detail.call()
		var forecast := Supply.forecast(app.sim, product, selected_supplier)
		var forecast_text := "Forecast %d units/day · Restock suggestion %d" % [roundi(float(forecast.daily)), int(forecast.suggested)]
		title.add_child(app.label(forecast_text, 12, Style.MUTED))
	var inbound_summary: VBoxContainer = app.card("Inbound Stock")
	stock_label.text = "%d available · %d inbound · %s available cash" % [app.sim.stock(product), Supply.incoming(state, product), app.money(state.cash)]
	inbound_summary.add_child(stock_label)
	refresh_inbound(app, product, inbound, shipments)
	supplier_returns(app, product)
	supplier_credit_payables(app)

static func supplier_credit_payables(app: Control) -> void:
	var state: Dictionary = app.sim.state
	SupplierCredit.ensure(state)
	if state.supplier_credit.obligations.is_empty() and state.supplier_credit.payments.is_empty(): return
	var view: VBoxContainer = app.wide_card("Supplier Credit Accounts")
	view.name = "SupplierCreditAccounts"
	var obligations: Array = state.supplier_credit.get("obligations", [])
	var open_count := 0
	for obligation in obligations:
		if int(obligation.get("balance", 0)) <= 0: continue
		open_count += 1
		var payable: VBoxContainer = app.card("%s · PO-%04d" % [str(obligation.supplier_name), int(obligation.purchase_id)])
		app.metric(payable, "Product · Quantity", "%s · %d units" % [Catalog.PRODUCTS[int(obligation.product)].name, int(obligation.units)])
		app.metric(payable, "Remaining Payable · Due Date", "%s · %s" % [app.money(int(obligation.balance)), str(obligation.due_date)], Style.GOLD if int(state.day) <= int(obligation.due_day) else Style.RED)
		var amount: LineEdit = app.field(payable, "Repayment Amount", app.amount_text(int(obligation.balance), true).replace(",", ""), 16)
		amount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		var request_id := "ui-repay-%d-%d" % [int(obligation.id), Time.get_ticks_usec()]
		app.action(payable, "Repay Supplier", func():
			var cents: int = app.price_cents(amount.text)
			var result := SupplierCredit.repay(state, int(obligation.id), cents, request_id)
			if not str(result.get("error", "")).is_empty():
				app.set_notice(str(result.error), true)
				return
			app.persist("Supplier repayment recorded. Remaining payable: %s." % app.money(int(result.balance)))
			app.refresh_view()
		, true)
	if open_count == 0:
		view.add_child(app.label("No supplier-credit payables are outstanding. Cash purchases continue to settle immediately.", 14, Style.MUTED))
	else:
		view.add_child(app.label("Payments reduce company cash and the related payable. Due dates and repayment history are saved with this company.", 13, Style.MUTED))
	var history: VBoxContainer = app.card("Recent Supplier Payments")
	var payments: Array = state.supplier_credit.get("payments", []).duplicate()
	payments.reverse()
	if payments.is_empty():
		history.add_child(app.label("No supplier-credit repayments have been recorded.", 13, Style.MUTED))
	else:
		for payment in payments.slice(0, mini(5, payments.size())):
			var provider_name: String = Catalog.SUPPLIERS[int(payment.supplier)].name if int(payment.supplier) in range(Catalog.SUPPLIERS.size()) else "Supplier"
			app.metric(history, "%s · %s · %s" % [str(payment.date), provider_name, "On time" if bool(payment.timely) else "Late"], app.money(int(payment.amount)))

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
