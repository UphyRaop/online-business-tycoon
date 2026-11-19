extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Calendar = preload("res://game_calendar.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
const Style = preload("res://corporate_theme.gd")

const CATALOG_STAGE_META := "product_catalog_stage"
const SELECTED_SUPPLIER_META := "catalog_selected_supplier"
const QUOTATION_META := "catalog_purchase_quotation"


static func show(app: Control) -> void:
	match str(app.get_meta(CATALOG_STAGE_META, "categories")):
		"categories":
			show_categories(app)
		"products":
			show_products(app)
		"confirmation":
			show_purchase_confirmation(app)
		_:
			show_supplier_workflow(app)

static func show_categories(app: Control) -> void:
	var catalogue: VBoxContainer = app.wide_card("Product Catalogue")
	catalogue.name = "ProductCataloguePanel"
	catalogue.add_child(app.label("Choose a category to compare products and suppliers.", 14, Style.MUTED))
	var grid := GridContainer.new()
	grid.name = "ProductCategoryGrid"
	grid.columns = 2 if app.size.x >= 620.0 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	catalogue.add_child(grid)
	for category in Catalog.CATEGORIES:
		var name := str(category)
		var count := Catalog.PRODUCTS.filter(func(product: Dictionary): return str(product.category) == name).size()
		var panel: VBoxContainer = _catalog_card(grid, name)
		panel.name = "CatalogueCategory_" + _safe_name(name)
		panel.add_child(app.label("%d products" % count, 13, Style.MUTED))
		var icon := TextureRect.new()
		icon.name = "CategoryIcon"
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load("res://assets/navigation/market.svg")
		panel.add_child(icon)
		app.action(panel, "Browse " + name, func():
			app.catalog_category = Catalog.CATEGORIES.find(name)
			app.catalog_search = ""
			app.set_meta(CATALOG_STAGE_META, "products")
			app.refresh_view()
		, true)
	app.secondary_tab(catalogue, "My Products", app.navigate.bind("My Products"), app.page == "My Products")

static func show_products(app: Control) -> void:
	var category_index := int(app.catalog_category)
	if category_index not in range(Catalog.CATEGORIES.size()):
		app.catalog_category = -1
		app.set_meta(CATALOG_STAGE_META, "categories")
		show_categories(app)
		return
	var category := str(Catalog.CATEGORIES[category_index])
	var catalogue: VBoxContainer = app.wide_card(category)
	catalogue.name = "CategoryProductsPanel"
	app.action(catalogue, "Back to Categories", func():
		app.set_meta(CATALOG_STAGE_META, "categories")
		app.refresh_view()
	)
	var search: LineEdit = app.field(catalogue, "Search Products", app.catalog_search, 64)
	search.name = "CatalogueProductSearch"
	var product_grid := VBoxContainer.new()
	product_grid.name = "CategoryProductList"
	product_grid.add_theme_constant_override("separation", 6)
	catalogue.add_child(product_grid)
	var product_cards: Array[Dictionary] = []
	var shown := 0
	var needle := str(app.catalog_search).strip_edges().to_lower()
	for product_index in Catalog.PRODUCTS.size():
		var product: Dictionary = Catalog.PRODUCTS[product_index]
		if str(product.category) != category:
			continue
		var matches := needle.is_empty() or str(product.name).to_lower().contains(needle) or str(product.id).to_lower().contains(needle)
		if matches: shown += 1
		var suppliers := _available_suppliers(app.sim.state, product_index)
		var starting_cost := _starting_landed_cost(app.sim.state, product_index, suppliers)
		var card: VBoxContainer = _catalog_card(product_grid, str(product.name))
		card.name = "CatalogueProduct_%d" % product_index
		app.metric(card, "Available Suppliers", "%d" % suppliers.size())
		app.metric(card, "Starting Landed Cost", app.money(starting_cost))
		var selected_product := product_index
		app.action(card, "Choose Product", func():
			app.selected_product = selected_product
			app.set_meta(CATALOG_STAGE_META, "suppliers")
			app.open_product(selected_product)
		, true)
		card.get_parent().visible = matches
		product_cards.append({"index": product_index, "card": card})
	var empty: Label = app.label("No products match this search. Clear the search or return to Categories.", 14, Style.MUTED)
	empty.name = "ProductCatalogueEmptyState"
	empty.visible = shown == 0
	product_grid.add_child(empty)
	search.text_changed.connect(func(value: String):
		app.catalog_search = value
		var visible_count := 0
		var filter := value.strip_edges().to_lower()
		for entry in product_cards:
			var item: Dictionary = Catalog.PRODUCTS[int(entry.index)]
			var matches := filter.is_empty() or str(item.name).to_lower().contains(filter) or str(item.id).to_lower().contains(filter)
			var card: VBoxContainer = entry.card
			(card.get_parent() as Control).visible = matches
			if matches: visible_count += 1
		empty.text = "No products match this search. Clear the search or return to Categories." if visible_count == 0 else ""
		empty.visible = visible_count == 0
	)

static func show_supplier_workflow(app: Control) -> void:
	var product: int = app.selected_product
	if product not in range(Catalog.PRODUCTS.size()):
		app.set_meta(CATALOG_STAGE_META, "categories")
		show_categories(app)
		return
	var item: Dictionary = app.sim.product_state(product)
	var breadcrumbs: VBoxContainer = app.wide_card("Supplier Sourcing · " + Catalog.PRODUCTS[product].name)
	breadcrumbs.name = "SupplierWorkflowBreadcrumbs"
	var category_label := str(Catalog.CATEGORIES[app.catalog_category]) if int(app.catalog_category) in range(Catalog.CATEGORIES.size()) else "Categories"
	app.action(breadcrumbs, "Back to " + category_label, func():
		app.set_meta(CATALOG_STAGE_META, "products")
		app.refresh_view()
	)
	var stock_label: Label = app.label("", 15, Style.MUTED)
	supplier_form(app, product, item, stock_label)

static func show_purchase_confirmation(app: Control) -> void:
	var receipt: Dictionary = app.get_meta("catalog_purchase_receipt", {})
	if receipt.is_empty():
		app.set_meta(CATALOG_STAGE_META, "categories")
		show_categories(app)
		return
	var view: VBoxContainer = app.wide_card("Purchase Confirmed")
	view.name = "SupplierPurchaseConfirmation"
	app.metric(view, "Product", str(receipt.get("product_name", "")))
	app.metric(view, "Supplier", str(receipt.get("supplier_name", "")))
	app.metric(view, "Quantity · Payment", "%s units · %s" % [_format_quantity(int(receipt.get("units", 0))), str(receipt.get("payment", ""))])
	app.metric(view, "Purchase Cost", str(receipt.get("total", "")), Style.GOLD)
	app.metric(view, "Expected Delivery", str(receipt.get("delivery", "")))
	view.add_child(app.label("The order is recorded in Inbound Stock. Inventory and accounting follow the existing supplier purchase workflow.", 13, Style.MUTED))
	app.action(view, "Continue Shopping", func():
		app.remove_meta("catalog_purchase_receipt")
		app.set_meta(CATALOG_STAGE_META, "categories")
		app.catalog_category = -1
		app.refresh_view()
	, true)
	app.action(view, "View Inbound Stock", app.navigate.bind("Inbound Stock"))

static func _available_suppliers(state: Dictionary, product: int) -> Array[int]:
	var result: Array[int] = []
	for candidate in Catalog.SUPPLIER_SELECTION_INDICES:
		var supplier := int(candidate)
		if Supply.supplier_unlocked(state, supplier):
			result.append(supplier)
	return result

static func _starting_landed_cost(state: Dictionary, product: int, suppliers: Array[int]) -> int:
	var minimum := -1
	for supplier in suppliers:
		var cost := Catalog.quote(int(state.country), product, supplier) + Catalog.inbound_freight(int(state.country), supplier)
		if minimum < 0 or cost < minimum:
			minimum = cost
	return maxi(0, minimum)

static func _safe_name(value: String) -> String:
	return value.replace("&", "and").replace(" ", "_")

static func _catalog_card(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "CatalogueCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.LINE, 14, 12))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	content.add_child(heading)
	return content

static func supplier_form(app: Control, product: int, item: Dictionary, stock_label: Label) -> void:
	var state: Dictionary = app.sim.state
	SupplierCredit.ensure(state)
	var company_key := str(state.get("company_id", "legacy-company")).replace("-", "_")
	var route_key := "catalog_supplier_%s_%d" % [company_key, product]
	var accepted_key := "accepted_quote_%s_%d" % [company_key, product]
	var last_supplier_key := "last_catalog_supplier_%s_%d" % [company_key, product]
	var selected_supplier := int(app.get_meta(route_key, -1))
	var supplier_indices: Array[int] = []
	for supplier_id in Catalog.SUPPLIER_SELECTION_INDICES:
		supplier_indices.append(int(supplier_id))
	var supply: VBoxContainer = app.wide_card("Suppliers for " + str(Catalog.PRODUCTS[product].name))
	supply.name = "ProductSupplierList"
	supply.add_child(app.label("Compare supplier terms. Select one supplier to review the full offer.", 13, Style.MUTED))
	var quantity: LineEdit
	var payment: OptionButton
	if selected_supplier < 0 or selected_supplier not in supplier_indices:
		var list: VBoxContainer = app.stack(supply, 6)
		list.name = "CompactSupplierList"
		for candidate in supplier_indices:
			var row_supplier := int(candidate)
			var provider: Dictionary = Catalog.SUPPLIERS[row_supplier]
			var available := Supply.supplier_unlocked(state, row_supplier)
			var goods := Catalog.quote(state.country, product, row_supplier)
			var freight := Catalog.inbound_freight(state.country, row_supplier)
			var entry: VBoxContainer = _catalog_card(list, str(provider.name))
			entry.name = "SupplierChoice%d" % row_supplier
			app.metric(entry, "Quality · Reliability", "%d%% · %d%%" % [roundi(float(provider.quality) * 100.0), roundi(float(provider.reliability) * 100.0)])
			app.metric(entry, "Lead Time · Minimum Order", "%d days · %s units" % [int(provider.lead), _format_quantity(int(provider.minimum))])
			app.metric(entry, "Landed Cost Per Unit", app.money(goods + freight))
			if not available:
				entry.add_child(app.label("Supplier platform is locked. Unlock it through company progression.", 12, Style.MUTED))
			var last_selected := int(app.get_meta(last_supplier_key, -1)) == row_supplier
			var choose: Button = app.action(entry, "Select Supplier" if not last_selected else "Selected Supplier", func():
				app.set_meta(route_key, row_supplier)
				app.set_meta(last_supplier_key, row_supplier)
				app.set_meta(SELECTED_SUPPLIER_META, row_supplier)
				app.refresh_view()
			, true)
			choose.disabled = not available
		if item.has("legacy_supplier"):
			supply.add_child(app.label("Existing purchases from %s remain in your history. Choose a currently available supplier for new orders." % str(item.legacy_supplier.name), 12, Style.MUTED))
	else:
		var provider: Dictionary = Catalog.SUPPLIERS[selected_supplier]
		var quantity_key := "%s_quantity_%d" % [route_key, selected_supplier]
		var quotation_key := "%s_%s_%d_%d" % [QUOTATION_META, company_key, product, selected_supplier]
		var title: VBoxContainer = app.wide_card("Supplier Details · " + str(provider.name))
		title.name = "SelectedSupplierDetails"
		var standard_unit := Catalog.quote(state.country, product, selected_supplier)
		var freight_unit := Catalog.inbound_freight(state.country, selected_supplier)
		var current_quote: Dictionary = Supply.quote(state, product, selected_supplier)
		var has_negotiated := int(current_quote.get("discount", 0)) > 0 and int(current_quote.get("expires", 0)) >= int(state.day)
		app.metric(title, "Quoted Goods Cost Per Unit", app.money(standard_unit))
		app.metric(title, "Inbound Freight Per Unit", app.money(freight_unit))
		app.metric(title, "Quality · Reliability", "%d%% · %d%%" % [roundi(float(provider.quality) * 100.0), roundi(float(provider.reliability) * 100.0)])
		app.metric(title, "Lead Time · MOQ · Maximum Order", "%d days · %s · %s units" % [int(provider.lead), _format_quantity(int(provider.minimum)), _format_quantity(Supply.maximum_order_quantity(selected_supplier))])
		app.metric(title, "Fulfillment Capability", "Direct-to-customer available" if provider.direct else "Warehouse inventory only")
		var quote_status: Label = app.label("", 13, Style.GOLD)
		title.add_child(quote_status)
		quantity = app.field(title, "Purchase Quantity", str(app.get_meta(quantity_key, str(int(provider.minimum)))), 10)
		quantity.name = "SupplierPurchaseQuantity"
		quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		var payment_index := 0
		var previous_quote: Dictionary = app.get_meta(quotation_key, {})
		if str(previous_quote.get("payment_method", "cash")) == "credit": payment_index = 1
		payment = app.dropdown(title, ["Pay Upfront", "Supplier Credit"], payment_index)
		var credit_label: Label = app.label("", 13, Style.MUTED)
		title.add_child(credit_label)
		var accepted_label: Label = app.label("Offer accepted" if int(app.get_meta(accepted_key, -1)) == selected_supplier else "Accept the current supplier offer before generating a quotation.", 13, Style.GREEN if int(app.get_meta(accepted_key, -1)) == selected_supplier else Style.MUTED)
		title.add_child(accepted_label)
		var quotation_panel: VBoxContainer = _catalog_card(title, "Purchase Quotation")
		quotation_panel.name = "GeneratedPurchaseQuotation"
		var quotation_summary: Label = app.label("Generate a quotation after accepting the supplier offer.", 13, Style.MUTED)
		quotation_panel.add_child(quotation_summary)
		var quote_button: Button = app.action(title, "Generate Quotation", func():
			var accepted_now := int(app.get_meta(accepted_key, -1)) == selected_supplier
			if not accepted_now:
				app.set_notice("Accept the current supplier offer before generating a quotation.", true)
				return
			var qty := units_from(quantity.text)
			var breakdown := Supply.purchase_breakdown(state, product, selected_supplier, qty)
			if not str(breakdown.get("error", "")).is_empty():
				app.set_notice(str(breakdown.error), true)
				return
			if payment.selected == 1:
				var eligibility := SupplierCredit.eligibility(state, selected_supplier)
				if not bool(eligibility.eligible) or int(breakdown.total) > int(eligibility.available):
					app.set_notice(str(eligibility.reason) if not bool(eligibility.eligible) else "The quotation exceeds the available supplier credit.", true)
					return
			elif int(breakdown.total) > int(state.cash):
				app.set_notice("Insufficient company cash for this quotation.", true)
				return
			var negotiated := Supply.quote(state, product, selected_supplier)
			var quote := breakdown.duplicate(true)
			quote.merge({"payment_method": "credit" if payment.selected == 1 else "cash", "day": int(state.day),
				"offer_expires": int(negotiated.get("expires", 0)), "offer_minimum": int(negotiated.get("minimum", 0)),
				"offer_discount": int(negotiated.get("discount", 0))}, true)
			app.set_meta(quotation_key, quote)
			app.set_notice("Quotation generated. Review the full landed-cost breakdown before confirming purchase.")
			app.refresh_view()
		, true)
		var confirm_button: Button = app.action(title, "Confirm Purchase", func():
			var quote: Dictionary = app.get_meta(quotation_key, {})
			if not _quotation_valid(quote, state, product, selected_supplier, units_from(quantity.text), payment.selected):
				app.set_notice("Generate a current quotation before confirming this purchase.", true)
				return
			var payment_name := "Supplier Credit" if payment.selected == 1 else "Pay Upfront"
			var message := "%s · %s · %s units\n%s goods + %s freight\nTotal %s · Delivery in %d days" % [
				str(Catalog.PRODUCTS[product].name), str(provider.name), _format_quantity(units_from(quantity.text)),
				app.money(int(quote.goods_unit_cost) * int(quote.units)), app.money(int(quote.freight_unit_cost) * int(quote.units)),
				app.money(int(quote.total)), int(provider.lead)]
			message += "\nPayment: %s" % payment_name
			app.confirm_action("Confirm Purchase", message, "Place Order", func():
				if bool(app.get_meta("supplier_purchase_processing", false)):
					return
				app.set_meta("supplier_purchase_processing", true)
				var latest: Dictionary = app.get_meta(quotation_key, {})
				if not _quotation_valid(latest, state, product, selected_supplier, units_from(quantity.text), payment.selected):
					app.set_meta("supplier_purchase_processing", false)
					app.set_notice("The quotation expired or changed. Generate a new quotation before ordering.", true)
					app.refresh_view()
					return
				var purchase_error := ""
				var purchase_id := -1
				if payment.selected == 1:
					var result := SupplierCredit.purchase_on_credit(state, product, selected_supplier, units_from(quantity.text))
					purchase_error = str(result.get("error", ""))
					if purchase_error.is_empty(): purchase_id = int(result.get("obligation", {}).get("purchase_id", -1))
				else:
					purchase_error = str(app.sim.buy(product, selected_supplier, units_from(quantity.text)))
					if purchase_error.is_empty() and not state.inbound.is_empty(): purchase_id = int(state.inbound.back().id)
				if not purchase_error.is_empty():
					app.set_meta("supplier_purchase_processing", false)
					app.set_notice(purchase_error, true)
					app.refresh_view()
					return
				app.remove_meta(quantity_key)
				app.remove_meta(quotation_key)
				app.set_meta(accepted_key, -1)
				var shipment: Dictionary = {}
				for batch in state.inbound:
					if int(batch.id) == purchase_id: shipment = batch; break
				var payment_name_after := "Supplier Credit" if payment.selected == 1 else "Pay Upfront"
				app.set_meta("catalog_purchase_receipt", {"product_name": Catalog.PRODUCTS[product].name,
					"supplier_name": provider.name, "units": int(latest.units), "payment": payment_name_after,
					"total": app.money(int(latest.total)), "delivery": Calendar.format(int(shipment.get("arrival", state.day + int(provider.lead)))),
					"purchase_id": purchase_id})
				app.set_meta(CATALOG_STAGE_META, "confirmation")
				app.set_meta("supplier_purchase_processing", false)
				app.persist("Purchase order placed. The new order is in your inbound shipments.")
				app.refresh_view()
			)
		, true)
		confirm_button.name = "ConfirmSupplierPurchase"
		var negotiate: Button = app.action(title, "Negotiate", func():
			var result := Supply.negotiate(state, product, selected_supplier, units_from(quantity.text))
			if not result.is_empty():
				app.set_notice(result, true)
				return
			app.set_meta(accepted_key, -1)
			app.remove_meta(quotation_key)
			app.persist("Negotiation complete. Review the supplier's actual response before accepting.")
			app.refresh_view()
		)
		negotiate.name = "NegotiateSupplierOffer"
		var accept: Button = app.action(title, "Accept Offer", func():
			app.sim.select_supplier(product, selected_supplier)
			app.set_meta(accepted_key, selected_supplier)
			app.remove_meta(quotation_key)
			app.persist("Supplier offer accepted. Generate a quotation to continue.")
			app.refresh_view()
		, true)
		accept.name = "AcceptSupplierOffer"
		var back: Button = app.action(title, "Back to Suppliers", func():
			app.set_meta(route_key, -1)
			app.remove_meta(quotation_key)
			app.refresh_view()
		)
		back.name = "BackToSupplierList"
		var update_detail := func():
			var qty := units_from(quantity.text)
			var breakdown := Supply.purchase_breakdown(state, product, selected_supplier, qty)
			var active_offer := Supply.quote(state, product, selected_supplier)
			var negotiated_valid := int(active_offer.get("discount", 0)) > 0 and int(active_offer.get("expires", 0)) >= int(state.day)
			var unit_goods := int(breakdown.get("goods_unit_cost", standard_unit))
			var unit_freight := int(breakdown.get("freight_unit_cost", freight_unit))
			var landed := int(breakdown.get("landed_unit_cost", standard_unit + freight_unit))
			quote_status.text = "Quoted %s goods/unit · Proposed %s goods/unit%s" % [app.money(standard_unit), app.money(unit_goods), " · %d%% off until %s" % [int(active_offer.discount), Calendar.format(int(active_offer.expires))] if negotiated_valid else " · standard supplier offer"]
			var eligibility := SupplierCredit.eligibility(state, selected_supplier)
			credit_label.text = "Trust %d/100 · Settled %d · Credit limit %s · Available %s" % [int(eligibility.trust), int(eligibility.settled_purchases), app.money(int(eligibility.credit_limit)), app.money(int(eligibility.available))]
			if bool(eligibility.eligible): credit_label.text += "\n%d-day terms · Due %s" % [SupplierCredit.PAYMENT_TERM_DAYS, Calendar.format(int(eligibility.due_day))]
			else: credit_label.text += "\n" + str(eligibility.reason)
			payment.set_item_disabled(1, not bool(eligibility.eligible))
			if payment.selected == 1 and not bool(eligibility.eligible): payment.select(0)
			var accepted_now := int(app.get_meta(accepted_key, -1)) == selected_supplier
			accepted_label.text = "Offer accepted" if accepted_now else "Accept the current supplier offer before generating a quotation."
			accepted_label.add_theme_color_override("font_color", Style.GREEN if accepted_now else Style.MUTED)
			var total := int(breakdown.get("total", 0))
			var quote_valid := _quotation_valid(app.get_meta(quotation_key, {}), state, product, selected_supplier, qty, payment.selected)
			if not str(breakdown.get("error", "")).is_empty():
				quotation_summary.text = str(breakdown.error)
				quotation_summary.add_theme_color_override("font_color", Style.RED)
			elif quote_valid:
				var quotation: Dictionary = app.get_meta(quotation_key, {})
				quotation_summary.text = "%s units · Goods %s · Freight %s · Landed/unit %s · Total %s · %s" % [
					_format_quantity(qty), app.money(int(quotation.goods_unit_cost) * qty), app.money(int(quotation.freight_unit_cost) * qty),
					app.money(int(quotation.landed_unit_cost)), app.money(int(quotation.total)), "Credit" if payment.selected == 1 else "Cash"]
				quotation_summary.add_theme_color_override("font_color", Style.TEXT)
			else:
				quotation_summary.text = "No current quotation. Generate one after accepting the offer."
				quotation_summary.add_theme_color_override("font_color", Style.MUTED)
			quotation_panel.visible = accepted_now or quote_valid
			quote_button.disabled = not accepted_now or not str(breakdown.get("error", "")).is_empty()
			confirm_button.disabled = not accepted_now or not quote_valid
		quantity.text_changed.connect(func(value: String):
			app.set_meta(quantity_key, value)
			app.remove_meta(quotation_key)
			update_detail.call()
		)
		payment.item_selected.connect(func(_index: int):
			app.remove_meta(quotation_key)
			update_detail.call()
		)
		update_detail.call()
		if has_negotiated:
			title.add_child(app.label("Negotiated supplier response: %d%% off at %s+ units, expiring %s." % [int(current_quote.discount), _format_quantity(int(current_quote.minimum)), Calendar.format(int(current_quote.expires))], 12, Style.GOLD))
		var forecast := Supply.forecast(app.sim, product, selected_supplier)
		title.add_child(app.label("Forecast %d units/day · Restock suggestion %s units" % [roundi(float(forecast.daily)), _format_quantity(int(forecast.suggested))], 12, Style.MUTED))

static func _quotation_valid(quote: Dictionary, state: Dictionary, product: int, supplier: int, units: int, payment_index: int) -> bool:
	if quote.is_empty() or int(quote.get("day", -1)) != int(state.day): return false
	if int(quote.get("product", -1)) != product or int(quote.get("supplier", -1)) != supplier or int(quote.get("units", -1)) != units: return false
	if str(quote.get("payment_method", "")) != ("credit" if payment_index == 1 else "cash"): return false
	var offer := Supply.quote(state, product, supplier)
	if int(offer.get("discount", 0)) > 0 and int(state.day) > int(offer.get("expires", 0)): return false
	var latest := Supply.purchase_breakdown(state, product, supplier, units)
	return str(latest.get("error", "")).is_empty() and int(latest.get("total", -1)) == int(quote.get("total", -2))

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

static func inbound_stock(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var view: VBoxContainer = app.wide_card("Inbound Stock")
	view.name = "InboundStockPage"
	view.add_child(app.label("Track supplier orders until their inventory is received into the shared company stock.", 13, Style.MUTED))
	if state.get("inbound", []).is_empty():
		view.add_child(app.label("No inbound stock orders are currently in transit.", 14, Style.MUTED))
		return
	var batches: Array = state.inbound.duplicate(true)
	batches.sort_custom(func(a: Dictionary, b: Dictionary):
		var day_a: int = int(a.get("arrival", a.get("eta", state.day)))
		var day_b: int = int(b.get("arrival", b.get("eta", state.day)))
		return day_a < day_b
	)
	for batch in batches:
		var product := int(batch.get("product", -1))
		var supplier := int(batch.get("supplier", -1))
		if product not in range(Catalog.PRODUCTS.size()): continue
		var product_name := str(Catalog.PRODUCTS[product].name)
		var supplier_name := str(batch.get("supplier_name", Catalog.SUPPLIERS[supplier].name if supplier in range(Catalog.SUPPLIERS.size()) else "Supplier"))
		var eta := int(batch.get("arrival", batch.get("eta", state.day)))
		var card: VBoxContainer = app.card("PO-%04d · %s" % [int(batch.get("id", 0)), product_name])
		card.name = "InboundPurchase%d" % int(batch.get("id", 0))
		app.metric(card, "Supplier · Quantity", "%s · %s units" % [supplier_name, _format_quantity(int(batch.get("units", 0)))])
		app.metric(card, "Status · Estimated Arrival", "Delayed · %s" % Calendar.format(eta) if bool(batch.get("delayed", false)) else "In transit · %s" % Calendar.format(eta), Style.GOLD)
		app.metric(card, "Payment Method", "Supplier Credit" if str(batch.get("payment_method", "cash")) == "credit" else "Paid Upfront")
		app.metric(card, "Landed Cost Per Unit", app.money(int(batch.get("cost", 0))))
		app.action(card, "View Product", app.open_product.bind(product))

static func supplier_returns_page(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var intro: VBoxContainer = app.wide_card("Supplier Returns")
	intro.name = "SupplierReturnsPage"
	intro.add_child(app.label("Return only unreserved warehouse inventory to its original supplier. Return history is shown below.", 13, Style.MUTED))
	var selected_product := int(app.get_meta("supplier_returns_product", int(app.selected_product)))
	if selected_product not in range(Catalog.PRODUCTS.size()): selected_product = 0
	var picker: OptionButton = app.dropdown(intro, Catalog.PRODUCTS.map(func(item: Dictionary): return str(item.name)), selected_product)
	picker.name = "SupplierReturnProductSelection"
	picker.item_selected.connect(func(index: int):
		app.set_meta("supplier_returns_product", index)
		app.refresh_view()
	)
	_supplier_return_form(app, selected_product)
	var history: VBoxContainer = app.wide_card("Supplier Return History")
	history.name = "SupplierReturnHistory"
	var records: Array = state.get("supplier_returns", []).duplicate(true)
	records.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) > int(b.get("id", 0)))
	if records.is_empty():
		history.add_child(app.label("No supplier returns have been recorded.", 13, Style.MUTED))
	else:
		for record in records.slice(0, mini(10, records.size())):
			var product_id := int(record.get("product", -1))
			var product_name := str(Catalog.PRODUCTS[product_id].name) if product_id in range(Catalog.PRODUCTS.size()) else "Product"
			var row: VBoxContainer = app.card("%s · %s" % [str(record.get("date", Calendar.format(int(record.get("day", state.day))))), product_name])
			app.metric(row, "Supplier · Quantity", "%s · %s units" % [str(record.get("supplier_name", "Supplier")), _format_quantity(int(record.get("units", 0)))])
			app.metric(row, "Landed Inventory Removed", app.money(int(record.get("landed_cost", 0))))
			app.metric(row, "Supplier Refund", app.money(int(record.get("refund", 0))), Style.GREEN)

static func _supplier_return_form(app: Control, product: int) -> void:
	var state: Dictionary = app.sim.state
	Fulfillment.allocate_preorders(app.sim)
	var view: VBoxContainer = app.wide_card("Return Inventory")
	view.name = "SupplierReturnForm"
	view.add_child(app.label("Refunds use the original goods cost; inbound freight is not refunded. Reserved or direct-fulfilled units cannot be returned here.", 13, Style.MUTED))
	var sources := Supply.return_sources(state, product)
	if sources.is_empty():
		view.add_child(app.label("No unreserved purchased stock from this product is currently available to return.", 14, Style.MUTED))
		return
	var supplier_ids: Array[int] = []
	var supplier_choices: Array[String] = []
	for source in sources:
		supplier_ids.append(int(source.supplier))
		supplier_choices.append("%s · %s available" % [str(source.name), _format_quantity(int(source.units))])
	var supplier: OptionButton = app.dropdown(view, supplier_choices, 0)
	supplier.name = "SupplierReturnSupplierSelection"
	var quantity: LineEdit = app.field(view, "Quantity to Return", "1", 10)
	quantity.name = "SupplierReturnQuantity"
	quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var preview_label: Label = app.label("", 14, Style.GOLD)
	view.add_child(preview_label)
	var refresh_preview := func():
		var preview := Supply.preview_return(state, product, supplier_ids[supplier.selected], units_from(quantity.text))
		if not str(preview.get("error", "")).is_empty():
			preview_label.text = str(preview.error)
			return
		preview_label.text = "Original goods cost %s · Landed inventory removed %s · Supplier refund %s" % [app.money(int(preview.original_purchase_cost)), app.money(int(preview.landed_cost)), app.money(int(preview.refund))]
	quantity.text_changed.connect(func(_value: String): refresh_preview.call())
	supplier.item_selected.connect(func(_index: int): refresh_preview.call())
	refresh_preview.call()
	app.action(view, "Return Stock", func():
		var preview := Supply.preview_return(state, product, supplier_ids[supplier.selected], units_from(quantity.text))
		if not str(preview.get("error", "")).is_empty():
			app.set_notice(str(preview.error), true)
			return
		app.confirm_action("Return %s units to %s?" % [_format_quantity(int(preview.units)), str(preview.supplier_name)], "This permanently removes unreserved stock. The refund is %s; inbound freight is not refunded." % app.money(int(preview.refund)), "Confirm Return", func():
			var result: Dictionary = app.sim.return_stock(product, supplier_ids[supplier.selected], units_from(quantity.text))
			if not str(result.get("error", "")).is_empty():
				app.set_notice(str(result.error), true)
				return
			app.persist("Supplier return recorded in company cash and the financial ledger.")
			app.refresh_view()
		)
	, true)

static func supplier_relationships(app: Control) -> void:
	var state: Dictionary = app.sim.state
	SupplierCredit.ensure(state)
	var intro: VBoxContainer = app.wide_card("Supplier Relationships")
	intro.name = "SupplierRelationshipsPage"
	intro.add_child(app.label("Trust reflects settled purchases and timely repayments. Credit remains limited by supplier terms and company financial condition.", 13, Style.MUTED))
	var relationships: Dictionary = state.supplier_credit.get("relationships", {})
	var suppliers: Array[int] = []
	for candidate in Catalog.SUPPLIER_SELECTION_INDICES:
		suppliers.append(int(candidate))
	for supplier in range(Catalog.SUPPLIERS.size()):
		var stable_id := Catalog.supplier_id(supplier)
		if relationships.has(stable_id) and supplier not in suppliers:
			suppliers.append(supplier)
	for supplier in suppliers:
		var provider: Dictionary = Catalog.SUPPLIERS[supplier]
		var active_platform := supplier in Catalog.SUPPLIER_SELECTION_INDICES
		var unlocked := Supply.supplier_unlocked(state, supplier)
		var eligibility := SupplierCredit.eligibility(state, supplier)
		var relation: Dictionary = SupplierCredit.relationship(state, supplier)
		var status := ("Available" if unlocked else "Level %d Locked" % int(provider.level)) if active_platform else "Historical"
		var title := "%s · %s" % [str(provider.name), status]
		var card: VBoxContainer = app.card(title)
		card.name = "SupplierRelationship%d" % supplier
		app.metric(card, "Trust · Settled Purchases", "%d / 100 · %d" % [int(relation.trust), int(relation.settled_purchase_count)])
		app.metric(card, "Open Payables", app.money(SupplierCredit.open_payables(state, supplier)))
		if active_platform:
			app.metric(card, "Credit Limit · Available", "%s · %s" % [app.money(int(eligibility.credit_limit)), app.money(int(eligibility.available))])
			if not bool(eligibility.eligible): card.add_child(app.label(str(eligibility.reason), 12, Style.MUTED))
			if not unlocked: card.add_child(app.label("Unlocks at supplier progression level %d." % int(provider.level), 12, Style.MUTED))
		else:
			card.add_child(app.label("Historical relationship. New sourcing is unavailable from this platform; existing balances and records are retained.", 12, Style.MUTED))
	supplier_credit_payables(app)

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
