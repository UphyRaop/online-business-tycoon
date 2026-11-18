extends "res://phase1_ui_test.gd"

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")

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
	press("Register company")
	expect(app.sim.state.stores.is_empty() and app.sim.state.store.is_empty(), "New company has no default store or store name")
	expect(not app.sim.channel_enabled(0) and not app.sim.channel_enabled(1), "Legacy channel flags do not create a marketplace or website")
	expect(has_label("Mira Founder, CEO"), "Dashboard displays the registered entrepreneur as CEO")
	press("Business")
	expect(has_label("Owned stores") and not has_label("Website domain") and not has_label("Website inactive")
		and controls(app, "OptionButton").is_empty(), "Company Profile shows zero stores and no legacy website or channel controls")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Mira Rouf Kalil"
	press("Save company profile")
	expect(app.sim.state.owner == "Mira Rouf Kalil" and app.sim.state.company == "Aster Labs", "Company Profile edits CEO identity independently")
	press("Store Management")
	expect(has_label("Owned stores · 0"), "Business opens Store Management with no default stores")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Shop"
	inputs[1].text = "Aster Brand"
	select(controls(app, "OptionButton")[0], 0)
	press("Create store")
	expect(app.sim.state.stores.size() == 1, "Marketplace creation is performed through Store Management")
	var store_id: int = app.sim.state.stores.back().id
	press("Deactivate")
	expect(not app.sim.state.stores.back().active and app.notice == "Aster Shop is now inactive.",
		"Store deactivation updates state and reports the inactive status")
	press("Activate")
	expect(app.sim.state.stores.back().active and app.notice == "Aster Shop is now active.",
		"Store activation updates state and reports the active status")
	app.sim.state.seed = 811
	var stock_result: String = app.sim.buy(0, 2, 40)
	expect(stock_result.is_empty(), "UI fixture obtains stock through the supplier system")
	for batch in app.sim.state.inbound:
		batch.eta = app.sim.state.day
		batch.arrival = app.sim.state.day
	Supply.receive(app.sim)
	expect(Stores.set_listing(app.sim.state, store_id, 0, 9500, true).is_empty(), "UI fixture publishes a store listing")

	press("Dashboard")
	expect(has_label("Mira Rouf Kalil, CEO"), "Dashboard updates CEO label")
	app.persist("Identity test save.")
	expect(Slots.latest().state.owner == "Mira Rouf Kalil", "Autosave persists entrepreneur name")
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
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Direct"
	inputs[1].text = "Aster Brand"
	inputs[2].text = "direct.aster.shop"
	select(controls(app, "OptionButton")[0], 1)
	var website_setup_cost := Stores.setup_cost(app.sim.state.country, 1)
	var website_cash_before: int = app.sim.state.cash
	var store_setup_before: int = app.sim.state.ledger.back().store_setup
	press("Create store")
	expect(is_instance_valid(app.confirmation), "Website setup requests confirmation")
	if is_instance_valid(app.confirmation):
		app.confirmation.confirmed.emit()
	expect(app.sim.state.stores.size() == 2 and app.sim.state.stores[1].domain == "direct.aster.shop",
		"Store form creates an own website with its configured domain")
	expect(app.sim.state.stores[1].active and app.sim.state.stores[1].setup_cost == website_setup_cost
		and app.sim.state.cash == website_cash_before - website_setup_cost
		and app.sim.state.ledger.back().store_setup == store_setup_before + website_setup_cost,
		"Website activates only after its required setup cost is charged and recorded")
	await settle("phase3-stores")
	var manage_buttons := controls(app, "Button").filter(func(button): return button.text == "Manage listings")
	if not manage_buttons.is_empty():
		manage_buttons.back().pressed.emit()
	else:
		expect(false, "Created store exposes its Manage listings control")
	expect(has_label("Aster Direct · Product listings"), "Store management opens store-specific product listings")
	await settle("phase3-store-listings")
	expect(Slots.latest().state.advertising.campaigns.size() == 1 and Slots.latest().state.stores.size() == 2
		and Slots.latest().state.stores[1].domain == "direct.aster.shop"
		and Slots.latest().state.stores[1].active and Slots.latest().state.stores[1].setup_cost == website_setup_cost,
		"Campaign, website domain, activation, and setup cost persist through autosave")
	var legacy_snapshot: Dictionary = app.sim.state.duplicate(true)
	legacy_snapshot.owner = ""
	var preserved_stores: Array = legacy_snapshot.stores.duplicate(true)
	var preserved_products: Dictionary = legacy_snapshot.products.duplicate(true)
	var preserved_campaigns: Dictionary = legacy_snapshot.advertising.campaigns.duplicate(true)
	expect(Slots.write(3, legacy_snapshot, Time.get_unix_time_from_system()) == OK,
		"Write a legacy save missing its entrepreneur identity")
	app.dirty = false
	app.request_load(Slots.read(3))
	if is_instance_valid(app.confirmation):
		app.confirmation.confirmed.emit()
	expect(app.screen == "Entrepreneur name" and has_label("Enter your entrepreneur name to continue this saved company."),
		"Loading a legacy save asks for a CEO name instead of inventing one")
	inputs = controls(app, "LineEdit")
	if not inputs.is_empty(): inputs[0].text = "Mira Restored"
	press("Save and continue")
	expect(app.sim.state.owner == "Mira Restored" and app.sim.state.company == "Aster Labs"
		and app.sim.state.stores == preserved_stores and app.sim.state.products == preserved_products
		and app.sim.state.advertising.campaigns == preserved_campaigns,
		"Entering the missing name resumes the same saved company and progress")
	print("Phase 3 UI (390 × 844): %d failures" % failures)
	quit(0 if failures == 0 else 1)
