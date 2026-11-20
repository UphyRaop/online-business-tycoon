extends SceneTree

const Main = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
const Market = preload("res://market_view.gd")

var failures := 0
var app: Control

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
	var candidate := button(title, scope)
	if candidate != null: candidate.pressed.emit()

func has_label(text: String) -> bool:
	return controls(app, "Label").any(func(candidate): return candidate.text.contains(text) and candidate.is_visible_in_tree())

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1":
		push_error("Run supplier workflow UI test with an isolated user-data profile.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	app = Main.instantiate()
	root.add_child(app)
	await process_frame
	app.sim = Sim.new(Sim.register("Ari Founder", "North Star Co", "North Star", 0, 0, 1, 954))
	app.screen = "Game"
	app.page = "Market"
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.render()
	await process_frame
	expect(app.find_child("ProductCategoryGrid", true, false) != null, "Product Catalogue starts with category cards")
	click("Browse", app.find_child("CatalogueCategory_Kitchen", true, false))
	await process_frame
	var product_card := app.find_child("CatalogueProduct_0", true, false)
	expect(product_card != null and button("Choose Product", product_card) != null, "Selecting Kitchen opens its actual product cards")
	click("Choose Product", product_card)
	await process_frame
	expect(app.find_child("CompactSupplierList", true, false) != null, "Product selection opens the compact supplier list")
	var supplier_index := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_card := app.find_child("SupplierChoice%d" % supplier_index, true, false)
	expect(supplier_card != null and button("View Details", supplier_card) != null, "A supplier summary can be expanded")
	click("View Details", supplier_card)
	await process_frame
	supplier_card = app.find_child("SupplierChoice%d" % supplier_index, true, false)
	expect(supplier_card != null and button("Select Supplier", supplier_card) != null, "Expanded supplier details can be selected")
	click("Select Supplier", supplier_card)
	await process_frame
	var details := app.find_child("SelectedSupplierDetails", true, false)
	expect(details != null, "Selecting a supplier opens its details")
	for action in ["Submit Offer", "Accept Offer", "Generate Quotation", "Confirm Purchase", "Back to Suppliers"]:
		expect(button(action, details) != null, "Supplier details provides the %s action" % action)
	expect(app.find_child("SupplierProposedUnitPrice", true, false) != null
		and app.find_child("SupplierNegotiationResponse", true, false) != null,
		"Negotiation view shows a target price and a separate actual supplier response")
	var quantity := app.find_child("SupplierPurchaseQuantity", true, false) as LineEdit
	expect(quantity != null, "Quantity controls are shown within supplier details")
	if quantity != null:
		quantity.text = "0"
		quantity.text_changed.emit("0")
		var invalid_quote_button := button("Generate Quotation")
		expect(invalid_quote_button != null and invalid_quote_button.disabled, "Invalid quantity is rejected using actual supplier minimums")
		quantity.text = str(Supply.negotiation_minimum(supplier_index))
		quantity.text_changed.emit(quantity.text)
	click("Submit Offer", details)
	await process_frame
	var terms := Supply.quote(app.sim.state, 0, supplier_index)
	expect(int(terms.get("discount", 0)) > 0, "Negotiation persists the existing supplier response and quote")
	click("Accept Offer")
	await process_frame
	click("Generate Quotation")
	await process_frame
	var quotation := app.find_child("GeneratedPurchaseQuotation", true, false)
	expect(quotation != null and has_label("Total") and has_label("Freight"), "A valid quotation presents the goods, freight, and total costs")
	var confirm := button("Confirm Purchase")
	expect(confirm != null and not confirm.disabled, "Accepted supplier terms and a valid quotation enable purchase confirmation")
	if confirm != null: confirm.pressed.emit()
	await process_frame
	expect(is_instance_valid(app.confirmation) and app.sim.state.inbound.is_empty(), "Purchase requires a confirmation dialog before creating inbound inventory")
	if is_instance_valid(app.confirmation):
		app.confirmation.confirmed.emit()
		await process_frame
	expect(app.sim.state.inbound.size() == 1 and app.find_child("SupplierPurchaseConfirmation", true, false) != null,
		"Confirming a purchase creates exactly one order and displays a receipt")
	var legacy_supplier := -1
	for candidate in range(Catalog.SUPPLIERS.size()):
		if candidate not in Catalog.SUPPLIER_SELECTION_INDICES:
			legacy_supplier = candidate
			break
	expect(legacy_supplier >= 0, "Legacy supplier fixture exists outside the active sourcing network")
	if legacy_supplier >= 0:
		SupplierCredit.ensure(app.sim.state)
		var credit: Dictionary = app.sim.state.supplier_credit
		credit.relationships[Catalog.supplier_id(legacy_supplier)] = {"trust": 64, "settled_purchase_count": 3}
		app.sim.state.supplier_credit = credit
		app.page = "Supplier Relationships"
		app.render()
		await process_frame
		var legacy_card := app.find_child("SupplierRelationship%d" % legacy_supplier, true, false)
		expect(legacy_card != null and has_label("Historical relationship. New sourcing is unavailable"),
			"Legacy-only supplier relationships remain visible with an accurate historical status")
		var legacy_text := ""
		if legacy_card != null:
			for label in controls(legacy_card, "Label"):
				legacy_text += " " + str(label.text)
		expect(not legacy_text.contains("Locked") and not legacy_text.contains("Unlocks at supplier progression"),
			"Legacy-only suppliers do not show an impossible future unlock level")
	app.page = "Market"
	root.size = Vector2i(390, 844)
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.catalog_category = -1
	app.render()
	await process_frame
	var grid := app.find_child("ProductCategoryGrid", true, false) as GridContainer
	expect(grid != null and grid.columns == 2, "Category cards adapt to a two-column mobile portrait layout")
	app.queue_free()
	await process_frame
	print("Supplier workflow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
