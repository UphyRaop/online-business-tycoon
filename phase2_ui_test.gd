extends "res://phase1_ui_test.gd"

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run the UI test with OBT_ISOLATED_TEST_PROFILE=1 and a fresh APPDATA folder.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	press("New Game")
	var inputs := controls(app, "LineEdit")
	inputs[0].text = "Mira Founder"
	inputs[1].text = "Aster Labs"
	press("Register company")
	app.sim.state.seed = 153
	press("Market")
	var choices := controls(app, "OptionButton")
	select(choices[1], 2)
	press("Use forecast quantity")
	inputs = controls(app, "LineEdit")
	expect(inputs[0].text.to_int() > 0, "Forecast fills the quantity field")
	inputs[0].text = "20"
	inputs[0].text_changed.emit("20")
	press("Negotiate quote")
	expect(has_label("Negotiated quote received.") and has_label("MYR 36.48 per unit"), "Negotiation updates the selected quotation")
	press("Purchase stock")
	expect(has_label("PO-0001") and has_label("0 available · 20 inbound"), "Purchase updates forecast and inbound tracking")
	press("Publish listing")
	choices = controls(app, "OptionButton")
	select(choices[0], 4)
	choices = controls(app, "OptionButton")
	select(choices[1], 2)
	inputs = controls(app, "LineEdit")
	inputs[0].text = "20"
	press("Purchase stock")
	press("Publish listing")
	choices = controls(app, "OptionButton")
	select(choices[3], 0)
	press("Save bundle")
	expect(app.sim.state.offers[4].has(1), "Market saves a bundle")
	press("Save upsell")
	expect(app.sim.state.offers[4].has(1) and app.sim.state.offers[4].has(2), "Market saves an upsell independently")
	press("Disable bundle")
	expect(not app.sim.state.offers[4][1].enabled and app.sim.state.offers[4][2].enabled, "Disable one offer while keeping the other enabled")
	press("Enable bundle")
	expect(app.sim.state.offers[4][1].enabled, "Re-enable the saved bundle")
	await settle("phase2-market")

	press("Orders")
	choices = controls(app, "OptionButton")
	select(choices[0], 3)
	choices = controls(app, "OptionButton")
	select(choices[1], 0)
	select(choices[2], 1)
	press("Save dispatch settings")
	expect(app.sim.state.shipping == 0 and not app.sim.state.auto_dispatch, "Fulfillment saves method and processing mode")
	select(choices[0], 0)
	press("Dashboard")
	press("+7")
	press("+7")
	press("Orders")
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
	press("+7")
	press("Orders")
	var tabs := controls(app, "OptionButton")
	select(tabs[0], 1)
	expect(tracked.case_status == "open", "Late simulated delivery creates a real service case")
	expect(has_label("Order #%04d" % shipped), "A delivered order can be handled from Customer service")
	await settle("phase2-service")
	press("Approve return and refund" if tracked.return_requested else "Issue refund")
	expect(tracked.refunded, "Service control completes the refund")
	expect(Slots.read(Slots.AUTOSAVE).state.orders[shipped].refunded, "Fulfillment and refunds persist across saves")
	select(controls(app, "OptionButton")[0], 2)
	expect(has_label("Checkout conversion") and has_label("Abandoned checkouts"), "Sales analytics opens")
	select(controls(app, "OptionButton")[1], 0)
	expect(has_label("Fri, 16 Jan 2026"), "Analytics window updates")
	await settle("phase2-analytics")
	print("Phase 2 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
