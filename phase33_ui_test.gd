extends "res://phase1_ui_test.gd"

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run Phase 3.3 UI checks with a fresh isolated profile.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	press("New Game")
	var fields := controls(app, "LineEdit")
	fields[0].text = "Nora Founder"
	fields[1].text = "Northstar Goods"
	press("Register company")
	expect(app.sim.state.stores.is_empty(), "New company starts with no marketplace stores or websites")
	expect(app.sim.report(app.sim.state.day).closing_cash == app.sim.state.cash, "Dashboard Bank Balance uses the reconciled cash ledger balance")
	var primary_names := ["Dashboard", "Market", "Order", "Business", "Finance"]
	var nav_names: Array[String] = []
	for button in controls(app, "Button"):
		if button.text in primary_names: nav_names.append(button.text)
	expect(nav_names.size() == 5, "Game navigation presents all five primary categories")
	for button in controls(app, "Button"):
		if button.text in primary_names:
			expect(button.custom_minimum_size.y == app.TOUCH_HEIGHT, "Primary navigation uses the shared touch target height")
	press("Market")
	expect(has_label("Product Catalogue") and has_label("Supplier quotation"), "Market exposes catalog and supplier purchasing")
	var category_button: MenuButton = controls(app, "MenuButton")[0]
	category_button.get_popup().id_pressed.emit(0)
	var search: LineEdit = field_for_label("Search products")
	search.text = "Wireless Earbuds"
	search.text_changed.emit(search.text)
	var product_picker: OptionButton = controls(app, "OptionButton")[0]
	expect(product_picker.item_count == 1 and product_picker.get_item_text(0) == "Wireless Earbuds · Electronics",
		"Category and text filters isolate the expected catalog product")
	await settle("phase33-mobile-market")
	press("Order")
	expect(app.page == "Orders" and has_label("Store operations"), "Order opens the existing fulfillment workspace")
	press("Pre-orders")
	expect(has_label("No customer pre-orders yet"), "Pre-orders route has a clear empty state")
	press("Business")
	expect(app.page == "Business" and has_label("Owned stores"), "Business opens the company profile")
	press("Advertising Analytics")
	expect(has_label("Reporting Period") and has_label("Advertising Platform") and has_label("Campaign Status")
		and has_label("Destination"), "Advertising analytics explains each filter")
	var filters := controls(app, "OptionButton")
	select(filters[0], 1)
	expect(app.ad_period == 1, "Last 7 Days reporting filter changes the period")
	filters = controls(app, "OptionButton")
	select(filters[1], 1)
	expect(app.ad_platform_filter == 0, "Advertising platform filter selects Meta Ads")
	filters = controls(app, "OptionButton")
	select(filters[2], 4)
	expect(app.ad_status_filter == 3 and has_label("No campaigns match these filters"), "Status filters update analytics and retain a helpful empty state")
	press("Finance")
	expect(app.page == "Finance" and has_label("Income Statement"), "Finance opens the Income Statement")
	filters = controls(app, "OptionButton")
	select(filters[1], 1)
	expect(has_label("Balance Sheet"), "Finance opens the Balance Sheet")
	filters = controls(app, "OptionButton")
	select(filters[1], 2)
	expect(has_label("Cash Flow Statement"), "Finance opens the Cash Flow Statement")
	press("Store Profitability")
	expect(has_label("No stores or websites have been created yet"), "Store Profitability has a clear empty state")
	print("Phase 3.3 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
