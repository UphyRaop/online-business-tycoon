extends "res://phase1_ui_test.gd"

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run Phase 4 navigation checks with a fresh isolated profile.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	app = Main.instantiate()
	root.add_child(app)
	press("New Game")
	var fields := controls(app, "LineEdit")
	fields[0].text = "Kai Founder"
	fields[1].text = "Harbor Works"
	press("Register company")
	await process_frame
	var nav: FlowContainer = app.find_child("PrimaryNavigation", true, false)
	var game_date: Label = app.find_child("GameDate", true, false)
	expect(nav != null and game_date != null and nav.get_parent() == game_date.get_parent()
		and nav.get_index() == game_date.get_index() + 1,
		"Primary navigation sits immediately after the game date in the masthead")
	_check_primary_tabs_within_viewport(Vector2i(1280, 720))
	for tab in ["Dashboard", "Market", "Order", "Business", "Finance"]:
		expect(nav != null and controls(nav, "Button").any(func(button): return button.text == tab), "%s is present in the top navigation" % tab)
	expect(controls(app, "Button").filter(func(button): return button.text in ["Dashboard", "Market", "Order", "Business", "Finance"]).size() == 5,
		"There is one primary navigation set; no bottom duplicate remains")

	press("Dashboard")
	expect(app.page == "Dashboard" and has_label("Business Alerts"), "Dashboard category works")
	press("Market")
	expect(app.page == "Market" and has_label("Product Catalogue"), "Market category opens Product Catalogue")
	press("My Products")
	expect(app.page == "My Products" and has_label("Product portfolio"), "Market secondary route opens My Products")
	press("Management")
	expect(app.page == "Management" and has_label("Owned stores · 0"), "Management is available under Market")

	var marketplace_error := Stores.create(app.sim.state, "Harbor Marketplace", 0, "Harbor", "", 0)
	var marketplace_id := int(app.sim.state.stores.back().id)
	var website_error := Stores.create(app.sim.state, "Harbor Website", 1, "Harbor", "harbor.example.test", 0, 1)
	var website_id := int(app.sim.state.stores.back().id)
	expect(marketplace_error.is_empty() and website_error.is_empty(), "Management retains marketplace and paid website creation")
	app.refresh_view()
	expect(has_label("Harbor Marketplace") and has_label("Harbor Website") and has_label("WooCommerce · harbor.example.test"),
		"Management lists existing marketplace and website details")
	expect(Stores.get_store(app.sim.state, marketplace_id).type == 0 and Stores.get_store(app.sim.state, website_id).type == 1,
		"Management preserves destination types and IDs")
	app.navigate("Store Management")
	expect(app.page == "Management", "Legacy Store Management navigation safely redirects to Management")
	app.selected_store_id = marketplace_id
	press("Product Listings")
	expect(app.page == "Store Listings" and has_label("Harbor Marketplace · Product listings"),
		"Market Product Listings still opens the selected marketplace destination")
	app.navigate("Management")
	var listing_actions := controls(app, "Button").filter(func(button): return button.text == "Manage Listings")
	expect(listing_actions.size() == 2, "Marketplace and website destinations both expose listing management")
	if listing_actions.size() == 2:
		listing_actions[1].pressed.emit()
		expect(app.page == "Store Listings" and app.selected_store_id == website_id
			and has_label("Harbor Website · Product listings"), "Website listings open through Management with the website ID")
	app.navigate("Management")
	var deactivate_actions := controls(app, "Button").filter(func(button): return button.text == "Deactivate")
	expect(deactivate_actions.size() == 2, "Management exposes activation controls for both destinations")
	for store_id in [marketplace_id, website_id]:
		app.navigate("Management")
		var store_index := Stores.index_of(app.sim.state, store_id)
		var status_buttons := controls(app, "Button").filter(func(button): return button.text in ["Deactivate", "Activate"])
		if store_index >= 0 and store_index < status_buttons.size() and status_buttons[store_index].text == "Deactivate":
			status_buttons[store_index].pressed.emit()
		expect(not Stores.get_store(app.sim.state, store_id).active, "Management deactivates destination %d" % store_id)
		app.navigate("Management")
		status_buttons = controls(app, "Button").filter(func(button): return button.text in ["Deactivate", "Activate"])
		if store_index >= 0 and store_index < status_buttons.size() and status_buttons[store_index].text == "Activate":
			status_buttons[store_index].pressed.emit()
		expect(Stores.get_store(app.sim.state, store_id).active, "Management reactivates destination %d" % store_id)

	press("Order")
	expect(app.page == "Orders" and has_label("Store operations"), "Order category opens customer orders")
	press("Pre-orders")
	expect(app.page == "Pre-orders" and has_label("Pre-orders"), "Order secondary route opens pre-order management")
	press("Returns and Service")
	expect(app.page == "Orders" and app.orders_tab == 1, "Returns and Service retains the existing customer-service screen")

	press("Business")
	expect(app.page == "Business" and has_label("Owned stores"), "Business category opens Company Profile")
	press("Advertising")
	expect(app.page == "Advertising" and has_label("Advertising Overview"), "Business secondary route opens Advertising")
	press("Campaign Manager")
	expect(app.screen == "Campaign Manager" or app.page == "Campaign Manager", "Campaign Manager remains reachable")
	press("Advertising Analytics")
	expect(app.screen == "Advertising Analytics" or app.page == "Advertising Analytics", "Advertising Analytics remains reachable")

	press("Finance")
	expect(app.page == "Finance" and has_label("Income Statement"), "Finance category opens statements")
	press("Store Profitability")
	expect(app.page == "Store Profitability" and has_label("Harbor Marketplace") and has_label("Harbor Website"),
		"Finance Store Profitability reports marketplace and website results")

	var stored := Slots.write(1, app.sim.state)
	var loaded := Slots.read(1)
	expect(stored == OK and Saves.valid(loaded.get("state", {})), "Save/load remains valid with both destination types")
	var loaded_stores: Array = loaded.get("state", {}).get("stores", [])
	expect(loaded_stores.size() == 2 and int(loaded_stores[0].id) == marketplace_id
		and int(loaded_stores[1].id) == website_id and str(loaded_stores[1].domain) == "harbor.example.test",
		"Save/load preserves marketplace and website IDs and website details")
	Slots.delete_slot(1)

	root.size = Vector2i(390, 844)
	await settle("phase4-mobile-top-navigation")
	_check_primary_tabs_within_viewport(Vector2i(390, 844))
	for target in ["Dashboard", "Market", "Order", "Business", "Finance"]:
		press(target)
		expect(app.primary_category(app.page) == target or (target == "Order" and app.primary_category(app.page) == "Order"),
			"Mobile navigation opens %s" % target)
	print("Phase 4 navigation and Management UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_primary_tabs_within_viewport(viewport: Vector2i) -> void:
	var nav: Control = app.find_child("PrimaryNavigation", true, false)
	if nav == null:
		expect(false, "Primary navigation remains present at %dx%d" % [viewport.x, viewport.y])
		return
	var button_count := 0
	for item in controls(nav, "Button"):
		var button: Button = item
		var button_bounds: Rect2 = button.get_global_rect()
		button_count += 1
		expect(button_bounds.position.x >= 0 and button_bounds.end.x <= float(viewport.x) + 1.0,
			"%s remains reachable within the viewport" % button.text)
	expect(button_count == 5, "All five primary tabs remain present without requiring horizontal scrolling")
