extends "res://phase1_ui_test.gd"

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Stores = preload("res://store_manager.gd")

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run the Phase 3 UI test with OBT_ISOLATED_TEST_PROFILE=1 and a fresh APPDATA folder.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	press("New Game")
	var inputs := controls(app, "LineEdit")
	inputs[0].text = "Mira Founder"
	inputs[1].text = "Aster Labs"
	inputs[2].text = "Aster Market"
	press("Register company")
	expect(app.sim.state.stores.is_empty(), "Registration creates no stores")
	expect(has_label("Mira Founder, CEO"), "Dashboard shows the registered entrepreneur")
	expect(Stores.create(app.sim.state, "Aster Marketplace", 0, "Aster") == "", "Company opens a free marketplace")
	app.sim.state.seed = 811
	var stock_result: String = app.sim.buy(0, 2, 40)
	expect(stock_result.is_empty(), "UI fixture obtains stock through the supplier system")
	for batch in app.sim.state.inbound:
		batch.eta = app.sim.state.day
		batch.arrival = app.sim.state.day
	Supply.receive(app.sim)
	expect(Stores.set_listing(app.sim.state, 2, 0, 9500, true).is_empty(), "UI fixture publishes a store listing")

	press("Growth")
	expect(has_label("Advertising Overview"), "Growth tab opens the advertising overview")
	await settle("phase3-growth")
	press("Campaign Manager")
	expect(has_label("Campaign Manager"), "Overview opens the campaign manager")
	press("Create campaign")
	inputs = controls(app, "LineEdit")
	expect(inputs.size() >= 5, "Campaign detail form exposes its configuration fields")
	inputs[0].text = "Portrait launch"
	inputs[1].text = "25"
	press("Create campaign")
	expect(app.sim.state.advertising.campaigns.size() == 1, "Campaign form creates a saved campaign")
	await settle("phase3-manager")
	press("Manage campaign")
	expect(has_label("Portrait launch"), "Manager opens the selected campaign details")
	press("Pause")
	expect(app.sim.state.advertising.campaigns[1].status == "paused", "Campaign pause button changes campaign state")
	press("Resume")
	expect(app.sim.state.advertising.campaigns[1].status == "active", "Campaign resume button changes campaign state")
	app.sim.advance(8)
	press("Advertising Analytics")
	expect(has_label("Advertising Analytics"), "Campaign details opens advertising analytics")
	press("Previous")
	press("Next")
	expect(has_label("Campaigns compared") and has_label("Portrait launch") and has_label("CPM"), "Analytics renders campaign comparisons and complete cost metrics")
	select(controls(app, "OptionButton").back(), 2)
	expect(not has_label("Portrait launch"), "Campaign status filter removes active campaigns when Paused is selected")
	select(controls(app, "OptionButton").back(), 0)
	expect(has_label("Portrait launch"), "Campaign status filter restores the all-status comparison")
	await settle("phase3-analytics")
	press("Growth")
	press("Store Management")
	expect(has_label("Owned stores"), "Growth opens multi-store management")
	expect(app.sim.state.owner == "Mira Founder" and app.sim.state.company == "Aster Labs", "Entrepreneur and company are independent")
	press("Business")
	inputs = controls(app, "LineEdit")
	var identity_field: LineEdit = inputs.filter(func(entry): return entry.name == "EntrepreneurName")[0]
	identity_field.text = "Mira Rouf"
	press("Save entrepreneur name")
	expect(app.sim.state.owner == "Mira Rouf" and app.sim.state.company == "Aster Labs", "CEO name can be edited independently")
	press("Dashboard")
	expect(has_label("Mira Rouf, CEO"), "Dashboard shows the CEO title")
	app.persist("Save identity test.")
	var saved_identity := Slots.read(Slots.AUTOSAVE)
	expect(saved_identity.state.owner == "Mira Rouf", "Autosave preserves entrepreneur name")
	saved_identity.state.owner = ""
	Saves.save(saved_identity.state, Slots.path_for(Slots.AUTOSAVE), saved_identity.saved_at)
	var migrated_identity := Slots.read(Slots.AUTOSAVE)
	expect(migrated_identity.state.owner == "", "Legacy save does not invent an entrepreneur name")
	app.request_load(migrated_identity)
	if is_instance_valid(app.confirmation):
		app.confirmation.confirmed.emit()
	expect(app.screen == "Entrepreneur name", "Legacy save requests entrepreneur name")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Mira Rouf"
	press("Save and continue")
	expect(app.sim.state.owner == "Mira Rouf" and app.sim.state.company == "Aster Labs", "Legacy identity migration preserves progress")
	press("Growth")
	press("Store Management")
	press("Create Store")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Direct"
	inputs[1].text = "Aster Brand"
	inputs[2].text = "direct.aster.shop"
	select(controls(app, "OptionButton")[0], 1)
	press("Create store")
	app.confirmation.confirmed.emit()
	expect(app.sim.state.stores.size() == 2 and app.sim.state.stores[1].domain == "direct.aster.shop",
		"Store form creates an own website with its configured domain")
	await settle("phase3-stores")
	var manage_buttons := controls(app, "Button").filter(func(button): return button.text == "Manage listings")
	if not manage_buttons.is_empty():
		manage_buttons.back().pressed.emit()
	else:
		expect(false, "Created store exposes its Manage listings control")
	expect(has_label("Aster Direct · Product listings"), "Store management opens store-specific product listings")
	await settle("phase3-store-listings")
	expect(Slots.latest().state.advertising.campaigns.size() == 1 and Slots.latest().state.stores.size() == 2,
		"Campaign and additional store persist through autosave")
	print("Phase 3 UI (390 × 844): %d failures" % failures)
	quit(0 if failures == 0 else 1)
