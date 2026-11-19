extends SceneTree

const Main = preload("res://main.tscn")
const Saves = preload("res://save_store.gd")
const Slots = preload("res://save_slots.gd")
const Stores = preload("res://store_manager.gd")
var app: Control
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func controls(node: Node, type: String) -> Array:
	var matches := []
	for child in node.get_children():
		if child.is_class(type):
			matches.append(child)
		matches.append_array(controls(child, type))
	return matches

func press(title: String) -> void:
	for button in controls(app, "Button"):
		if button.text.to_lower() == title.to_lower() and not button.disabled and button.is_visible_in_tree():
			button.pressed.emit()
			return
	var primary := title.to_lower()
	var primary_target := ""
	var secondary_title := title
	var selects_secondary := false
	if primary in ["dashboard", "market", "order", "orders", "business", "marketing", "finance", "profile"]:
		primary_target = "Order" if primary in ["order", "orders"] else title
	elif primary in ["advertising", "overview", "campaign manager", "campaign management", "ads analytics"]:
		primary_target = "Marketing"
		selects_secondary = primary != "marketing"
		if primary in ["advertising", "overview"]: secondary_title = "Overview"
		if primary in ["campaign manager", "campaign management"]: secondary_title = "Campaign Management"
		if primary == "ads analytics": secondary_title = "Ads Analytics"
	elif primary in ["my products", "inventory management", "management", "store management", "product catalogue"]:
		primary_target = "Market"
		if primary in ["my products", "inventory management"]: secondary_title = "Inventory Management"
		if primary in ["management", "store management"]: secondary_title = "Store Management"
		if primary == "product catalogue": secondary_title = "Product Catalogue"
	elif primary in ["company profile", "company management"]:
		primary_target = "Business"
		secondary_title = "Company Management"
	var drawer: Control = app.find_child("PrimaryNavigation", true, false)
	var menu: Button = app.find_child("NavigationMenuButton", true, false)
	if primary in ["save game", "main menu"] and drawer != null and menu != null:
		if not drawer.is_visible_in_tree(): menu.pressed.emit()
		var action_name := "DrawerActionSave" if primary == "save game" else "DrawerActionMainMenu"
		var drawer_action: Button = drawer.find_child(action_name, true, false)
		if drawer_action != null and drawer_action.is_visible_in_tree():
			drawer_action.pressed.emit()
			return
	if primary_target in ["Dashboard", "Market", "Order", "Business", "Marketing", "Finance", "Profile"] and drawer != null and menu != null:
		if not drawer.is_visible_in_tree(): menu.pressed.emit()
		var navigation_item: Button = drawer.find_child("Primary_" + primary_target, true, false)
		if navigation_item != null and navigation_item.is_visible_in_tree():
			navigation_item.pressed.emit()
			if secondary_title == title and not selects_secondary: return
		else:
			expect(false, "Missing primary route " + primary_target)
			return
	if not secondary_title.is_empty() and (secondary_title != title or selects_secondary):
		for button in controls(app, "Button"):
			if button.text.to_lower() == secondary_title.to_lower() and button.is_visible_in_tree():
				button.pressed.emit()
				return
	expect(false, "Missing enabled button " + title)

func has_visible_label(prefix: String) -> bool:
	for node in controls(app, "Label"):
		if node.text.begins_with(prefix) and node.is_visible_in_tree(): return true
	return false

func field_for_label(prefix: String) -> LineEdit:
	for node in controls(app, "Label"):
		if not node.text.begins_with(prefix) or not node.is_visible_in_tree(): continue
		var parent: Node = node.get_parent()
		var next_index: int = node.get_index() + 1
		if next_index < parent.get_child_count() and parent.get_child(next_index) is LineEdit:
			return parent.get_child(next_index)
	return null

func option_after_label(prefix: String) -> OptionButton:
	for node in controls(app, "Label"):
		if not node.text.begins_with(prefix) or not node.is_visible_in_tree(): continue
		var parent: Node = node.get_parent()
		var next_index: int = node.get_index() + 1
		if next_index < parent.get_child_count() and parent.get_child(next_index) is OptionButton:
			return parent.get_child(next_index)
	return null

func open_first_store_listing() -> void:
	if app.sim == null or app.sim.state.stores.is_empty():
		expect(false, "Listing test fixture has a store destination")
		return
	# Keep the legacy destination screen covered without exposing it as a user
	# navigation destination; players manage listings from My Products.
	app.selected_store_id = int(app.sim.state.stores.front().id)
	app.navigate("Store Listings")

func select(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)

func has_label(prefix: String) -> bool:
	for node in controls(app, "Label"):
		if node.text.begins_with(prefix):
			return true
	return false

func has_button(title: String) -> bool:
	return controls(app, "Button").any(func(button): return button.text.to_lower() == title.to_lower() and button.is_visible_in_tree())

func create_new_game_for_test(ceo_name: String, company_name: String) -> void:
	if app.screen != "New Game": press("New Game")
	var ceo_field := field_for_label("CEO Name")
	if ceo_field != null: ceo_field.text = ceo_name
	press("Continue to Company Registration")
	var company_field := field_for_label("Company Name")
	if company_field != null: company_field.text = company_name
	press("Register company")

func settle(name: String) -> void:
	await process_frame
	await process_frame
	for scroll in controls(app, "ScrollContainer"):
		if not scroll.is_visible_in_tree(): continue
		if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: continue
		var content: Control = scroll.get_child(0)
		expect(content.get_combined_minimum_size().x <= scroll.size.x + 1, "Portrait content fits on " + name)
	var captures := OS.get_environment("OBT_UI_CAPTURE_DIR")
	if not captures.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		expect(image.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)

func run() -> void:
	# The UI writes its standard save. The launcher must supply an isolated user-data folder.
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run the UI test with OBT_ISOLATED_TEST_PROFILE=1 and a fresh APPDATA folder.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	press("New Game")
	await settle("01-registration")
	press("Continue to Company Registration")
	expect(app.notice.to_lower().contains("ceo name"), "New Game requires a CEO name before company registration")
	var inputs := controls(app, "LineEdit")
	inputs[0].text = "Mira Founder"
	press("Continue to Company Registration")
	press("Register company")
	expect(app.notice.to_lower().contains("company name"), "Company registration independently requires a company name")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Labs"
	var choices := controls(app, "OptionButton")
	select(choices[0], 4)
	select(choices[1], 2)
	press("Register company")
	expect(app.sim.state.country == 4 and app.sim.state.difficulty == 2, "Registration saves choices")
	# Legacy Phase 1 sales-flow fixture explicitly creates its two channel stores.
	app.sim.state.stores = Stores.migration_defaults(app.sim.state)
	app.sim.state.website_active = true

	await settle("02-dashboard")
	press("Browse Product Catalogue")
	choices = controls(app, "OptionButton")
	select(choices[0], 1)
	select(app.find_child("ProductSelection", true, false), 0)
	press("View Details")
	expect(has_label("Lead Time · MOQ · Maximum Order"), "Supplier details expose lead time and supplier-specific quantity limits")
	await settle("03-market")
	press("Accept Offer")
	var quantity: LineEdit = field_for_label("Purchase Quantity")
	quantity.text = "0"
	quantity.text_changed.emit("0")
	expect(has_label("Enter a quantity from"), "Purchase validation displays supplier-specific quantity limits")
	quantity = field_for_label("Purchase Quantity")
	quantity.text = "10"
	quantity.text_changed.emit("10")
	press("Purchase")
	expect(app.sim.stock(1) == 0 and app.sim.state.inbound[0].units == 10, "Purchase button schedules inbound stock")
	app.selected_store_id = int(app.sim.state.stores.front().id)
	app.selected_product = 1
	app.navigate("Store Listings")
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 1)
	press("Save Changes")
	expect(Stores.listing(app.sim.state, 0, 1).listed, "Store listing is published through Management")
	press("Edit Listing")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "250000"
	press("Save Changes")
	expect(Stores.listing(app.sim.state, 0, 1).price == 25000000, "Store-specific listing price updates")
	press("Dashboard")
	press("+1")
	expect(app.sim.state.day == 2 and app.sim.state.inbound.size() == 1, "Dashboard time advances with pending supply")
	for advance_title in ["+2", "+7", "+30"]:
		press(advance_title)
	expect(app.sim.state.day == 41, "All four time controls advance")
	expect(app.sim.state.inbound.is_empty() and app.sim.state.orders.size() > 0, "Purchases arrive and listings generate orders")
	press("Finance")
	await settle("04-income")
	for index in range(4):
		choices = controls(app, "OptionButton")
		select(choices[0], index)
		for report_type in range(3):
			select(controls(app, "OptionButton")[1], report_type)
			expect(has_label(app.STATEMENTS[report_type]), "Statement renders in period %d" % index)
	select(controls(app, "OptionButton")[0], 1)
	press("Previous")
	expect(app.report_end == 39, "Previous calendar week")
	press("Next")
	expect(app.report_end == 40, "Next calendar week")
	select(controls(app, "OptionButton")[1], 1)
	await settle("05-balance")
	press("Business")
	press("Edit Company Details")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Mira Founder Updated"
	inputs[1].text = "Aster Holdings"
	press("Save Changes")
	expect(app.sim.state.owner == "Mira Founder Updated" and app.sim.state.company == "Aster Holdings"
		and not has_label("Website Domain"), "Company Profile saves identity without exposing website controls")
	press("Save Game")
	press("Save to slot 1")
	press("Back")
	press("Load Game")
	press("Load slot 1")
	expect(app.sim.state.company == "Aster Holdings" and app.sim.state.brand == "Aster Labs"
		and app.sim.state.store.is_empty() and app.sim.state.owner == "Mira Founder Updated"
		and app.sim.state.stores.size() == 2 and app.sim.state.stores[1].domain == app.sim.state.website_domain,
		"Local load restores company identity and existing legacy website without profile-side website edits")
	press("Business")
	await settle("06-business")
	press("Market")
	press("My Products")
	press("Manage Wireless Earbuds")
	var test_store_id := int(app.sim.state.stores[0].id)
	var first_store_listing: Control = app.find_child("ProductListingStore%d" % test_store_id, true, false)
	var edit_listing_button: Button = controls(first_store_listing, "Button").filter(func(button): return button.text == "Edit Listing")[0] if first_store_listing != null else null
	if edit_listing_button != null:
		edit_listing_button.pressed.emit()
	else:
		expect(false, "My Products exposes the store-specific listing editor for the selected product")
	first_store_listing = app.find_child("ProductListingStore%d" % test_store_id, true, false)
	if first_store_listing != null:
		var listing_options := controls(first_store_listing, "OptionButton")
		if not listing_options.is_empty():
			select(listing_options[0], 0)
			var save_listing_buttons := controls(first_store_listing, "Button").filter(func(button): return button.text == "Save Listing")
			if not save_listing_buttons.is_empty(): save_listing_buttons[0].pressed.emit()
		else:
			expect(false, "Store-specific listing edit exposes listing controls")
	else:
		expect(false, "Store-specific listing editor remains visible after opening")
	expect(not Stores.listing(app.sim.state, test_store_id, 1).listed, "Store listing pause action")
	var saved := Slots.read_for_game(app.active_game_id, Slots.AUTOSAVE)
	expect(saved.state.day == 41 and not Stores.listing(saved.state, test_store_id, 1).listed, "Mutations autosave")
	app.queue_free()
	await process_frame
	app = Main.instantiate()
	root.add_child(app)
	press("Continue Game")
	expect(app.sim.state.day == 41 and app.sim.state.store.is_empty(), "The game resumes on launch")
	print("Phase 1 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
