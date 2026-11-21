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

func button(title: String) -> Button:
	for candidate in controls(app, "Button"):
		if candidate.text.to_lower() == title.to_lower() and candidate.is_visible_in_tree(): return candidate
	return null

func click(title: String) -> void:
	var candidate := button(title)
	if candidate != null and not candidate.disabled: candidate.pressed.emit()

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
	expect(app.find_child("BuyInventoryProgress", true, false) != null and button("Continue") != null,
		"Market shows the approved progress indicator and category continuation")
	var category := app.find_child("CatalogueCategory_Kitchen", true, false) as Button
	if category != null: category.pressed.emit()
	click("Continue")
	await process_frame
	var product := app.find_child("CatalogueProduct_0", true, false) as Button
	expect(product != null and product.find_child("ChooseProduct_0", true, false) == null,
		"Kitchen category displays selectable catalogue product cards without a redundant nested action")
	if product != null: product.pressed.emit()
	click("Continue")
	await process_frame
	expect(app.find_child("CompactSupplierList", true, false) != null and app.find_child("SupplierChoice%d" % int(Catalog.SUPPLIER_SELECTION_INDICES[0]), true, false) != null,
		"Product step opens available real supplier offers")
	var supplier_index := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_card := app.find_child("SupplierChoice%d" % supplier_index, true, false)
	var choose_supplier := supplier_card.find_child("SelectSupplier%d" % supplier_index, true, false) as Button
	if choose_supplier != null: choose_supplier.pressed.emit()
	click("Continue")
	await process_frame
	expect(app.find_child("SupplierNegotiationStep", true, false) != null and button("Request Offer") != null,
		"Supplier step opens the separate negotiation card")
	var discount := app.find_child("RequestedDiscount", true, false) as OptionButton
	if discount != null:
		discount.select(1)
		discount.item_selected.emit(1)
	click("Request Offer")
	await process_frame
	var terms := Supply.quote(app.sim.state, 0, supplier_index)
	expect(int(terms.get("discount", 0)) > 0 and button("Accept Offer") != null,
		"Requested offer follows actual supplier volume negotiation mechanics")
	click("Accept Offer")
	await process_frame
	expect(bool(app.get_meta("buy_negotiation_accepted_0_%d" % supplier_index, false)), "Negotiated terms require explicit acceptance")
	if discount != null:
		discount.select(2)
		discount.item_selected.emit(2)
		expect(not bool(app.get_meta("buy_negotiation_accepted_0_%d" % supplier_index, true)) and not bool(app.get_meta("buy_negotiation_ready_0_%d" % supplier_index, true)),
			"Changing requested discount invalidates the displayed negotiation result")
		click("Request Offer")
		await process_frame
		click("Accept Offer")
	click("Continue")
	await process_frame
	expect(app.find_child("PurchaseSummaryStep", true, false) != null, "Accepted supplier terms continue to quantity and purchase summary")
	var quantity := app.find_child("SupplierPurchaseQuantity", true, false) as Label
	expect(quantity != null and app.find_child("QuantityIncrement10", true, false) != null and app.find_child("QuantityIncrement100", true, false) != null and app.find_child("QuantityIncrement1000", true, false) != null,
		"Quantity display and all three quantity increments are present")
	app.set_meta("buy_quantity_0_%d" % supplier_index, int(Catalog.SUPPLIERS[supplier_index].minimum))
	app.refresh_view()
	var confirm := button("Confirm Purchase")
	expect(confirm != null and not confirm.disabled and button("Buy Max") != null, "Valid supplier minimum allows purchase and Buy Max calculation")
	if confirm != null: confirm.pressed.emit()
	await process_frame
	expect(is_instance_valid(app.confirmation) and app.sim.state.inbound.is_empty(), "Purchase has a user confirmation before order creation")
	if is_instance_valid(app.confirmation): app.confirmation.confirmed.emit()
	await process_frame
	expect(app.sim.state.inbound.size() == 1 and app.page == "Inbound Stock" and app.find_child("FocusedInboundPurchase%d" % int(app.get_meta("focused_inbound_purchase_id", -1)), true, false) != null,
		"Confirmed transaction creates one inbound shipment and focuses it in Inbound Stock")
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
		expect(legacy_card != null, "Legacy supplier relationship remains visible")
	app.queue_free()
	await process_frame
	print("Supplier workflow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
