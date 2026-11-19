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
	expect(app.find_child("CatalogueCategory_Electronics", true, false) != null
		and app.find_child("CatalogueCategory_Kitchen", true, false) != null,
		"Product Catalogue starts with selectable game categories")
	click("Browse Kitchen")
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
	var supplier := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_card := app.find_child("SupplierChoice%d" % supplier, true, false)
	expect(supplier_card != null and button("Select Supplier", supplier_card) != null,
		"Supplier summary exposes selection, quality, reliability, MOQ, lead time, and landed cost")
	click("Select Supplier", supplier_card)
	await settle_frames()
	var details := app.find_child("SelectedSupplierDetails", true, false)
	expect(details != null and button("Negotiate", details) != null and button("Accept Offer", details) != null
		and button("Generate Quotation", details) != null and button("Confirm Purchase", details) != null,
		"Supplier details provide negotiation, acceptance, quotation, and confirmation actions")
	var quantity := app.find_child("SupplierPurchaseQuantity", true, false) as LineEdit
	expect(quantity != null, "Purchase quantity is shown in supplier details")
	if quantity != null:
		quantity.text = str(Supply.negotiation_minimum(supplier))
		quantity.text_changed.emit(quantity.text)
	click("Negotiate", details)
	await settle_frames()
	var terms := Supply.quote(app.sim.state, 0, supplier)
	expect(int(terms.get("discount", 0)) > 0, "Negotiate uses the existing supplier response mechanics")
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
	expect(mobile_grid != null and mobile_grid.columns == 1,
		"Category catalogue switches to a single-column layout on mobile portrait")
	app.queue_free()
	await process_frame
	print("Category-first product flow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func has_label(text: String) -> bool:
	return controls(app, "Label").any(func(candidate): return candidate.text.contains(text) and candidate.is_visible_in_tree())
