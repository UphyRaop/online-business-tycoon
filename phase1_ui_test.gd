extends SceneTree

const Main = preload("res://main.tscn")
const Saves = preload("res://save_store.gd")
const Slots = preload("res://save_slots.gd")
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
		if button.text == title and not button.disabled:
			button.pressed.emit()
			return
	expect(false, "Missing enabled button " + title)

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
	inputs[2].text = "Aster Shop"
	var choices := controls(app, "OptionButton")
	select(choices[0], 4)
	select(choices[1], 2)
	select(choices[2], 2)
	press("Register company")
	expect(app.sim.state.country == 4 and app.sim.state.difficulty == 2, "Registration saves choices")
	await settle("02-dashboard")
	press("Browse product catalog")
	choices = controls(app, "OptionButton")
	select(choices[0], 1)
	choices = controls(app, "OptionButton")
	select(choices[1], 0)
	expect(has_label("Minimum 5 ·"), "Changing supplier exposes quotation terms")
	await settle("03-market")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "1"
	press("Purchase stock")
	expect(has_label("Enter a quantity"), "Purchase validation displays")
	inputs[0].text = "10"
	press("Purchase stock")
	expect(app.sim.stock(1) == 0 and app.sim.state.inbound[0].units == 10, "Purchase button schedules inbound stock")
	press("Publish listing")
	expect(app.sim.product_state(1).listed, "Publish button activates listing")
	inputs = controls(app, "LineEdit")
	inputs[1].text = "250000"
	press("Update listing")
	expect(app.sim.product_state(1).price == 25000000, "Price updates")
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
	expect(has_label("Marketplace charges 12%"), "Channel terms render")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Holdings"
	inputs[1].text = "Aster Brand"
	inputs[2].text = "Aster Store"
	inputs[3].text = "aster.example"
	press("Save names")
	select(controls(app, "OptionButton")[1], 0)
	press("Save channels")
	expect(app.sim.state.channel == 0, "Business channel choice saves")
	select(controls(app, "OptionButton")[0], 1)
	press("Save names")
	expect(app.sim.state.website_active and app.sim.state.channel == 0 and app.sim.channel_enabled(1), "Website channel can be enabled independently")
	press("Save Game")
	press("Save to slot 1")
	press("Back")
	press("Load Game")
	press("Load slot 1")
	expect(app.sim.state.company == "Aster Holdings" and app.sim.state.brand == "Aster Brand" and app.sim.state.store == "Aster Store" and app.sim.state.website_domain == "aster.example", "Local load restores business identities")
	press("Business")
	await settle("06-business")
	press("My Products")
	press("Manage Wireless Earbuds")
	press("Pause listing")
	expect(not app.sim.product_state(1).listed, "Pause listing button")
	var saved := Slots.read(Slots.AUTOSAVE)
	expect(saved.state.day == 41 and not saved.state.products[1].listed, "Mutations autosave")
	app.queue_free()
	await process_frame
	app = Main.instantiate()
	root.add_child(app)
	press("Continue Game")
	expect(app.sim.state.day == 41 and app.sim.state.store == "Aster Store", "The game resumes on launch")
	print("Phase 1 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
