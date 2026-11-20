extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Market = preload("res://market_view.gd")

var app: Control
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func controls(node: Node, type: String) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child.is_class(type): result.append(child)
		result.append_array(controls(child, type))
	return result

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func button(title: String, scope: Node = null) -> Button:
	for candidate in controls(app if scope == null else scope, "Button"):
		if candidate.text.to_lower() == title.to_lower() and candidate.is_visible_in_tree(): return candidate
	return null

func click(title: String, scope: Node = null) -> void:
	var node := button(title, scope)
	if node != null: node.pressed.emit()

func settle_frames() -> void:
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	root.add_child(app)
	await settle_frames()
	app.sim = Sim.new(Sim.register("Catalog CEO", "Catalog Test Co", "Catalog", 0, 0, 1, 811))
	app.screen = "Game"
	app.page = "Market"
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.render()
	await settle_frames()
	expect(Market._category_columns(1280.0) == 3 and Market._category_columns(768.0) == 2
		and Market._category_columns(390.0) == 2, "Category cards use three, two and compact mobile two-column layouts")
	expect(Market._product_columns(1280.0) == 3 and Market._product_columns(768.0) == 2
		and Market._product_columns(390.0) == 1, "Product cards use three, two and one responsive columns")
	expect(Market._supplier_columns(1280.0) == 3 and Market._supplier_columns(768.0) == 2
		and Market._supplier_columns(390.0) == 1, "Supplier comparison uses three, two and one responsive columns")
	expect(app.find_child("CatalogueCategory_Electronics", true, false) != null
		and app.find_child("CatalogueCategory_Kitchen", true, false) != null,
		"Product Catalogue starts with selectable game categories")
	click("Browse", app.find_child("CatalogueCategory_Kitchen", true, false))
	await settle_frames()
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "products"
		and app.catalog_category == Catalog.CATEGORIES.find("Kitchen"),
		"Selecting a category opens the matching product list")
	var search := app.find_child("CatalogueProductSearch", true, false) as LineEdit
	var first_card := app.find_child("CatalogueProduct_0", true, false) as Control
	expect(first_card != null and first_card.is_visible_in_tree()
		and has_label("Starting Landed Cost") and has_label("Available Suppliers"),
		"Product cards display unlocked supplier count and starting landed cost")
	if search != null:
		search.text = "no-such-product"
		search.text_changed.emit(search.text)
		expect(first_card != null and not first_card.is_visible_in_tree()
			and has_label("No products match this search. Clear the search or return to Categories."),
			"Catalogue search filters product cards in place and preserves the input field")
		search.text = "Portable Blender"
		search.text_changed.emit(search.text)
	click("Choose Product", first_card)
	await settle_frames()
	expect(app.selected_product == 0 and str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "suppliers"
		and app.find_child("CompactSupplierList", true, false) != null,
		"Choosing a product opens its compact supplier selection stage")
	var flow := app.find_child("CompactSupplierList", true, false) as HFlowContainer
	var supplier := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_card := app.find_child("SupplierChoice%d" % supplier, true, false)
	expect(supplier_card != null and button("View Details", supplier_card) != null,
		"Collapsed supplier summary exposes its expansion control")
	expect(button("Select Supplier", supplier_card) == null,
		"Collapsed supplier cards keep selection inside the expanded details state")
	click("View Details", supplier_card)
	await settle_frames()
	supplier_card = app.find_child("SupplierChoice%d" % supplier, true, false)
	expect(supplier_card != null and button("Select Supplier", supplier_card) != null,
		"Expanded supplier card exposes selection with quality, reliability, MOQ, lead time, and landed cost")
	var expanded_panel := app.find_child("SupplierChoicePanel%d" % supplier, true, false) as PanelContainer
	var other_supplier := int(Catalog.SUPPLIER_SELECTION_INDICES[1])
	var collapsed_panel := app.find_child("SupplierChoicePanel%d" % other_supplier, true, false) as PanelContainer
	expect(expanded_panel != null and collapsed_panel != null
		and expanded_panel.size_flags_vertical == Control.SIZE_SHRINK_BEGIN
		and collapsed_panel.size_flags_vertical == Control.SIZE_SHRINK_BEGIN
		and collapsed_panel.size.y < expanded_panel.size.y,
		"Opening a supplier expands only its own natural-height card")
	flow = app.find_child("CompactSupplierList", true, false) as HFlowContainer
	expect(flow != null and expanded_panel.position.x >= 0.0 and expanded_panel.position.x + expanded_panel.size.x <= flow.size.x + 1.0,
		"Supplier card stays inside its parent flow without horizontal overflow")
	click("View Details", supplier_card)
	await settle_frames()
	click("View Details", app.find_child("SupplierChoice%d" % other_supplier, true, false))
	await settle_frames()
	expect(button("View Details", app.find_child("SupplierChoice%d" % supplier, true, false)) != null
		and button("Hide Details", app.find_child("SupplierChoice%d" % other_supplier, true, false)) != null,
		"Expanding another supplier collapses the previously expanded card")
	click("View Details", app.find_child("SupplierChoice%d" % supplier, true, false))
	await settle_frames()
	supplier_card = app.find_child("SupplierChoice%d" % supplier, true, false)
	click("Select Supplier", supplier_card)
	await settle_frames()
	var details := app.find_child("SelectedSupplierDetails", true, false)
	expect(details != null and button("Submit Offer", details) != null and button("Accept Offer", details) != null
		and button("View Quotation", details) != null and button("Generate Quotation", details) != null and button("Confirm Purchase", details) != null,
		"Supplier details provide negotiation, acceptance, quotation, and confirmation actions")
	expect(app.find_child("SupplierProposedUnitPrice", true, false) != null,
		"Negotiation offers expose a currency amount target while keeping supplier terms system-driven")
	var quantity := app.find_child("SupplierPurchaseQuantity", true, false) as LineEdit
	expect(quantity != null, "Purchase quantity is shown in supplier details")
	var proposed := app.find_child("SupplierProposedUnitPrice", true, false) as LineEdit
	if proposed != null:
		proposed.text = "-1"
		click("Submit Offer", details)
		expect((app.find_child("SupplierNegotiationResponse", true, false) as Label).text.contains("positive target"),
			"Invalid or negative target prices are rejected")
		proposed.text = app.amount_text(roundi(Catalog.quote(app.sim.state.country, 0, supplier) * 0.9), true)
	if quantity != null:
		quantity.text = "1"
		quantity.text_changed.emit(quantity.text)
		click("Submit Offer", details)
		var rejected_response := app.find_child("SupplierNegotiationResponse", true, false) as Label
		expect(rejected_response != null and rejected_response.text.contains("negotiates orders"),
			"Supplier negotiation rejects quantities below the existing order threshold")
		quantity.text = str(Supply.negotiation_minimum(supplier))
		quantity.text_changed.emit(quantity.text)
	click("Submit Offer", details)
	await settle_frames()
	var terms := Supply.quote(app.sim.state, 0, supplier)
	expect(int(terms.get("discount", 0)) > 0, "Negotiate uses the existing supplier response mechanics")
	var response := app.find_child("SupplierNegotiationResponse", true, false) as Label
	expect(response != null and response.text.contains("Supplier counteroffer") and response.text.contains("not agreed"),
		"Actual supplier counteroffer remains separate from an accepted agreement")
	details = app.find_child("SelectedSupplierDetails", true, false)
	click("View Quotation", details)
	await settle_frames()
	var preview := app.find_child("GeneratedPurchaseQuotation", true, false)
	expect(preview != null and has_label("Estimate") and not has_label("current quotation"),
		"View Quotation displays the calculated current estimate without creating a purchase order")
	click("Accept Offer")
	await settle_frames()
	click("Generate Quotation")
	await settle_frames()
	var quotation := app.find_child("GeneratedPurchaseQuotation", true, false)
	expect(quotation != null and has_label("Goods") and has_label("Freight") and has_label("Total"),
		"Generated quotation summarizes the real goods, freight, and landed purchase cost")
	var confirm := button("Confirm Purchase")
	expect(confirm != null and not confirm.disabled, "A valid accepted quotation enables purchase confirmation")
	if confirm != null:
		confirm.pressed.emit()
		confirm.pressed.emit()
		await settle_frames()
	expect(is_instance_valid(app.confirmation) and app.sim.state.inbound.is_empty(),
		"Purchase confirmation prevents both an immediate order and duplicate confirmation dialogs")
	if is_instance_valid(app.confirmation):
		app.confirmation.confirmed.emit()
		await settle_frames()
	expect(app.sim.state.inbound.size() == 1 and app.find_child("SupplierPurchaseConfirmation", true, false) != null,
		"Confirmed quotation creates exactly one real inbound supplier order and a purchase receipt")
	Market.inbound_stock(app)
	expect(app.find_child("InboundStockPage", true, false) != null and app.find_child("InboundPurchase%d" % int(app.sim.state.inbound[0].id), true, false) != null,
		"Inbound Stock route lists the real purchase order and delivery estimate")
	Market.supplier_returns_page(app)
	expect(app.find_child("SupplierReturnsPage", true, false) != null and app.find_child("SupplierReturnHistory", true, false) != null,
		"Supplier Returns combines return actions and historical records on one page")
	Market.supplier_relationships(app)
	expect(app.find_child("SupplierRelationshipsPage", true, false) != null and app.find_child("SupplierRelationship%d" % supplier, true, false) != null,
		"Supplier Relationships displays actual trust and credit account state")
	root.size = Vector2i(390, 844)
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.catalog_category = -1
	app.render()
	await settle_frames()
	var mobile_grid := app.find_child("ProductCategoryGrid", true, false) as GridContainer
	expect(mobile_grid != null and mobile_grid.columns == 2,
		"Category catalogue uses compact two-column cards on mobile portrait")
	app.queue_free()
	await process_frame
	print("Category-first product flow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func has_label(text: String) -> bool:
	return controls(app, "Label").any(func(candidate): return candidate.text.contains(text) and candidate.is_visible_in_tree())
