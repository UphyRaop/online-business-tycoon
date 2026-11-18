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
		if button.text == title and not button.disabled and button.is_visible_in_tree():
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
	press("Manage stores")
	var listings := controls(app, "Button").filter(func(button): return button.text == "Manage listings")
	if listings.is_empty():
		expect(false, "Store Management exposes per-store listings")
		return
	listings[0].pressed.emit()

func select(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)

func has_label(prefix: String) -> bool:
	for node in controls(app, "Label"):
		if node.text.begins_with(prefix):
			return true
	return false

func settle(name: String) -> void:
	await process_frame
	await process_frame
	for scroll in controls(app, "ScrollContainer"):
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
	press("Register company")
	expect(has_label("Enter an entrepreneur"), "Registration validates required names")
	var inputs := controls(app, "LineEdit")
	inputs[0].text = "Mira Founder"
	inputs[1].text = "Aster Labs"
	var choices := controls(app, "OptionButton")
	select(choices[0], 4)
	select(choices[1], 2)
	press("Register company")
	expect(app.sim.state.country == 4 and app.sim.state.difficulty == 2, "Registration saves choices")
	# Legacy Phase 1 sales-flow fixture explicitly creates its two channel stores.
	app.sim.state.stores = Stores.migration_defaults(app.sim.state)
	app.sim.state.website_active = true

	await settle("02-dashboard")
	press("Browse product catalog")
	choices = controls(app, "OptionButton")
	select(choices[0], 1)
	choices = controls(app, "OptionButton")
	select(choices[1], 0)
	expect(has_label("Minimum 1 ·"), "Changing supplier exposes quotation terms")
	await settle("03-market")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "0"
	press("Purchase stock")
	expect(has_label("Enter a quantity"), "Purchase validation displays")
	inputs[0].text = "10"
	press("Purchase stock")
	expect(app.sim.stock(1) == 0 and app.sim.state.inbound[0].units == 10, "Purchase button schedules inbound stock")
	press("Manage stores")
	var listings_buttons := controls(app, "Button").filter(func(button): return button.text == "Manage listings")
	if not listings_buttons.is_empty():
		listings_buttons[0].pressed.emit()
	else:
		expect(false, "Store Management exposes per-store listings")
	select(controls(app, "OptionButton").back(), 1)
	press("Save store listing")
	expect(Stores.listing(app.sim.state, 0, 1).listed, "Store listing is published through Store Management")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "250000"
	press("Save store listing")
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
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Mira Founder Updated"
	inputs[1].text = "Aster Holdings"
	press("Save company profile")
	expect(app.sim.state.owner == "Mira Founder Updated" and app.sim.state.company == "Aster Holdings"
		and not has_label("Website domain"), "Company Profile saves identity without exposing website controls")
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
	press("My Products")
	press("Manage Wireless Earbuds")
	press("Manage stores")
	var store_listing_buttons := controls(app, "Button").filter(func(button): return button.text == "Manage listings")
	if not store_listing_buttons.is_empty():
		store_listing_buttons[0].pressed.emit()
	else:
		expect(false, "Store listing can be paused through Store Management")
	select(controls(app, "OptionButton").back(), 0)
	press("Save store listing")
	expect(not Stores.listing(app.sim.state, 0, 1).listed, "Store listing pause action")
	var saved := Slots.read(Slots.AUTOSAVE)
	expect(saved.state.day == 41 and not Stores.listing(saved.state, 0, 1).listed, "Mutations autosave")
	app.queue_free()
	await process_frame
	app = Main.instantiate()
	root.add_child(app)
	press("Continue Game")
	expect(app.sim.state.day == 41 and app.sim.state.store.is_empty(), "The game resumes on launch")
	print("Phase 1 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
