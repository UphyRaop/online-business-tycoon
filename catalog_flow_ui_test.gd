extends SceneTree

const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const SupplierCredit = preload("res://supplier_credit.gd")
const Market = preload("res://market_view.gd")
const Saves = preload("res://save_store.gd")

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
	if node != null and not node.disabled: node.pressed.emit()

func settle_frames() -> void:
	await process_frame
	await process_frame

func has_label(text: String) -> bool:
	return controls(app, "Label").any(func(candidate): return candidate.text.contains(text) and candidate.is_visible_in_tree())

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1":
		push_error("Run catalog UI tests with an isolated user-data profile.")
		quit(1)
		return
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
	expect(app.find_child("BuyInventoryWorkflow", true, false) != null and has_label("Quick Purchase"),
		"Market opens the compact Quick Purchase workflow")
	expect(Market._category_columns(1280.0) == 3 and Market._category_columns(768.0) == 2 and Market._category_columns(390.0) == 2,
		"Categories use responsive three, two and compact mobile columns")
	expect(app.find_child("CatalogueCategory_Electronics", true, false) != null and app.find_child("CatalogueCategory_Kitchen", true, false) != null,
		"Category selection uses the live game catalogue")
	click("Select Category", app.find_child("CatalogueCategory_Kitchen", true, false))
	expect(app.catalog_category == Catalog.CATEGORIES.find("Kitchen") and app.find_child("ContinueBuyInventory", true, false) != null,
		"Category selection is retained and Continue is available")
	click("Continue")
	await settle_frames()
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "products", "Continue opens the Product step")
	var search := app.find_child("CatalogueProductSearch", true, false) as LineEdit
	var first_card := app.find_child("CatalogueProduct_0", true, false) as Control
	expect(first_card != null and has_label("Starting Landed Cost") and has_label("Available Suppliers"),
		"Product cards show catalogue product and indicative supplier pricing information")
	if search != null:
		search.text = "no-such-product"
		search.text_changed.emit(search.text)
		expect(first_card != null and not first_card.is_visible_in_tree(), "Product category filters its products")
		search.text = "Portable Blender"
		search.text_changed.emit(search.text)
	click("Select Product", first_card)
	click("Continue")
	await settle_frames()
	expect(app.selected_product == 0 and str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "suppliers",
		"Selected product is retained and the Supplier step opens")
	var supplier_index := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_card := app.find_child("SupplierChoice%d" % supplier_index, true, false)
	expect(supplier_card != null and has_label("Quality · MOQ") and has_label("Trust · Reliability") and has_label("Estimated Arrival"),
		"Supplier cards show actual quality, MOQ, trust, reliability and calendar arrival")
	click("Select Supplier", supplier_card)
	click("Continue")
	await settle_frames()
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "negotiate" and app.find_child("SupplierNegotiationStep", true, false) != null,
		"Supplier selection opens the separate Negotiate step")
	var discount := app.find_child("RequestedDiscount", true, false) as OptionButton
	if discount != null:
		discount.select(2)
		discount.item_selected.emit(2)
	click("Request Offer")
	await settle_frames()
	var accepted_quote := Supply.quote(app.sim.state, 0, supplier_index)
	expect(int(accepted_quote.get("discount", 0)) > 0 and has_label("Offer received"),
		"Negotiation uses the existing supplier volume and pricing rules")
	click("Accept Offer")
	await settle_frames()
	expect(has_label("Offer accepted") and not button("Continue").disabled,
		"Supplier offer requires explicit acceptance before purchase")
	if discount != null:
		discount.select(3)
		discount.item_selected.emit(3)
		expect(not has_label("Offer accepted") and has_label("Request changed"),
			"Changing the requested discount invalidates the prior negotiation result")
		discount.select(2)
		discount.item_selected.emit(2)
	click("Request Offer")
	await settle_frames()
	click("Accept Offer")
	click("Continue")
	await settle_frames()
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "summary", "Continue opens the Confirm Purchase step")
	var quantity_label := app.find_child("SupplierPurchaseQuantity", true, false) as Label
	expect(quantity_label != null and quantity_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"Quantity is displayed centered in the compact navy quantity field")
	for increment in [10, 100, 1000]:
		expect(app.find_child("QuantityIncrement%d" % int(increment), true, false) != null,
			"Quantity increment ×%d is available" % int(increment))
	click("QuantityIncrement10")
	click("PurchaseQuantityPlus")
	await settle_frames()
	var quantity := int(app.get_meta("buy_quantity_0_%d" % supplier_index, 0))
	expect(quantity >= int(Catalog.SUPPLIERS[supplier_index].minimum), "Quantity controls respect supplier MOQ")
	expect(has_label("Available Bank Balance") and button("Buy Max") != null,
		"Buy Max shows the live company bank balance")
	app.refresh_view()
	var unit_cost := int(Supply.quote(app.sim.state, 0, supplier_index).get("cost", Catalog.quote(app.sim.state.country, 0, supplier_index)))
	var unit_freight := Catalog.inbound_freight(app.sim.state.country, supplier_index)
	var expected_max := mini(Supply.maximum_order_quantity(supplier_index), int(app.sim.state.cash) / (unit_cost + unit_freight))
	click("Buy Max")
	await settle_frames()
	quantity = int(app.get_meta("buy_quantity_0_%d" % supplier_index, 0))
	expect(quantity == expected_max, "Buy Max uses current cash, actual unit cost, freight and supplier order limit")
	expect(has_label("Goods Subtotal") and has_label("Inbound Freight") and has_label("Total Purchase")
		and has_label("Landed Cost Per Unit") and has_label("Estimated Arrival Date") and has_label("Possible Delay"),
		"Purchase summary displays each approved field with actual price and date calculations")
	var confirm := button("Confirm Purchase")
	expect(confirm != null and not confirm.disabled, "Valid quantity and available funds enable purchase confirmation")
	var expected_purchase := Supply.purchase_breakdown(app.sim.state, 0, supplier_index, quantity)
	var cash_before_purchase := int(app.sim.state.cash)
	var original_cash := int(app.sim.state.cash)
	app.sim.state.cash = 0
	app.refresh_view()
	confirm = button("Confirm Purchase")
	expect(confirm != null and confirm.disabled, "Insufficient funds prevent purchase")
	app.sim.state.cash = original_cash
	app.refresh_view()
	confirm = button("Confirm Purchase")
	if confirm != null: confirm.pressed.emit()
	await settle_frames()
	expect(is_instance_valid(app.confirmation) and app.sim.state.inbound.is_empty(), "Purchase requires confirmation and does not execute early")
	if is_instance_valid(app.confirmation): app.confirmation.confirmed.emit()
	await settle_frames()
	var purchase_id := int(app.get_meta("focused_inbound_purchase_id", -1))
	expect(app.sim.state.inbound.size() == 1 and app.page == "Inbound Stock" and app.find_child("FocusedInboundPurchase%d" % purchase_id, true, false) != null,
		"Confirmed purchase creates one shipment and automatically opens focused Inbound Stock")
	expect(app.sim.state.inbound[0].units == expected_max and has_label("Purchase Confirmed") and has_label("Shipment Status"),
		"Inbound Inventory confirmation shows the actual shipment details")
	expect(int(app.sim.state.cash) == cash_before_purchase - int(expected_purchase.total)
		and int(app.sim.state.ledger.back().purchases) >= int(expected_purchase.total),
		"Purchase debits cash and records the actual landed purchase cost in the existing ledger")
	var save_path := "user://buy_inventory_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(app.sim.state, save_path) == OK, "Purchase and inbound shipment save successfully")
	var restored := Saves.load_state(save_path)
	expect(restored != null and restored.inbound.size() == 1 and int(restored.inbound[0].id) == purchase_id
		and int(restored.inbound[0].units) == expected_max, "Save and Load retain the new purchase and shipment without schema changes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var progress := app.find_child("ShipmentProgress", true, false)
	expect(progress != null and has_label("In Transit"), "Shipment progress follows the actual inbound state")
	root.size = Vector2i(390, 844)
	app.page = "Market"
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.catalog_category = -1
	app.render()
	await settle_frames()
	var mobile_grid := app.find_child("ProductCategoryGrid", true, false) as GridContainer
	expect(mobile_grid != null and mobile_grid.columns == 2 and app.find_child("BuyInventoryProgress", true, false) != null,
		"Mobile portrait retains compact category cards and the five-step indicator")
	app.queue_free()
	await process_frame
	print("Buy Inventory workflow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
