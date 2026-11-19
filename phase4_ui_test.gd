extends "res://phase1_ui_test.gd"

const CEO = preload("res://ceo_profile.gd")
const Sim = preload("res://simulation.gd")

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
	var nav: GridContainer = app.find_child("PrimaryNavigation", true, false)
	var game_date: Label = app.find_child("GameDate", true, false)
	expect(nav != null and game_date != null and nav.get_parent() == game_date.get_parent()
		and nav.get_index() == game_date.get_index() + 1,
		"Primary navigation sits immediately after the game date in the masthead")
	_check_primary_tabs_within_viewport(Vector2i(1280, 720))
	for tab in ["Dashboard", "Market", "Order", "Business", "Finance", "Profile"]:
		expect(nav != null and controls(nav, "Button").any(func(button): return button.text == tab), "%s is present in the top navigation" % tab)
	expect(nav != null and nav.columns == 6, "Desktop shows all six primary categories in one row")
	expect(controls(app, "Button").filter(func(button): return button.text in ["Dashboard", "Market", "Order", "Business", "Finance", "Profile"]).size() == 6,
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
	app.orders_tab = 0
	app.navigate("Orders")
	expect(app.page_grid.get_child_count() == 2 and app.page_left_column.get_child_count() + app.page_right_column.get_child_count() == 3
		and app.page_left_column.get_child_count() > 0 and app.page_right_column.get_child_count() > 0,
		"Desktop content uses two populated natural-height columns without an empty grid cell")
	press("Pre-orders")
	expect(app.page_grid.get_child_count() == 0 and app.page_wide.get_child_count() == 1,
		"A single desktop content card expands to the full content width")

	press("Business")
	expect(app.page == "Business" and has_label("Owned Stores"), "Business category opens Company Profile")
	var company_subtab: Button = controls(app, "Button").filter(func(button): return button.text == "Company Profile")[0]
	var dashboard_primary: Button = controls(nav, "Button").filter(func(button): return button.text == "Dashboard")[0]
	expect(company_subtab.custom_minimum_size.y == 44 and dashboard_primary.custom_minimum_size.y == app.TOUCH_HEIGHT
		and company_subtab.get_theme_font_size("font_size") < dashboard_primary.get_theme_font_size("font_size"),
		"Secondary navigation is visually smaller than primary tabs while keeping a 44 px touch target")
	press("Advertising")
	expect(app.page == "Advertising" and has_label("Advertising Overview"), "Business secondary route opens Advertising")
	press("Campaign Manager")
	expect(app.screen == "Campaign Manager" or app.page == "Campaign Manager", "Campaign Manager remains reachable")
	press("Ads Analytics")
	expect(app.screen == "Advertising Analytics" or app.page == "Advertising Analytics", "Ads Analytics remains reachable")

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
	press("Profile")
	expect(app.page == "Profile" and has_label("CEO Profile") and has_label("Career Progression")
		and has_label("Owned Companies"), "Profile category presents identity, career, and owned companies with consistent title case")
	expect(has_label("Personal cash and net worth are not currently tracked."),
		"Profile explains that personal finance is not tracked and separates it from company accounts")
	expect(controls(app, "LineEdit").is_empty() and has_button("Edit Profile"),
		"Profile details are read-only until editing is explicitly activated")
	var portrait: TextureRect = app.find_child("CEOAvatar", true, false)
	expect(portrait != null and absf(portrait.custom_minimum_size.y / portrait.custom_minimum_size.x - 4.0 / 3.0) < 0.01,
		"CEO portrait preserves the 3:4 frame on desktop")
	var existing_photo := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	existing_photo.fill(Color("#dfb777"))
	CEO.add_avatar(app.ceo_profile, "image/png", existing_photo.save_png_to_buffer())
	CEO.save_profile(app.ceo_profile)
	app.refresh_view()
	expect(not has_button("Change Photo") and not has_button("Remove Photo"),
		"Saved Profile hides photo actions until Edit Profile is selected")
	press("Edit Profile")
	expect(has_button("Change Photo") and has_button("Remove Photo"),
		"Photo replacement and removal actions appear inside Profile edit mode")
	var profile_fields := controls(app, "LineEdit")
	profile_fields[0].text = "Discarded CEO Name"
	profile_fields[0].text_changed.emit(profile_fields[0].text)
	var replacement_photo := Image.create(600, 400, false, Image.FORMAT_RGBA8)
	replacement_photo.fill(Color("#4f87bc"))
	app.open_avatar_crop(replacement_photo)
	await process_frame
	await process_frame
	expect(app.find_child("AvatarCropModal", true, false) != null and has_button("Apply Crop")
		and has_button("Reset"),
		"Photo replacement opens a centered crop dialog over the Profile edit screen")
	press("Apply Crop")
	await process_frame
	var staged_photo := str(app.ceo_profile.avatar_data)
	expect(staged_photo != "" and staged_photo != CEO.load_profile().avatar_data,
		"Apply Crop updates the edit preview without persisting before Save Profile")
	press("Cancel")
	expect(app.ceo_profile.full_name == "Kai Founder" and app.ceo_profile.avatar_data == CEO.load_profile().avatar_data
		and not has_button("Save Changes"), "Cancel restores saved identity and photo after a staged replacement")
	press("Edit Profile")
	profile_fields = controls(app, "LineEdit")
	profile_fields[0].text = "Kai Global CEO"
	profile_fields[0].text_changed.emit(profile_fields[0].text)
	app.open_avatar_crop(replacement_photo)
	await process_frame
	await process_frame
	press("Apply Crop")
	await process_frame
	press("Save Changes")
	expect(app.ceo_profile.full_name == "Kai Global CEO" and app.sim.state.owner == "Kai Global CEO"
		and CEO.load_profile().full_name == "Kai Global CEO" and CEO.load_profile().avatar_data == app.ceo_profile.avatar_data,
		"Saving Profile persists edited identity and a replacement photo")
	var retained_photo := str(app.ceo_profile.avatar_data)
	press("Edit Profile")
	press("Remove Photo")
	expect(str(app.ceo_profile.avatar_data).is_empty(), "Remove Photo stages a reversible change while editing")
	press("Cancel")
	expect(str(app.ceo_profile.avatar_data) == retained_photo and CEO.load_profile().avatar_data == retained_photo,
		"Cancel restores the previously saved CEO photo")
	press("Edit Profile")
	press("Remove Photo")
	press("Save Changes")
	expect(str(app.ceo_profile.avatar_data).is_empty() and CEO.load_profile().avatar_data.is_empty(),
		"Saving Profile commits photo removal")
	CEO.add_avatar(app.ceo_profile, "image/png", existing_photo.save_png_to_buffer())
	CEO.save_profile(app.ceo_profile)
	var first_company_id := str(app.sim.state.company_id)
	var second_company := Sim.register("Kai Global CEO", "Harbor Digital", "", 1, 1, 0, 9123)
	app.ceo_profile = CEO.register_company(app.ceo_profile, second_company)
	expect(Saves.save(second_company, CEO.company_path(second_company.company_id), 2.0) == OK
		and CEO.save_profile(app.ceo_profile) == OK, "Second company save is linked without changing the current business")
	app.navigate("Profile")
	var switch_buttons := controls(app, "Button").filter(func(button): return button.text == "Switch")
	expect(switch_buttons.size() == 1, "Profile offers company switching for the other owned company")
	if switch_buttons.size() == 1:
		switch_buttons[0].pressed.emit()
		expect(str(app.sim.state.company_id) == str(second_company.company_id)
			and app.sim.state.company == "Harbor Digital" and app.ceo_profile.full_name == "Kai Global CEO",
			"Company switching restores a separate save and keeps CEO progression linked")
		app.navigate("Profile")
		switch_buttons = controls(app, "Button").filter(func(button): return button.text == "Switch")
		if switch_buttons.size() == 1:
			switch_buttons[0].pressed.emit()
		expect(str(app.sim.state.company_id) == first_company_id and app.sim.state.company == "Harbor Works",
			"Switching back restores the original company and its store history")

	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	app.navigate("Profile")
	var mobile_current_labels := controls(app, "Label").filter(func(node): return node.text == "Current Company")
	var ceo_avatar := app.find_child("CEOAvatar", true, false) as TextureRect
	expect(mobile_current_labels.size() == 1 and mobile_current_labels[0].get_parent() is VBoxContainer,
		"Mobile owned-company rows stack the company name and current status without narrow wrapping")
	expect(ceo_avatar != null and ceo_avatar.custom_minimum_size.x >= 190.0
		and absf(ceo_avatar.custom_minimum_size.y / ceo_avatar.custom_minimum_size.x - 4.0 / 3.0) < 0.01
		and ceo_avatar.size_flags_horizontal == Control.SIZE_SHRINK_CENTER,
		"CEO avatar keeps its centered portrait aspect ratio on mobile")
	for target in ["Dashboard", "Market", "Order", "Business", "Finance", "Profile"]:
		press(target)
		expect(app.primary_category(app.page) == target or (target == "Order" and app.primary_category(app.page) == "Order"),
			"Mobile navigation opens %s" % target)
	for viewport in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(768, 1024), Vector2i(390, 844), Vector2i(375, 812)]:
		root.size = viewport
		await settle("phase4-%dx%d" % [viewport.x, viewport.y])
		_check_primary_tabs_within_viewport(viewport)
		expect(app.page_grid.columns == (2 if viewport.x >= 900 else 1),
			"Page panels use the intended responsive column count at %dx%d" % [viewport.x, viewport.y])
		var expected_grid_children: int = 0 if viewport.x >= 900 and app.page_cards.size() == 1 else (2 if viewport.x >= 900 else app.page_cards.size())
		expect(app.page_grid.get_child_count() == expected_grid_children,
			"Card layout reflows without unused columns at %dx%d" % [viewport.x, viewport.y])
		press("Dashboard")
		var kpis: GridContainer = app.find_child("DashboardKpis", true, false)
		expect(kpis != null and kpis.columns == (4 if viewport.x >= 900 else 2),
			"Dashboard KPI cards use the intended responsive columns at %dx%d" % [viewport.x, viewport.y])
		_check_primary_tabs_within_viewport(viewport)
		var shell_bounds: Rect2 = app.page_shell.get_global_rect()
		var scale_x: float = float(viewport.x) / app.get_viewport_rect().size.x
		expect(shell_bounds.position.x * scale_x >= 0 and shell_bounds.end.x * scale_x <= float(viewport.x) + 1.0,
			"Centered content shell fits %dx%d" % [viewport.x, viewport.y])
	app.navigate("Profile")
	press("Edit Profile")
	app.open_avatar_crop(replacement_photo)
	await process_frame
	await process_frame
	var mobile_modal: Control = app.find_child("AvatarCropModal", true, false)
	var mobile_crop: Control = app.find_child("AvatarCropViewport", true, false)
	var mobile_actions: Array = controls(mobile_modal, "Button") if mobile_modal != null else []
	var crop_actions_fit := mobile_actions.filter(func(button): return button.text in ["Cancel", "Reset", "Apply Crop"]).all(
		func(button): return button.get_global_rect().position.y >= 0 and button.get_global_rect().end.y <= root.size.y)
	expect(mobile_modal != null and mobile_crop != null and mobile_crop.custom_minimum_size.x <= 220.0
		and crop_actions_fit, "Mobile crop dialog fits its 3:4 editor and Cancel, Reset, and Apply Crop controls")
	var modal_cancel: Variant = mobile_actions.filter(func(button): return button.text == "Cancel").back()
	if modal_cancel != null: modal_cancel.pressed.emit()
	press("Cancel")
	print("Phase 4 navigation and Management UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_primary_tabs_within_viewport(viewport: Vector2i) -> void:
	var nav: Control = app.find_child("PrimaryNavigation", true, false)
	if nav == null:
		expect(false, "Primary navigation remains present at %dx%d" % [viewport.x, viewport.y])
		return
	var button_count := 0
	var scale_x: float = float(viewport.x) / app.get_viewport_rect().size.x
	for item in controls(nav, "Button"):
		var button: Button = item
		var button_bounds: Rect2 = button.get_global_rect()
		button_count += 1
		expect(button_bounds.position.x * scale_x >= 0 and button_bounds.end.x * scale_x <= float(viewport.x) + 1.0,
			"%s remains reachable within the viewport" % button.text)
	expect(button_count == 6, "All six primary tabs remain present without requiring horizontal scrolling")
