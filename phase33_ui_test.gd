extends "res://phase1_ui_test.gd"

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run Phase 3.3 UI checks with a fresh isolated profile.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	create_new_game_for_test("Nora Founder", "Northstar Goods")
	var fields := controls(app, "LineEdit")
	expect(app.sim.state.stores.is_empty(), "New company starts with no marketplace stores or websites")
	expect(app.sim.report(app.sim.state.day).closing_cash == app.sim.state.cash, "Dashboard Bank Balance uses the reconciled cash ledger balance")
	var primary_names := ["Dashboard", "Market", "Order", "Business", "Marketing", "Finance", "Profile"]
	var menu: Button = app.find_child("NavigationMenuButton", true, false)
	if menu != null: menu.pressed.emit()
	await process_frame
	var drawer: Control = app.find_child("PrimaryNavigation", true, false)
	expect(drawer != null and drawer.is_visible_in_tree(), "Hamburger button opens the primary navigation drawer")
	var nav_names: Array[String] = []
	if drawer != null:
		for button in controls(drawer, "Button"):
			if button.tooltip_text in primary_names: nav_names.append(button.tooltip_text)
	expect(nav_names.size() == 7 and "Profile" in nav_names and "Marketing" in nav_names,
		"Hamburger navigation presents all seven primary categories including Marketing and Profile")
	if drawer != null:
		for button in controls(drawer, "Button"):
			if button.tooltip_text in primary_names:
				expect(button.custom_minimum_size.y >= 44.0,
					"Primary navigation uses a compact touch target of at least 44 px")
	press("Market")
	await process_frame
	await process_frame
	expect(has_label("Product Catalogue") and controls(app, "Button").any(func(button): return button.text == "Request Quotation" and button.is_visible_in_tree()), "Market exposes product catalog and supplier quotation actions")
	var search_panel: Control = app.find_child("ProductSearchPanel", true, false)
	var catalogue: Control = app.find_child("ProductCataloguePanel", true, false)
	expect(search_panel != null and catalogue != null and search_panel.get_global_rect().position.y < catalogue.get_global_rect().position.y
		and field_for_label("Search Product") != null,
		"Search Product is immediately above Product Catalogue")
	expect(has_label("Return Inventory to Supplier") and has_label("No unreserved purchased stock is eligible to return."),
		"Supplier return controls appear in inventory management with a safe empty state")
	var category_button: OptionButton = app.find_child("ProductCategorySelection", true, false)
	select(category_button, 1)
	var search: LineEdit = field_for_label("Search Product")
	search.text = "Wireless Earbuds"
	search.text_changed.emit(search.text)
	var product_picker: OptionButton = app.find_child("ProductSelection", true, false)
	expect(product_picker.item_count == 1 and product_picker.get_item_text(0) == "Wireless Earbuds · Electronics",
		"Category and text filters isolate the expected catalog product")
	select(product_picker, 0)
	category_button = app.find_child("ProductCategorySelection", true, false)
	search = field_for_label("Search Product")
	product_picker = app.find_child("ProductSelection", true, false)
	expect(category_button.get_item_text(category_button.selected) == "Electronics" and has_label("Select Product")
		and has_label("Electronics"), "Selected category, product selection, and product details have a clear hierarchy")
	search.text = "no-such-product"
	search.text_changed.emit(search.text)
	expect(product_picker.disabled and has_label("No products match this category and search. Choose another category or clear the search."),
		"Product catalog shows a useful empty state when filters match no products")
	search.text = "Wireless Earbuds"
	search.text_changed.emit(search.text)
	await settle("phase33-mobile-market")
	press("Order")
	expect(app.page == "Orders" and has_label("Store operations"), "Order opens the existing fulfillment workspace")
	press("Pre-orders")
	expect(has_label("No customer pre-orders yet"), "Pre-orders route has a clear empty state")
	press("Business")
	expect(app.page == "Business" and has_label("Owned Stores"), "Business opens the company profile")
	press("Ads Analytics")
	expect(has_label("Reporting Period") and has_label("Advertising Platform") and has_label("Campaign Status")
		and has_label("Destination"), "Ads Analytics explains each filter")
	var filters := controls(app, "OptionButton")
	expect(filters.size() >= 3 and filters[2].get_item_text(0) == "All Status",
		"Campaign status dropdown uses the revised All Status label")
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
