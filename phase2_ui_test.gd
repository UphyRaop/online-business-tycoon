extends "res://phase1_ui_test.gd"

const Storefront = preload("res://storefront.gd")
const Calendar = preload("res://game_calendar.gd")


func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run the UI test with OBT_ISOLATED_TEST_PROFILE=1 and a fresh APPDATA folder.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	create_new_game_for_test("Mira Founder", "Aster Labs")
	app.sim.state.stores = Stores.migration_defaults(app.sim.state)
	app.sim.state.website_active = true
	app.sim.state.seed = 153
	press("Market")
	await browse_catalog_product("Kitchen", 0)
	expect(has_label("Forecast"), "Supplier Details shows the product demand forecast")
	var quantity: LineEdit = field_for_label("Purchase Quantity")
	expect(quantity != null, "Supplier Details exposes an editable purchase quantity")
	quantity.text = "20"
	quantity.text_changed.emit("20")
	press("Submit Offer")
	expect(has_label("Negotiated supplier response:"), "Negotiation displays the actual supplier response and terms")
	await quote_and_confirm_purchase()
	expect(has_label("Purchase Confirmed") and app.sim.state.inbound.size() == 1 and app.sim.state.inbound[0].units == 20,
		"A confirmed supplier quotation creates one purchase order with the requested quantity")
	open_first_store_listing()
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 1)
	press("Save Changes")
	press("Market")
	await browse_catalog_product("Kitchen", 4)
	quantity = field_for_label("Purchase Quantity")
	quantity.text = "20"
	quantity.text_changed.emit("20")
	await quote_and_confirm_purchase()
	open_first_store_listing()
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 1)
	press("Save Changes")
	press("Market")
	await browse_catalog_product("Kitchen", 4)
	open_first_store_listing()
	var offer_store_id: int = app.selected_store_id
	var offers_before: Dictionary = Storefront.offers_for_store(app.sim.state, offer_store_id, 4).duplicate(true)
	expect(has_visible_label("No offers saved") and not has_visible_label("Units per Bundle")
		and not has_visible_label("Upsell Quantity") and controls(app, "Button").any(func(button): return button.text.to_lower() == "create offer" and button.is_visible_in_tree()),
		"Offer forms start collapsed while the existing-offer summary and Create Offer action remain visible")
	press("Create Offer")
	expect(has_visible_label("Choose the type of offer") and not has_visible_label("Units per Bundle")
		and not has_visible_label("Upsell Quantity"), "Create Offer asks the player to choose an offer type before showing a form")
	press("Bundle")
	expect(has_visible_label("Units per Bundle") and not has_visible_label("Upsell Quantity"), "Selecting Bundle shows only the bundle form")
	var bundle_quantity := field_for_label("Units per Bundle")
	bundle_quantity.text = "3"
	press("Upsell")
	expect(has_visible_label("Upsell Quantity") and not has_visible_label("Units per Bundle"), "Offer form can switch to Upsell without showing both forms")
	press("Bundle")
	expect(field_for_label("Units per Bundle").text == "3", "Switching offer type retains unsaved form values")
	press("Cancel")
	expect(not has_visible_label("Units per Bundle") and not has_visible_label("Upsell Quantity")
		and Storefront.offers_for_store(app.sim.state, offer_store_id, 4) == offers_before,
		"Cancel closes offer creation without changing saved offers")
	press("Create Offer")
	press("Bundle")
	field_for_label("Units per Bundle").text = "3"
	press("Save bundle")
	expect(Storefront.offers_for_store(app.sim.state, offer_store_id, 4).has(1) and Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[1].quantity == 3,
		"Saving a Bundle records the configured quantity")
	press("Edit bundle")
	expect(field_for_label("Units per Bundle").text == "3", "Editing a saved Bundle preserves its settings in the form")
	field_for_label("Units per Bundle").text = "4"
	press("Save bundle")
	expect(Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[1].quantity == 4, "Editing a saved Bundle updates its quantity")
	press("Edit bundle")
	field_for_label("Units per Bundle").text = "6"
	press("Cancel")
	expect(Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[1].quantity == 4 and not has_visible_label("Units per Bundle"),
		"Cancel closes an edit without changing the saved Bundle")
	press("Create Offer")
	press("Upsell")
	press("Save upsell")
	expect(Storefront.offers_for_store(app.sim.state, offer_store_id, 4).has(1) and Storefront.offers_for_store(app.sim.state, offer_store_id, 4).has(2), "Bundle and Upsell configurations can both be retained for this listing")
	expect(not Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[1].enabled and Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[2].enabled, "Saving an active upsell disables the Bundle")
	press("Edit upsell")
	field_for_label("Discount Percent").text = "15"
	press("Save upsell")
	expect(Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[2].discount == 15 and Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[2].enabled,
		"Editing an Upsell preserves its offer and saves the changed discount")
	press("Enable bundle")
	expect(Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[1].enabled and not Storefront.offers_for_store(app.sim.state, offer_store_id, 4)[2].enabled, "Enabling the Bundle disables the Upsell")
	await settle("phase2-market")

	press("Order")
	var choices := controls(app, "OptionButton")
	select(choices[0], 3)
	press("Edit Dispatch Settings")
	choices = controls(app, "OptionButton")
	select(choices[1], 0)
	select(choices[2], 1)
	press("Save Changes")
	expect(app.sim.state.shipping == 0 and not app.sim.state.auto_dispatch, "Fulfillment saves method and processing mode")
	select(choices[0], 0)
	press("Dashboard")
	await confirm_advance(7)
	await confirm_advance(7)
	press("Order")
	expect(has_label("Awaiting dispatch"), "Manual orders appear in the tracking queue")
	select(controls(app, "OptionButton")[1], 1)
	if app.sim.state.active_orders.is_empty():
		quit(1)
		return
	var oldest: int = app.sim.state.active_orders.front()
	var last_page := floori((app.sim.state.active_orders.size() - 1) / 5.0)
	for i in range(last_page):
		press("Older")
	expect(app.order_page == last_page, "Order tracking can page through earlier orders")
	# Dispatch a visible oldest-page order after its promised delivery date.
	expect(app.sim.state.orders[oldest].promise < app.sim.state.day, "Old orders retain the checkout promise")
	await settle("phase2-fulfillment")
	press("Dispatch order")
	var shipped := 0
	for order in app.sim.state.orders.values():
		if order.status == "shipped":
			shipped = order.id
	expect(shipped > 0, "Dispatch control changes the order status")
	if shipped == 0:
		quit(1)
		return
	var tracked: Dictionary = app.sim.state.orders[shipped]
	press("Dashboard")
	await confirm_advance(7)
	press("Order")
	var tabs := controls(app, "OptionButton")
	select(tabs[0], 1)
	expect(tracked.case_status == "open", "Late simulated delivery creates a real service case")
	expect(has_label("Order #%04d" % shipped), "A delivered order can be handled from Customer service")
	await settle("phase2-service")
	press("Approve return and refund" if tracked.return_requested else "Issue refund")
	expect(tracked.refunded, "Service control completes the refund")
	expect(Slots.read_for_game(app.active_game_id, Slots.AUTOSAVE).state.orders[shipped].refunded, "Fulfillment and refunds persist across saves")
	select(controls(app, "OptionButton")[0], 2)
	expect(has_label("Checkout conversion") and has_label("Abandoned checkouts"), "Sales analytics opens")
	select(controls(app, "OptionButton")[1], 0)
	var completed_report: Dictionary = app.sim.report_completed(7)
	expect(has_label(Calendar.format(int(completed_report.start))), "Analytics window updates to completed-day dates")
	await settle("phase2-analytics")
	print("Phase 2 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
