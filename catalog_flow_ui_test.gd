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

func click_control(control: Control, use_touch: bool = false) -> void:
	if control == null:
		return
	var position := control.get_global_rect().get_center()
	if use_touch:
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 1
		touch_down.position = position
		touch_down.pressed = true
		root.push_input(touch_down)
		await process_frame
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 1
		touch_up.position = position
		touch_up.pressed = false
		root.push_input(touch_up)
	else:
		var mouse_down := InputEventMouseButton.new()
		mouse_down.button_index = MOUSE_BUTTON_LEFT
		mouse_down.position = position
		mouse_down.pressed = true
		root.push_input(mouse_down)
		await process_frame
		var mouse_up := InputEventMouseButton.new()
		mouse_up.button_index = MOUSE_BUTTON_LEFT
		mouse_up.position = position
		mouse_up.pressed = false
		root.push_input(mouse_up)
	await settle_frames()

func settle_frames() -> void:
	await process_frame
	await process_frame

func verify_purchase_footer(stage: String) -> void:
	var workflow := app.find_child("BuyInventoryWorkflow", true, false) as Control
	var step_scroll := app.find_child("BuyInventoryStepScroll", true, false) as ScrollContainer
	var footer := app.find_child("BuyInventoryNavigationFooter", true, false) as Control
	var outer_scroll := app.find_child("GameContentScroll", true, false) as ScrollContainer
	expect(workflow != null and step_scroll != null and footer != null
		and footer.is_visible_in_tree(), "%s keeps the persistent navigation footer visible" % stage)
	if workflow == null or step_scroll == null or footer == null:
		return
	var footer_rect := footer.get_global_rect()
	var step_rect := step_scroll.get_global_rect()
	expect(footer_rect.position.y >= 0.0 and footer_rect.end.y <= app.size.y
		and step_rect.end.y <= footer_rect.position.y + 1.0,
		"%s footer stays inside the viewport and below the independently scrollable content" % stage)
	if outer_scroll != null:
		var bar := outer_scroll.get_v_scroll_bar()
		expect(bar.max_value - bar.page <= 0.1,
			"%s does not depend on outer-page scrolling to reach purchase navigation" % stage)

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
	var workflow_panel := app.find_child("BuyInventoryWorkflow", true, false) as Control
	var workflow_scroll := app.find_child("BuyInventoryStepScroll", true, false) as ScrollContainer
	var workflow_footer := app.find_child("BuyInventoryNavigationFooter", true, false) as HBoxContainer
	expect(workflow_panel != null and workflow_scroll != null and workflow_footer != null
		and workflow_scroll.get_parent() == workflow_panel and workflow_footer.get_parent() == workflow_panel
		and not _is_descendant_of(workflow_footer, workflow_scroll),
		"Quick Purchase uses an independently scrollable middle area and a persistent footer outside it")
	verify_purchase_footer("Category")
	var page_heading := app.find_child("PageHeading", true, false)
	expect(page_heading != null and controls(page_heading, "Label").any(func(item): return item.text == "Market"),
		"Market page heading displays only Market while the Quick Purchase heading remains in-panel")
	var navigation_slot := app.find_child("PrimaryNavigationSlot", true, false) as Control
	var navigation_drawer := app.find_child("PrimaryNavigation", true, false) as Control
	expect(navigation_slot != null and navigation_drawer != null and navigation_drawer.get_parent() == navigation_slot
		and is_zero_approx(navigation_slot.custom_minimum_size.y),
		"Closed navigation drawer remains available without adding its hidden content height to the page")
	expect(Market._category_columns(1920.0) == 3 and Market._category_columns(1366.0) == 3
		and Market._category_columns(1024.0) == 3 and Market._category_columns(768.0) == 2
		and Market._category_columns(390.0) == 2 and Market._category_columns(375.0) == 2
		and Market._category_columns(844.0) == 2 and Market._category_columns(667.0) == 2,
		"Categories use responsive three, two and compact mobile columns")
	expect(app.find_child("CatalogueCategory_Electronics", true, false) is Button and app.find_child("CatalogueCategory_Kitchen", true, false) is Button,
		"Category selection uses the live game catalogue")
	expect(button("Select Category") == null, "Category cards no longer contain redundant Select Category buttons")
	for category_index in Catalog.CATEGORIES.size():
		var category_name := str(Catalog.CATEGORIES[category_index])
		var category_id := category_name.replace("&", "and").replace(" ", "_")
		var category_card := app.find_child("CatalogueCategory_" + category_id, true, false) as Button
		expect(category_card != null and category_card.icon != null and category_card.text.contains("products"),
			"%s shows its live product count with a bundled graphical category icon" % category_name)
	var electronics := app.find_child("CatalogueCategory_Electronics", true, false) as Button
	await click_control(electronics)
	expect(app.catalog_category == Catalog.CATEGORIES.find("Electronics") and app.find_child("ContinueBuyInventory", true, false) != null,
		"A real mouse click selects Electronics and enables Continue")
	electronics = app.find_child("CatalogueCategory_Electronics", true, false) as Button
	var selected_box := electronics.get_theme_stylebox("normal") as StyleBoxFlat if electronics != null else null
	expect(selected_box != null and selected_box.border_color == Color("#D5AC61"),
		"Selected category uses the gold border")
	var touch_test_card := app.find_child("CatalogueCategory_Kitchen", true, false) as Button
	await click_control(touch_test_card, true)
	expect(app.catalog_category == Catalog.CATEGORIES.find("Kitchen"),
		"A real touchscreen tap selects a category through the same button target")
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.render()
	await settle_frames()
	click("Continue")
	await settle_frames()
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "products"
		and app.find_child("BuyInventoryNavigationFooter", true, false) != null
		and app.find_child("BackFromProducts", true, false) != null,
		"Continue opens the Product step with persistent Back and Continue controls")
	verify_purchase_footer("Product")
	var search := app.find_child("CatalogueProductSearch", true, false) as LineEdit
	var first_card := app.find_child("CatalogueProduct_0", true, false) as Button
	var product_content := first_card.get_node_or_null("ProductCardContent") as VBoxContainer if first_card != null else null
	var product_name_row := product_content.get_node_or_null("ProductNameRow") as HBoxContainer if product_content != null else null
	var product_summary_row := product_content.get_node_or_null("ProductSummaryRow") as HBoxContainer if product_content != null else null
	var supplier_count := product_content.get_node_or_null("ProductSummaryRow/ProductSupplierCount") as Label if product_content != null else null
	var landed_cost := product_content.get_node_or_null("ProductSummaryRow/ProductStartingLandedCost") as Label if product_content != null else null
	expect(product_content != null and product_content.get_child_count() == 2
		and product_name_row != null and product_summary_row != null
		and supplier_count != null and supplier_count.text == "%d suppliers" % Market._available_suppliers(app.sim.state, 0).size()
		and landed_cost != null and landed_cost.text == app.money(Market._starting_landed_cost(app.sim.state, 0, Market._available_suppliers(app.sim.state, 0)))
		and landed_cost.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
		"Product card presents product name, supplier count, and starting landed cost in exactly two compact rows")
	expect(first_card != null and first_card.custom_minimum_size.y <= 68.0
		and not has_label("Tap to select"),
		"Product card removes the instructional text and avoids unnecessary height")
	expect(first_card != null and first_card.find_child("ChooseProduct_0", true, false) == null
		and app.find_child("ProductSelectionIndicator_0", true, false) != null
		and search != null and search.custom_minimum_size.y <= 40.0,
		"Compact product cards use a full-card selection target, visible selection state, and a compact search field")
	if search != null:
		search.text = "no-such-product"
		search.text_changed.emit(search.text)
		expect(first_card != null and not first_card.is_visible_in_tree(), "Product category filters its products")
		search.text = "Portable Blender"
		search.text_changed.emit(search.text)
	await click_control(first_card)
	first_card = app.find_child("CatalogueProduct_0", true, false) as Button
	var selected_indicator := app.find_child("ProductSelectionIndicator_0", true, false) as TextureRect
	var selected_product_style := first_card.get_theme_stylebox("normal") as StyleBoxFlat if first_card != null else null
	expect(first_card != null and selected_indicator != null and selected_indicator.visible and selected_indicator.texture != null
		and selected_product_style != null and selected_product_style.border_color == Color("#D5AC61"),
		"Selecting a product updates its gold border and graphical checkmark")
	click("Continue")
	await settle_frames()
	expect(app.selected_product == 0 and str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "suppliers"
		and app.find_child("BackFromSuppliers", true, false) != null,
		"Selected product is retained and the Supplier step opens")
	await settle_frames()
	verify_purchase_footer("Supplier")
	var supplier_index := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_card := app.find_child("SupplierChoice%d" % supplier_index, true, false)
	expect(supplier_card != null and has_label("Quality · MOQ") and has_label("Trust · Reliability") and has_label("Estimated Arrival"),
		"Supplier cards show actual quality, MOQ, trust, reliability and calendar arrival")
	click("Select Supplier", supplier_card)
	click("Continue")
	await settle_frames()
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "negotiate" and app.find_child("SupplierNegotiationStep", true, false) != null
		and app.find_child("BackToSuppliers", true, false) != null,
		"Supplier selection opens the separate Negotiate step")
	verify_purchase_footer("Negotiate")
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
	expect(str(app.get_meta(Market.CATALOG_STAGE_META, "")) == "summary"
		and app.find_child("BackFromPurchaseSummary", true, false) != null
		and app.find_child("ConfirmPurchaseOrder", true, false) != null,
		"Continue opens Confirm Purchase with persistent Back and Confirm controls")
	verify_purchase_footer("Confirm")
	var quantity_label := app.find_child("SupplierPurchaseQuantity", true, false) as Label
	expect(quantity_label != null and quantity_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"Quantity is displayed centered in the compact navy quantity field")
	root.size = Vector2i(390, 844)
	app.size = Vector2(390, 844)
	app.refresh_view()
	await settle_frames()
	var mobile_purchase_scroll := app.find_child("BuyInventoryStepScroll", true, false) as ScrollContainer
	if mobile_purchase_scroll != null:
		var touch_start := mobile_purchase_scroll.get_global_rect().position + Vector2(50, 100)
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 1
		touch_down.position = touch_start
		touch_down.pressed = true
		root.push_input(touch_down)
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = 1
		touch_drag.position = touch_start + Vector2(0, -120)
		touch_drag.relative = Vector2(0, -120)
		root.push_input(touch_drag)
		await settle_frames()
		expect(mobile_purchase_scroll.scroll_vertical > 0,
			"Touchscreen drag scrolls the mobile purchase summary without moving its footer")
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 1
		touch_up.position = touch_drag.position
		touch_up.pressed = false
		root.push_input(touch_up)
	else:
		expect(false, "Mobile purchase summary exposes a touch-scroll container")
	root.size = Vector2i(1280, 720)
	app.size = Vector2(1280, 720)
	app.refresh_view()
	await settle_frames()
	var quantity_minus := app.find_child("PurchaseQuantityMinus", true, false) as Button
	var quantity_plus := app.find_child("PurchaseQuantityPlus", true, false) as Button
	var buy_max := app.find_child("BuyMaximumUnits", true, false) as Button
	var quantity_row := app.find_child("PurchaseQuantityControls", true, false) as HBoxContainer
	var buy_max_row := app.find_child("BuyMaxControls", true, false) as HBoxContainer
	var balance_metric: Control = buy_max_row.get_child(0) as Control if buy_max_row != null and buy_max_row.get_child_count() > 0 else null
	expect(quantity_minus != null and quantity_plus != null and quantity_row != null
		and is_equal_approx(quantity_minus.custom_minimum_size.x, 48.0)
		and is_equal_approx(quantity_plus.custom_minimum_size.x, 48.0)
		and quantity_minus.size_flags_horizontal == Control.SIZE_SHRINK_CENTER
		and quantity_plus.size_flags_horizontal == Control.SIZE_SHRINK_CENTER
		and buy_max != null and is_equal_approx(buy_max.custom_minimum_size.x, 132.0)
		and is_equal_approx(buy_max.custom_minimum_size.y, 44.0)
		and buy_max_row != null and balance_metric != null
		and (buy_max_row.size_flags_horizontal & Control.SIZE_EXPAND_FILL) != 0
		and (balance_metric.size_flags_horizontal & Control.SIZE_EXPAND_FILL) != 0,
		"Quantity stepper uses compact fixed-width touch targets and Buy Max stays compact")
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
	var mobile_step_scroll := app.find_child("BuyInventoryStepScroll", true, false) as ScrollContainer
	var mobile_footer := app.find_child("BuyInventoryNavigationFooter", true, false) as Control
	await settle_frames()
	var mobile_scroll_bar := mobile_step_scroll.get_v_scroll_bar() if mobile_step_scroll != null else null
	var mobile_step_content := mobile_step_scroll.get_child(0) as Control if mobile_step_scroll != null and mobile_step_scroll.get_child_count() > 0 else null
	var category_content_exceeds_viewport := mobile_step_content != null and mobile_step_content.get_combined_minimum_size().y > mobile_step_scroll.size.y + 1.0
	var outer_page_scroll := app.find_child("GameContentScroll", true, false) as ScrollContainer
	var outer_scroll_bar := outer_page_scroll.get_v_scroll_bar() if outer_page_scroll != null else null
	expect(mobile_grid != null and mobile_grid.columns == 2 and app.find_child("BuyInventoryProgress", true, false) != null,
		"Mobile portrait retains compact category cards and the five-step indicator")
	expect(mobile_scroll_bar != null and mobile_step_content != null
		and (category_content_exceeds_viewport == (mobile_scroll_bar.max_value - mobile_scroll_bar.page > 0.0)),
		"Mobile category content scrolls independently only when its measured height exceeds the available step viewport")
	expect(outer_scroll_bar != null and outer_scroll_bar.max_value - outer_scroll_bar.page <= 0.1,
		"Market page does not need an outer scroll that could carry its persistent footer off-screen")
	if mobile_footer != null:
		var footer_rect := mobile_footer.get_global_rect()
		expect(footer_rect.position.y >= 0.0 and footer_rect.end.y <= float(root.size.y),
			"Mobile navigation footer remains visible within the viewport")
	var viewport_matrix := [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1024, 768), Vector2i(768, 1024),
		Vector2i(390, 844), Vector2i(375, 667), Vector2i(360, 800), Vector2i(844, 390), Vector2i(667, 375)]
	for viewport in viewport_matrix:
		root.size = viewport
		app.size = Vector2(viewport)
		app.catalog_category = -1
		app.set_meta(Market.CATALOG_STAGE_META, "categories")
		app.render()
		await settle_frames()
		var responsive_grid := app.find_child("ProductCategoryGrid", true, false) as GridContainer
		var first_category := app.find_child("CatalogueCategory_Electronics", true, false) as Button
		expect(responsive_grid != null and first_category != null,
			"Category cards render at %d×%d" % [viewport.x, viewport.y])
		var responsive_footer := app.find_child("BuyInventoryNavigationFooter", true, false) as Control
		if responsive_footer != null:
			var footer_rect := responsive_footer.get_global_rect()
			expect(footer_rect.position.y >= 0.0 and footer_rect.end.y <= app.size.y,
				"Purchase navigation footer is visible at %d×%d" % [viewport.x, viewport.y])
		if viewport.y <= 450:
			expect(app.compact_landscape_layout and responsive_footer != null,
				"Short landscape viewport uses compact layout and retains Buy Inventory navigation")
	app.queue_free()
	await process_frame
	print("Buy Inventory workflow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
