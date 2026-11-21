extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Calendar = preload("res://game_calendar.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
const Style = preload("res://corporate_theme.gd")

const CATALOG_STAGE_META := "product_catalog_stage"
const SELECTED_SUPPLIER_META := "catalog_selected_supplier"


static func show(app: Control) -> void:
	match str(app.get_meta(CATALOG_STAGE_META, "categories")):
		"categories":
			show_categories(app)
		"products":
			show_products(app)
		"suppliers":
			show_supplier_selection(app)
		"negotiate":
			show_negotiation(app)
		"summary":
			show_purchase_summary(app)
		_:
			app.set_meta(CATALOG_STAGE_META, "categories")
			show_categories(app)

static func _route_key(app: Control, product: int) -> String:
	var company_key := str(app.sim.state.get("company_id", "legacy-company")).replace("-", "_")
	return "catalog_supplier_%s_%d" % [company_key, product]

static func _supplier_for(app: Control, product: int) -> int:
	return int(app.get_meta(_route_key(app, product), -1))

static func _set_supplier(app: Control, product: int, supplier: int) -> void:
	app.set_meta(_route_key(app, product), supplier)
	app.set_meta(SELECTED_SUPPLIER_META, supplier)

static func _refresh_step(app: Control) -> void:
	app.refresh_view(true)

static func _step_header(app: Control, selected: int) -> VBoxContainer:
	var panel: VBoxContainer = app.wide_card("Quick Purchase")
	panel.name = "BuyInventoryWorkflow"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var compact_landscape := app.size.y <= 450.0 and app.size.x > app.size.y
	panel.add_theme_constant_override("separation", 4 if compact_landscape else 8)
	var outer_panel := panel.get_parent() as PanelContainer
	if outer_panel != null:
		outer_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer_panel.add_theme_stylebox_override("panel", Style.box(Color("#101B2E"), Color("#35465D"), 12, 6 if compact_landscape else 12))
	var row := HFlowContainer.new()
	row.name = "BuyInventoryProgress"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 4)
	for index in range(5):
		var names := ["Category", "Product", "Supplier", "Negotiate", "Confirm"]
		var step := Label.new()
		step.name = "BuyStep%d" % index
		step.text = "%d  %s" % [index + 1, str(names[index])]
		step.add_theme_font_size_override("font_size", 10 if compact_landscape else 12)
		step.add_theme_color_override("font_color", Style.GOLD if index == selected else Style.MUTED)
		row.add_child(step)
		if index < 4:
			var separator := Label.new()
			separator.name = "BuyStepSeparator%d" % index
			separator.text = ">"
			separator.add_theme_font_size_override("font_size", 11)
			separator.add_theme_color_override("font_color", Style.MUTED)
			row.add_child(separator)
	panel.add_child(row)
	var content_scroll := ScrollContainer.new()
	content_scroll.name = "BuyInventoryStepScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_scroll.follow_focus = true
	content_scroll.mouse_force_pass_scroll_events = true
	content_scroll.scroll_deadzone = 10
	panel.add_child(content_scroll)
	var content := VBoxContainer.new()
	content.name = "BuyInventoryStepContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content)
	var footer := HBoxContainer.new()
	footer.name = "BuyInventoryNavigationFooter"
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 8)
	panel.add_child(footer)
	app.set_meta("buy_inventory_footer", footer)
	return content

static func _footer_button(app: Control, title: String, callback: Callable, name: String, disabled: bool = false) -> Button:
	var footer := app.get_meta("buy_inventory_footer", null) as HBoxContainer
	if footer == null:
		return null
	var button: Button = app.action(footer, title, callback, title == "Continue" or title == "Confirm Purchase")
	button.name = name
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	if app.size.y <= 450.0 and app.size.x > app.size.y:
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 12)
	button.disabled = disabled
	return button

static func _footer_spacer(app: Control) -> void:
	var footer := app.get_meta("buy_inventory_footer", null) as HBoxContainer
	if footer == null:
		return
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

static func show_categories(app: Control) -> void:
	var workflow := _step_header(app, 0)
	var catalogue: VBoxContainer = _nested_card(workflow, "Select Category")
	catalogue.name = "ProductCataloguePanel"
	catalogue.add_child(app.label("Choose a product category to begin your purchase.", 13, Style.MUTED))
	var grid := GridContainer.new()
	grid.name = "ProductCategoryGrid"
	grid.columns = _category_columns(app.size.x)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	catalogue.add_child(grid)
	for category in Catalog.CATEGORIES:
		var name := str(category)
		var category_product_count := Catalog.PRODUCTS.filter(func(product: Dictionary) -> bool:
			return str(product.get("category", "")) == name
		).size()
		var card := Button.new()
		card.name = "CatalogueCategory_" + _safe_name(name)
		card.text = "%s\n%d products" % [name, category_product_count]
		card.icon = load(_category_icon_path(name)) as Texture2D
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 13 if app.size.x < 600.0 else 14)
		card.add_theme_constant_override("h_separation", 10)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 62)
		card.tooltip_text = "%s · %d products" % [name, category_product_count]
		card.focus_mode = Control.FOCUS_ALL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var selected := int(app.catalog_category) == Catalog.CATEGORIES.find(name)
		var fill := Color("#25364D") if selected else Color("#19283C")
		var outline := Color("#D5AC61") if selected else Color("#35465D")
		card.add_theme_stylebox_override("normal", Style.box(fill, outline, 12, 10))
		card.add_theme_stylebox_override("hover", Style.box(fill.lightened(0.07), Color("#D5AC61"), 12, 10))
		card.add_theme_stylebox_override("pressed", Style.box(Color("#25364D"), Color("#D5AC61"), 12, 10))
		card.add_theme_stylebox_override("focus", Style.box(fill, Color("#D5AC61"), 12, 10))
		card.add_theme_color_override("font_color", Style.TEXT)
		card.add_theme_color_override("font_hover_color", Style.TEXT)
		card.add_theme_color_override("font_pressed_color", Style.TEXT)
		card.add_theme_color_override("font_focus_color", Style.TEXT)
		grid.add_child(card)
		var choose_category := func():
			app.catalog_category = Catalog.CATEGORIES.find(name)
			app.catalog_search = ""
			app.set_meta("buy_selected_product", -1)
			app.refresh_view(true)
		card.pressed.connect(choose_category)
	_footer_spacer(app)
	_footer_button(app, "Continue", func():
		if int(app.catalog_category) not in range(Catalog.CATEGORIES.size()):
			app.set_notice("Select a category to continue.", true)
			return
		app.catalog_search = ""
		app.set_meta(CATALOG_STAGE_META, "products")
		_refresh_step(app)
	, "ContinueBuyInventory", int(app.catalog_category) not in range(Catalog.CATEGORIES.size()))

static func show_products(app: Control) -> void:
	var category_index := int(app.catalog_category)
	if category_index not in range(Catalog.CATEGORIES.size()):
		app.catalog_category = -1
		app.set_meta(CATALOG_STAGE_META, "categories")
		show_categories(app)
		return
	var category := str(Catalog.CATEGORIES[category_index])
	var workflow := _step_header(app, 1)
	var catalogue: VBoxContainer = _nested_card(workflow, category)
	catalogue.name = "CategoryProductsPanel"
	var search: LineEdit = app.field(catalogue, "Search Products", app.catalog_search, 64)
	search.name = "CatalogueProductSearch"
	var product_grid := GridContainer.new()
	product_grid.name = "CategoryProductList"
	product_grid.columns = _product_columns(app.size.x)
	product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_grid.add_theme_constant_override("h_separation", 10)
	product_grid.add_theme_constant_override("v_separation", 10)
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
		app.metric(card, "Available Suppliers", str(suppliers.size()))
		app.metric(card, "Starting Landed Cost", app.money(starting_cost) if starting_cost > 0 else "Unavailable", Style.GOLD)
		var selected_product := product_index
		var selected := int(app.get_meta("buy_selected_product", -1)) == product_index
		var card_panel := card.get_parent() as PanelContainer
		card_panel.add_theme_stylebox_override("panel", Style.box(Color("#25364D") if selected else Color("#19283C"), Color("#D5AC61") if selected else Color("#35465D"), 12, 10))
		var select_product := func():
			app.set_meta("buy_selected_product", selected_product)
			app.refresh_view()
		var choose_product: Button = app.action(card, "Select Product", select_product, selected)
		choose_product.name = "ChooseProduct_%d" % product_index
		card.get_parent().visible = matches
		product_cards.append({"index": product_index, "card": card})
	var empty: Label = app.label("No products match this search. Clear the search or return to Categories.", 14, Style.MUTED)
	empty.name = "ProductCatalogueEmptyState"
	empty.visible = shown == 0
	product_grid.add_child(empty)
	var count_label: Label = app.label("%d products" % shown, 12, Style.MUTED)
	count_label.name = "CategoryProductCount"
	catalogue.add_child(count_label)
	search.text_changed.connect(func(value: String):
		app.catalog_search = value
		var filter := value.strip_edges().to_lower()
		var visible_count := 0
		for entry in product_cards:
			var item: Dictionary = Catalog.PRODUCTS[int(entry.index)]
			var matches := filter.is_empty() or str(item.name).to_lower().contains(filter) or str(item.id).to_lower().contains(filter)
			(entry.card.get_parent() as Control).visible = matches
			if matches: visible_count += 1
		empty.text = "No products match this search. Clear the search or return to Categories." if visible_count == 0 else ""
		empty.visible = visible_count == 0
		count_label.text = "%d products" % visible_count
	)
	_footer_button(app, "Back", func():
		app.set_meta(CATALOG_STAGE_META, "categories")
		_refresh_step(app)
	, "BackFromProducts")
	_footer_spacer(app)
	_footer_button(app, "Continue", func():
		var selected_product := int(app.get_meta("buy_selected_product", -1))
		if selected_product not in range(Catalog.PRODUCTS.size()) or str(Catalog.PRODUCTS[selected_product].category) != category:
			app.set_notice("Select a product to continue.", true)
			return
		app.selected_product = selected_product
		app.set_meta(CATALOG_STAGE_META, "suppliers")
		_refresh_step(app)
	, "ContinueBuyInventory", int(app.get_meta("buy_selected_product", -1)) not in range(Catalog.PRODUCTS.size()))

static func show_supplier_workflow(app: Control) -> void:
	app.set_meta(CATALOG_STAGE_META, "suppliers")
	show_supplier_selection(app)

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

static func _category_columns(viewport_width: float) -> int:
	# Categories remain two-up on narrow phones where the compact card fits.
	return 3 if viewport_width >= 900.0 else (2 if viewport_width >= 340.0 else 1)

static func _product_columns(viewport_width: float) -> int:
	return 3 if viewport_width >= 900.0 else (2 if viewport_width >= 600.0 else 1)

static func _supplier_columns(viewport_width: float) -> int:
	return 3 if viewport_width >= 900.0 else (2 if viewport_width >= 600.0 else 1)

static func _supplier_card_width(viewport_width: float) -> float:
	# Account for the outer page shell, card padding and flow spacing before
	# assigning a minimum width. Shrink-begin cards then retain natural heights.
	var page_width := minf(1100.0, maxf(280.0, viewport_width - (40.0 if viewport_width >= 900.0 else 24.0)))
	var inner_width := maxf(220.0, page_width - 64.0)
	var columns := _supplier_columns(viewport_width)
	return floorf((inner_width - 10.0 * float(columns - 1)) / float(columns))

static func _category_icon_path(category: String) -> String:
	var icons := {
		"Electronics": "electronics", "Home & Living": "home_living", "Kitchen": "kitchen", "Fashion": "fashion",
		"Beauty": "beauty", "Fitness": "fitness", "Automotive": "automotive", "Baby & Kids": "baby_kids",
		"Pets": "pets", "Travel": "travel",
	}
	return "res://assets/categories/%s.svg" % str(icons.get(category, "general"))

static func _nested_card(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Color("#19283C"), Color("#35465D"), 12, 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	content.add_child(heading)
	return content

static func update_responsive_layout(app: Control) -> void:
	var viewport_width := app.size.x
	var category_grid := app.find_child("ProductCategoryGrid", true, false) as GridContainer
	if category_grid != null:
		category_grid.columns = _category_columns(viewport_width)
	var product_grid := app.find_child("CategoryProductList", true, false) as GridContainer
	if product_grid != null:
		product_grid.columns = _product_columns(viewport_width)
	var supplier_list := app.find_child("CompactSupplierList", true, false) as GridContainer
	if supplier_list != null:
		supplier_list.columns = _supplier_columns(viewport_width)
		for child in supplier_list.get_children():
			var card := child as PanelContainer
			if card == null:
				continue
			card.custom_minimum_size.x = 0
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func _catalog_card(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "CatalogueCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Color("#19283C"), Color("#35465D"), 12, 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	content.add_child(heading)
	return content

static func show_supplier_selection(app: Control) -> void:
	var product := int(app.selected_product)
	if product not in range(Catalog.PRODUCTS.size()):
		app.set_meta(CATALOG_STAGE_META, "categories")
		show_categories(app)
		return
	var state: Dictionary = app.sim.state
	SupplierCredit.ensure(state)
	var workflow := _step_header(app, 2)
	var panel: VBoxContainer = _nested_card(workflow, "Choose Supplier · " + str(Catalog.PRODUCTS[product].name))
	panel.name = "SupplierSelectionStep"
	panel.add_child(app.label("Compare available suppliers for this product.", 13, Style.MUTED))
	var list := GridContainer.new()
	list.name = "CompactSupplierList"
	list.columns = _supplier_columns(app.size.x)
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 8)
	panel.add_child(list)
	var selected := _supplier_for(app, product)
	for supplier_variant in _available_suppliers(state, product):
		var supplier := int(supplier_variant)
		var provider: Dictionary = Catalog.SUPPLIERS[supplier]
		var goods := Catalog.quote(state.country, product, supplier)
		var freight := Catalog.inbound_freight(state.country, supplier)
		var card: VBoxContainer = _catalog_card(list, str(provider.name))
		card.name = "SupplierChoice%d" % supplier
		var selected_now := selected == supplier
		var card_panel := card.get_parent() as PanelContainer
		card_panel.name = "SupplierChoicePanel%d" % supplier
		card_panel.custom_minimum_size.x = _supplier_card_width(app.size.x)
		card_panel.add_theme_stylebox_override("panel", Style.box(Color("#25364D") if selected_now else Color("#19283C"), Color("#D5AC61") if selected_now else Color("#35465D"), 12, 10))
		app.metric(card, "Unit Price", app.money(goods), Style.GOLD)
		app.metric(card, "Quality · MOQ", "%d%% · %s" % [roundi(float(provider.quality) * 100.0), _format_quantity(int(provider.minimum))])
		var relation := SupplierCredit.relationship(state, supplier)
		app.metric(card, "Trust · Reliability", "%d / 100 · %d%%" % [int(relation.trust), roundi(float(provider.reliability) * 100.0)])
		app.metric(card, "Estimated Arrival", Calendar.format(int(state.day) + int(provider.lead)))
		app.metric(card, "Landed Cost / Unit", app.money(goods + freight))
		var choose: Button = app.action(card, "Select Supplier", func():
			_set_supplier(app, product, supplier)
			app.refresh_view()
		, selected_now)
		choose.name = "SelectSupplier%d" % supplier
	if _available_suppliers(state, product).is_empty():
		panel.add_child(app.label("No supplier platforms are currently unlocked for new purchases.", 13, Style.MUTED))
	_footer_button(app, "Back", func():
		app.set_meta(CATALOG_STAGE_META, "products")
		_refresh_step(app)
	, "BackFromSuppliers")
	_footer_spacer(app)
	_footer_button(app, "Continue", func():
		var supplier := _supplier_for(app, product)
		if supplier not in _available_suppliers(state, product):
			app.set_notice("Select an available supplier to continue.", true)
			return
		app.set_meta(CATALOG_STAGE_META, "negotiate")
		_refresh_step(app)
	, "ContinueBuyInventory", selected not in _available_suppliers(state, product))

static func show_negotiation(app: Control) -> void:
	var product := int(app.selected_product)
	var supplier := _supplier_for(app, product)
	if product not in range(Catalog.PRODUCTS.size()) or supplier not in range(Catalog.SUPPLIERS.size()):
		app.set_meta(CATALOG_STAGE_META, "suppliers")
		show_supplier_selection(app)
		return
	var state: Dictionary = app.sim.state
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	var route_key := _route_key(app, product)
	var workflow := _step_header(app, 3)
	var panel: VBoxContainer = _nested_card(workflow, "Negotiate Price · " + str(provider.name))
	panel.name = "SupplierNegotiationStep"
	var asking := Catalog.quote(state.country, product, supplier)
	var relation := SupplierCredit.relationship(state, supplier)
	var selected_request := int(app.get_meta("buy_discount_request_%d_%d" % [product, supplier], 0))
	app.metric(panel, "Supplier Asking Price", app.money(asking), Style.GOLD)
	app.metric(panel, "Supplier Trust", "%d / 100" % int(relation.trust))
	var discount := OptionButton.new()
	discount.name = "RequestedDiscount"
	for percent in [0, 5, 10, 15]: discount.add_item("%d%%" % int(percent))
	discount.select([0, 5, 10, 15].find(selected_request) if selected_request in [0, 5, 10, 15] else 0)
	panel.add_child(app.label("Requested Discount", 12, Style.MUTED))
	panel.add_child(discount)
	var result_label: Label = app.label(str(app.get_meta("buy_negotiation_result_%d_%d" % [product, supplier], "Choose a requested discount and request an offer.")), 13, Style.MUTED)
	result_label.name = "NegotiationResult"
	panel.add_child(result_label)
	var accept_button: Button = app.action(panel, "Accept Offer", func():
		if not bool(app.get_meta("buy_negotiation_ready_%d_%d" % [product, supplier], false)):
			return
		app.set_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], true)
		app.set_notice("Supplier terms accepted. Continue to purchase quantity.")
		app.refresh_view()
	, true)
	accept_button.name = "AcceptNegotiatedOffer"
	var accepted := bool(app.get_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], false))
	accept_button.visible = bool(app.get_meta("buy_negotiation_ready_%d_%d" % [product, supplier], false))
	accept_button.disabled = accepted
	if accepted:
		result_label.text += "\nOffer accepted."
		result_label.add_theme_color_override("font_color", Style.GREEN)
	var request_button: Button = app.action(panel, "Request Offer", func():
		var requested := int([0, 5, 10, 15][discount.selected])
		app.set_meta("buy_discount_request_%d_%d" % [product, supplier], requested)
		app.set_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], false)
		app.set_meta("buy_negotiation_ready_%d_%d" % [product, supplier], false)
		if requested == 0:
			var current_terms := Supply.quote(state, product, supplier)
			if int(current_terms.get("discount", 0)) > 0 and int(current_terms.get("expires", 0)) >= int(state.day):
				app.set_meta("buy_negotiation_ready_%d_%d" % [product, supplier], true)
				app.set_meta("buy_negotiation_result_%d_%d" % [product, supplier], "Existing firm supplier offer: %s per unit, valid through %s." % [app.money(int(current_terms.cost)), Calendar.format(int(current_terms.expires))])
				app.refresh_view()
				return
			app.set_meta("buy_negotiation_ready_%d_%d" % [product, supplier], true)
			app.set_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], true)
			app.set_meta("buy_negotiation_result_%d_%d" % [product, supplier], "No discount requested. Negotiated unit price remains the supplier asking price: %s." % app.money(asking))
			app.refresh_view()
			return
		var existing_offer := Supply.quote(state, product, supplier)
		if int(existing_offer.get("discount", 0)) > 0 and int(existing_offer.get("expires", 0)) >= int(state.day):
			app.set_meta("buy_negotiation_ready_%d_%d" % [product, supplier], true)
			app.set_meta("buy_negotiation_result_%d_%d" % [product, supplier], "Existing firm supplier offer: %s per unit, valid through %s." % [app.money(int(existing_offer.cost)), Calendar.format(int(existing_offer.expires))])
			app.refresh_view()
			return
		var negotiation_error := Supply.negotiate(state, product, supplier, Supply.negotiation_minimum(supplier))
		if not negotiation_error.is_empty():
			app.set_meta("buy_negotiation_result_%d_%d" % [product, supplier], "Offer rejected: %s. Negotiated unit price remains %s." % [negotiation_error, app.money(asking)])
			app.set_notice(negotiation_error, true)
			app.refresh_view()
			return
		var quote := Supply.quote(state, product, supplier)
		var actual_discount := int(quote.get("discount", 0))
		var response := "Offer received: requested %d%%; existing supplier terms returned %d%% at %s per unit. Review and accept the actual price." % [requested, actual_discount, app.money(int(quote.get("cost", asking)))]
		app.set_meta("buy_negotiation_ready_%d_%d" % [product, supplier], true)
		app.set_meta("buy_negotiation_result_%d_%d" % [product, supplier], response)
		app.persist("Supplier offer received. Review and accept the actual supplier terms to continue.")
		app.refresh_view()
	)
	request_button.name = "RequestSupplierOffer"
	discount.item_selected.connect(func(index: int):
		var requested := int([0, 5, 10, 15][index])
		app.set_meta("buy_discount_request_%d_%d" % [product, supplier], requested)
		app.set_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], false)
		app.set_meta("buy_negotiation_ready_%d_%d" % [product, supplier], false)
		app.remove_meta("buy_negotiation_result_%d_%d" % [product, supplier])
		result_label.text = "Request changed. Submit a new request to see the supplier response."
		result_label.add_theme_color_override("font_color", Style.MUTED)
		accept_button.visible = false
		app.set_meta("buy_purchase_quotation", {})
	)
	var active_quote := Supply.quote(state, product, supplier)
	if int(active_quote.get("discount", 0)) > 0 and int(active_quote.get("expires", 0)) >= int(state.day) and not bool(app.get_meta("buy_negotiation_ready_%d_%d" % [product, supplier], false)):
		result_label.text = "Existing firm supplier offer: %s per unit, valid through %s. Submit the request to review it." % [app.money(int(active_quote.cost)), Calendar.format(int(active_quote.expires))]
	_footer_button(app, "Back", func():
		app.set_meta(CATALOG_STAGE_META, "suppliers")
		_refresh_step(app)
	, "BackToSuppliers")
	_footer_spacer(app)
	_footer_button(app, "Continue", func():
		if not bool(app.get_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], false)):
			app.set_notice("Accept the current supplier terms before continuing.", true)
			return
		app.set_meta(CATALOG_STAGE_META, "summary")
		_refresh_step(app)
	, "ContinueBuyInventory", not bool(app.get_meta("buy_negotiation_accepted_%d_%d" % [product, supplier], false)))

static func show_purchase_summary(app: Control) -> void:
	var product := int(app.selected_product)
	var supplier := _supplier_for(app, product)
	if product not in range(Catalog.PRODUCTS.size()) or supplier not in range(Catalog.SUPPLIERS.size()):
		app.set_meta(CATALOG_STAGE_META, "suppliers")
		show_supplier_selection(app)
		return
	var state: Dictionary = app.sim.state
	var provider: Dictionary = Catalog.SUPPLIERS[supplier]
	var key := "buy_quantity_%d_%d" % [product, supplier]
	var step_key := "buy_quantity_step_%d_%d" % [product, supplier]
	var quantity := int(app.get_meta(key, int(provider.minimum)))
	var increment := int(app.get_meta(step_key, 10))
	if increment not in [10, 100, 1000]: increment = 10
	quantity = clampi(quantity, int(provider.minimum), Supply.maximum_order_quantity(supplier))
	app.set_meta(key, quantity)
	app.set_meta(step_key, increment)
	var workflow := _step_header(app, 4)
	var panel: VBoxContainer = _nested_card(workflow, "Quantity & Purchase Summary")
	panel.name = "PurchaseSummaryStep"
	var quantity_row := HBoxContainer.new()
	quantity_row.name = "PurchaseQuantityControls"
	quantity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quantity_row.add_theme_constant_override("separation", 8)
	panel.add_child(app.label("Order Quantity", 12, Style.MUTED))
	panel.add_child(quantity_row)
	var current_quantity := Label.new()
	current_quantity.name = "SupplierPurchaseQuantity"
	current_quantity.text = _format_quantity(quantity)
	current_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_quantity.add_theme_font_size_override("font_size", 21)
	current_quantity.add_theme_color_override("font_color", Color("#E6C37B"))
	current_quantity.custom_minimum_size = Vector2(96, 40)
	var minus: Button = app.action(quantity_row, "−", func():
		_set_purchase_quantity(app, product, supplier, quantity - increment)
		app.refresh_view()
	)
	minus.name = "PurchaseQuantityMinus"
	var quantity_field := PanelContainer.new()
	quantity_field.add_theme_stylebox_override("panel", Style.box(Color("#101B2E"), Color("#35465D"), 8, 6))
	quantity_field.add_child(current_quantity)
	quantity_row.add_child(quantity_field)
	var plus: Button = app.action(quantity_row, "+", func():
		_set_purchase_quantity(app, product, supplier, quantity + increment)
		app.refresh_view()
	, true)
	plus.name = "PurchaseQuantityPlus"
	minus.disabled = quantity <= int(provider.minimum)
	plus.disabled = quantity >= Supply.maximum_order_quantity(supplier)
	var increments := HBoxContainer.new()
	increments.name = "QuantityIncrements"
	increments.alignment = BoxContainer.ALIGNMENT_CENTER
	increments.add_theme_constant_override("separation", 4)
	panel.add_child(app.label("Quantity Increment", 12, Style.MUTED))
	panel.add_child(increments)
	for value in [10, 100, 1000]:
		var amount := int(value)
		var option: Button = app.action(increments, "×%s" % _format_quantity(amount), func():
			app.set_meta(step_key, amount)
			app.refresh_view()
		, amount == increment)
		option.name = "QuantityIncrement%d" % amount
	var payment_key := "buy_payment_%d_%d" % [product, supplier]
	var payment: OptionButton = app.dropdown(panel, ["Pay Upfront", "Supplier Credit"], int(app.get_meta(payment_key, 0)))
	payment.name = "PurchasePaymentMethod"
	var eligibility := SupplierCredit.eligibility(state, supplier)
	payment.set_item_disabled(1, not bool(eligibility.eligible))
	if not bool(eligibility.eligible): payment.set_item_text(1, "Supplier Credit · Unavailable")
	var max_row := HBoxContainer.new()
	max_row.name = "BuyMaxControls"
	panel.add_child(max_row)
	app.metric(max_row, "Available Bank Balance", app.money(int(state.cash)))
	var max_button: Button = app.action(max_row, "Buy Max", func():
		var active_offer := Supply.quote(state, product, supplier)
		var freight := Catalog.inbound_freight(state.country, supplier)
		var offered_minimum := int(active_offer.get("minimum", 0))
		var goods := int(active_offer.get("cost", Catalog.quote(state.country, product, supplier)))
		var maximum_units := mini(Supply.maximum_order_quantity(supplier), int(state.cash) / maxi(1, goods + freight))
		if maximum_units < offered_minimum:
			goods = Catalog.quote(state.country, product, supplier)
			maximum_units = mini(Supply.maximum_order_quantity(supplier), int(state.cash) / maxi(1, goods + freight))
		if maximum_units < int(provider.minimum):
			app.set_notice("Current bank balance cannot cover the supplier minimum order.", true)
			return
		_set_purchase_quantity(app, product, supplier, maximum_units)
		app.refresh_view()
	, true)
	max_button.name = "BuyMaximumUnits"
	max_button.custom_minimum_size.y = 40
	var breakdown := Supply.purchase_breakdown(state, product, supplier, quantity)
	var quote_panel: VBoxContainer = _nested_card(panel, "Purchase Summary")
	quote_panel.name = "GeneratedPurchaseQuotation"
	var goods_unit := int(breakdown.get("goods_unit_cost", Catalog.quote(state.country, product, supplier)))
	var freight_unit := int(breakdown.get("freight_unit_cost", Catalog.inbound_freight(state.country, supplier)))
	var goods_total := goods_unit * quantity
	var freight_total := freight_unit * quantity
	var purchase_total := int(breakdown.get("total", goods_total + freight_total))
	var arrival_day := int(state.day) + int(provider.lead)
	app.metric(quote_panel, "Product", str(Catalog.PRODUCTS[product].name))
	app.metric(quote_panel, "Supplier", str(provider.name))
	app.metric(quote_panel, "Unit Cost × Quantity", "%s × %s" % [app.money(goods_unit), _format_quantity(quantity)])
	app.metric(quote_panel, "Goods Subtotal", app.money(goods_total))
	app.metric(quote_panel, "Inbound Freight", app.money(freight_total))
	app.metric(quote_panel, "Total Purchase", app.money(purchase_total), Style.GOLD)
	app.metric(quote_panel, "Landed Cost Per Unit", app.money(goods_unit + freight_unit))
	app.metric(quote_panel, "Estimated Arrival Date", Calendar.format(arrival_day))
	var reliability := roundi(float(provider.reliability) * 100.0)
	var possible_delay := "No delay expected · %d%% reliability" % reliability if reliability >= 100 else "%s · up to 3 days · %d%% reliability" % [Calendar.format(arrival_day + 3), reliability]
	app.metric(quote_panel, "Possible Delay (Supplier Reliability)", possible_delay)
	var error := str(breakdown.get("error", ""))
	if not error.is_empty(): quote_panel.add_child(app.label(error, 12, Style.RED))
	var funds_available := int(state.cash) >= purchase_total if payment.selected == 0 else (bool(eligibility.eligible) and int(eligibility.available) >= purchase_total)
	_footer_button(app, "Back", func():
		app.set_meta(CATALOG_STAGE_META, "negotiate")
		app.refresh_view()
	, "BackFromPurchaseSummary")
	_footer_spacer(app)
	_footer_button(app, "Confirm Purchase", func():
		if bool(app.get_meta("supplier_purchase_processing", false)): return
		var latest := Supply.purchase_breakdown(state, product, supplier, quantity)
		if not str(latest.get("error", "")).is_empty():
			app.set_notice(str(latest.error), true)
			return
		var latest_eligibility := SupplierCredit.eligibility(state, supplier)
		if payment.selected == 0 and int(latest.total) > int(state.cash):
			app.set_notice("Insufficient company cash for this purchase.", true)
			return
		if payment.selected == 1 and (not bool(latest_eligibility.eligible) or int(latest.total) > int(latest_eligibility.available)):
			app.set_notice("The purchase exceeds available supplier credit.", true)
			return
		var confirm_message := "%s · %s · %s units\nTotal %s · Estimated arrival %s\nThe supplier order will be recorded once." % [
			str(Catalog.PRODUCTS[product].name), str(provider.name), _format_quantity(quantity), app.money(int(latest.total)), Calendar.format(arrival_day)]
		app.confirm_action("Confirm Purchase", confirm_message, "Place Order", func():
			if bool(app.get_meta("supplier_purchase_processing", false)): return
			app.set_meta("supplier_purchase_processing", true)
			var purchase_id := -1
			var purchase_error := ""
			if payment.selected == 1:
				var result := SupplierCredit.purchase_on_credit(state, product, supplier, quantity)
				purchase_error = str(result.get("error", ""))
				if purchase_error.is_empty(): purchase_id = int(result.get("obligation", {}).get("purchase_id", -1))
			else:
				purchase_error = str(app.sim.buy(product, supplier, quantity))
				if purchase_error.is_empty(): purchase_id = int(state.next_purchase) - 1
			if not purchase_error.is_empty():
				app.set_meta("supplier_purchase_processing", false)
				app.set_notice(purchase_error, true)
				app.refresh_view()
				return
			var shipment: Dictionary = {}
			for batch in state.inbound:
				if int(batch.get("id", -1)) == purchase_id: shipment = batch; break
			app.set_meta("catalog_purchase_receipt", {"product": product, "supplier": supplier, "product_name": Catalog.PRODUCTS[product].name,
				"supplier_name": provider.name, "units": quantity, "payment": "Supplier Credit" if payment.selected == 1 else "Pay Upfront",
				"total": int(latest.total), "purchase_id": purchase_id, "eta": int(shipment.get("eta", arrival_day)),
				"arrival": int(shipment.get("arrival", arrival_day)), "status": "In Transit"})
			app.set_meta("focused_inbound_purchase_id", purchase_id)
			app.set_meta(CATALOG_STAGE_META, "categories")
			app.set_meta("supplier_purchase_processing", false)
			app.page = "Inbound Stock"
			app.category_last_page["Market"] = "Inbound Stock"
			app.persist("Purchase order placed. The new shipment is open in Inbound Stock.")
			app.refresh_view(true)
		)
	, "ConfirmPurchaseOrder", not error.is_empty() or not funds_available or quantity < int(provider.minimum))
	payment.item_selected.connect(func(index: int):
		app.set_meta(payment_key, index)
		app.refresh_view()
	)
	var buymax := max_button
	buymax.disabled = int(state.cash) < (goods_unit + freight_unit) * int(provider.minimum)

static func _set_purchase_quantity(app: Control, product: int, supplier: int, value: int) -> void:
	var minimum := int(Catalog.SUPPLIERS[supplier].minimum)
	var maximum := Supply.maximum_order_quantity(supplier)
	app.set_meta("buy_quantity_%d_%d" % [product, supplier], clampi(value, minimum, maximum))

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
	var focused_id := int(app.get_meta("focused_inbound_purchase_id", -1))
	if focused_id >= 0:
		var receipt: Dictionary = app.get_meta("catalog_purchase_receipt", {})
		var focused_batch: Dictionary = {}
		for batch in state.get("inbound", []):
			if int(batch.get("id", -1)) == focused_id: focused_batch = batch; break
		var received_lot: Dictionary = {}
		if focused_batch.is_empty():
			for item in state.get("products", {}).values():
				for lot in item.get("lots", []):
					if int(lot.get("purchase_id", -1)) == focused_id: received_lot = lot; break
		var product_id := int(receipt.get("product", focused_batch.get("product", -1)))
		var supplier_id := int(receipt.get("supplier", focused_batch.get("supplier", -1)))
		var product_name := str(receipt.get("product_name", Catalog.PRODUCTS[product_id].name if product_id in range(Catalog.PRODUCTS.size()) else "Product"))
		var supplier_name := str(receipt.get("supplier_name", focused_batch.get("supplier_name", Catalog.SUPPLIERS[supplier_id].name if supplier_id in range(Catalog.SUPPLIERS.size()) else "Supplier")))
		var shipment_status := "Received" if not received_lot.is_empty() else ("Delayed" if bool(focused_batch.get("delayed", false)) else ("In Transit" if not focused_batch.is_empty() else str(receipt.get("status", "Ordered"))))
		var shipment_rank := 0 if shipment_status == "Ordered" else (2 if shipment_status == "Received" else 1)
		var shipment: VBoxContainer = _nested_card(view, "Purchase Confirmed")
		shipment.name = "FocusedInboundPurchase%d" % focused_id
		shipment.add_child(app.label("Inventory is on its way to your warehouse." if shipment_status in ["Ordered", "In Transit", "Delayed"] else "The shipment has been received into company inventory.", 13, Style.MUTED))
		var eta := int(focused_batch.get("eta", receipt.get("eta", state.day)))
		var arrival := int(focused_batch.get("arrival", receipt.get("arrival", eta)))
		var supplier_reliability := float(Catalog.SUPPLIERS[supplier_id].reliability) if supplier_id in range(Catalog.SUPPLIERS.size()) else 1.0
		app.metric(shipment, "Shipment ID", "PO-%04d" % focused_id)
		app.metric(shipment, "Product", product_name)
		app.metric(shipment, "Supplier", supplier_name)
		app.metric(shipment, "Incoming Quantity", _format_quantity(int(receipt.get("units", focused_batch.get("units", received_lot.get("units", 0))))))
		app.metric(shipment, "Estimated Arrival Date", Calendar.format(eta))
		app.metric(shipment, "Possible Delay", Calendar.format(arrival) if arrival > eta else "No delay currently forecast · %d%% reliability" % roundi(supplier_reliability * 100.0))
		app.metric(shipment, "Purchase Total", app.money(int(receipt.get("total", 0))), Style.GOLD)
		app.metric(shipment, "Shipment Status", shipment_status, Style.GREEN if shipment_status == "Received" else Style.GOLD)
		var progress := HBoxContainer.new()
		progress.name = "ShipmentProgress"
		progress.add_theme_constant_override("separation", 4)
		for step_index in range(3):
			var status: String = ["Ordered", "In Transit", "Received"][step_index]
			var step_color: Color = Style.GOLD if step_index == shipment_rank else (Style.GREEN if step_index < shipment_rank else Style.MUTED)
			var label: Label = app.label(status, 12, step_color)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			progress.add_child(label)
		shipment.add_child(progress)
		app.action(shipment, "New Inventory Purchase", func():
			app.remove_meta("focused_inbound_purchase_id")
			app.remove_meta("catalog_purchase_receipt")
			app.set_meta(CATALOG_STAGE_META, "categories")
			app.catalog_category = -1
			app.page = "Market"
			app.category_last_page["Market"] = "Market"
			_refresh_step(app)
		, true)
	if state.get("inbound", []).is_empty():
		if focused_id < 0: view.add_child(app.label("No inbound stock orders are currently in transit.", 14, Style.MUTED))
		return
	var batches: Array = state.inbound.duplicate(true)
	batches.sort_custom(func(a: Dictionary, b: Dictionary):
		var day_a: int = int(a.get("arrival", a.get("eta", state.day)))
		var day_b: int = int(b.get("arrival", b.get("eta", state.day)))
		return day_a < day_b
	)
	for batch in batches:
		if int(batch.get("id", -1)) == focused_id: continue
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

static func _parse_money_cents(value: String) -> int:
	var cleaned := value.strip_edges().replace(",", "").replace(" ", "")
	if cleaned.is_empty() or not cleaned.is_valid_float():
		return -1
	return roundi(cleaned.to_float() * 100.0)

static func _format_quantity(value: int) -> String:
	var text := str(value)
	var result := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0: result += ","
		result += text[i]
	return result
