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
	create_new_game_for_test("Mira Founder", "Aster Labs")
	var inputs := controls(app, "LineEdit")
	expect(app.sim.state.stores.is_empty() and app.sim.state.store.is_empty(), "New company has no default store or store name")
	expect(controls(app, "Button").filter(func(button): return button.text == "Growth").is_empty(),
		"Growth is not a standalone navigation destination")
	expect(not app.sim.channel_enabled(0) and not app.sim.channel_enabled(1), "Legacy channel flags do not create a marketplace or website")
	expect(has_label("Mira Founder, CEO"), "Dashboard displays the registered entrepreneur as CEO")
	press("Business")
	expect(has_label("Owned Stores") and not has_label("Website domain") and not has_label("Website inactive")
		and controls(app, "OptionButton").is_empty(), "Company Profile shows zero stores and no legacy website or channel controls")
	expect(controls(app, "LineEdit").is_empty() and has_button("Edit Company Details"),
		"Saved company details are read-only until editing is explicitly activated")
	press("Edit Company Details")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Discarded Name"
	press("Cancel")
	expect(app.sim.state.owner == "Mira Founder" and not has_button("Save Changes"),
		"Cancel discards unsaved company profile changes")
	press("Edit Company Details")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Mira Rouf Kalil"
	press("Save Changes")
	expect(app.sim.state.owner == "Mira Rouf Kalil" and app.sim.state.company == "Aster Labs", "Company Profile edits CEO identity independently")
	press("Management")
	expect(not has_label("Open a new store"), "New-store form is collapsed by default")
	press("Open New Store")
	expect(has_label("Owned stores · 0"), "Business opens Management with no default stores")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Shop"
	inputs[1].text = "Aster Brand"
	select(controls(app, "OptionButton")[0], 0)
	press("Create store")
	expect(app.sim.state.stores.size() == 1, "Marketplace creation is performed through Management")
	var store_id: int = app.sim.state.stores.back().id
	press("Deactivate")
	expect(not app.sim.state.stores.back().active and app.notice == "Aster Shop is now inactive.",
		"Store deactivation updates state and reports the inactive status")
	press("Activate")
	expect(app.sim.state.stores.back().active and app.notice == "Aster Shop is now active.",
		"Store activation updates state and reports the active status")
	app.sim.state.seed = 811
	var stock_result: String = app.sim.buy(0, Catalog.DEFAULT_SUPPLIER, 40)
	expect(stock_result.is_empty(), "UI fixture obtains stock through the supplier system")
	for batch in app.sim.state.inbound:
		batch.eta = app.sim.state.day
		batch.arrival = app.sim.state.day
	Supply.receive(app.sim)
	expect(Stores.set_listing(app.sim.state, store_id, 0, 9500, true).is_empty(), "UI fixture publishes a store listing")

	press("Dashboard")
	expect(has_label("Mira Rouf Kalil, CEO"), "Dashboard updates CEO label")
	app.persist("Identity test save.")
	expect(Slots.latest_for_game(app.active_game_id).state.owner == "Mira Rouf Kalil", "Autosave persists entrepreneur name")
	press("Business")
	press("Advertising")
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
	expect(controls(app, "LineEdit").is_empty() and has_button("Edit Campaign"),
		"Saved campaign details are read-only until editing is explicitly activated")
	press("Edit Campaign")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Discarded campaign edit"
	press("Cancel")
	expect(app.sim.state.advertising.campaigns[1].name == "Portrait launch",
		"Cancel discards unsaved campaign edits")
	press("Campaign Manager")
	press("Manage campaign")
	press("Pause")
	expect(app.sim.state.advertising.campaigns[1].status == "paused", "Campaign pause button changes campaign state")
	press("Resume")
	expect(app.sim.state.advertising.campaigns[1].status == "active", "Campaign resume button changes campaign state")
	app.sim.advance(8)
	press("Ads Analytics")
	expect(has_label("Ads Analytics"), "Campaign details opens ads analytics")
	expect(has_label("Total Ad Spend") and has_label("Attributed Revenue") and has_label("ROAS")
		and has_label("Impressions") and has_label("Clicks") and has_label("Purchases")
		and has_label("Ad Spend vs. Attributed Revenue") and has_label("ROAS Trend")
		and has_label("Clicks and Purchases") and has_label("Campaign Performance")
		and has_label("Portrait launch") and has_label("Advertising Platform")
		and has_label("Reporting Period") and has_label("Destination Store"),
		"Analytics dashboard uses recorded campaign data, KPI cards, trends, and accessible filters")
	var expected_ad_spend := 0
	for record in app.sim.state.advertising.history:
		if int(record.day) >= maxi(1, app.sim.state.day - 6) and int(record.day) <= app.sim.state.day:
			expected_ad_spend += int(record.spend)
	expect(controls(app, "Label").any(func(node): return node.text == app.money(expected_ad_spend)),
		"Ads Analytics KPI spend reconciles to campaign history for the selected date range")
	select(controls(app, "OptionButton")[2], 3)
	expect(not has_label("Portrait launch"), "Campaign status filter removes active campaigns when Paused is selected")
	select(controls(app, "OptionButton")[2], 0)
	expect(has_label("Portrait launch"), "Campaign status filter restores the all-status comparison")
	await settle("phase3-analytics")
	press("Business")
	press("Management")
	expect(has_label("Owned stores"), "Growth opens multi-store management")
	press("Open New Store")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Aster Direct"
	inputs[1].text = "Aster Brand"
	inputs[2].text = "direct.aster.shop"
	select(controls(app, "OptionButton")[0], 1)
	var stores_before_unselected_website: int = app.sim.state.stores.size()
	press("Create store")
	expect(app.sim.state.stores.size() == stores_before_unselected_website
		and not is_instance_valid(app.confirmation)
		and app.notice == "Select a website platform before creating the website.",
		"Website cannot be created before the player chooses a platform")
	select(controls(app, "OptionButton")[2], 3)
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
	press("My Products")
	press("Manage " + Catalog.PRODUCTS[0].name)
	var website_listing: Control = app.find_child("ProductListingStore%d" % int(app.sim.state.stores[1].id), true, false)
	expect(app.page == "My Products" and website_listing != null and has_label("Store Listings"),
		"Selected product owns the store-specific listing management interface")
	expect(controls(app, "LineEdit").filter(func(field): return field.is_visible_in_tree()).is_empty() and has_button("Edit Listing"),
		"Saved store listings display read-only details by default")
	var listing_edit_buttons := controls(website_listing, "Button").filter(func(button): return button.text == "Edit Listing") if website_listing != null else []
	if not listing_edit_buttons.is_empty():
		listing_edit_buttons[0].pressed.emit()
	else:
		expect(false, "The selected product exposes an Edit Listing action for the website")
	expect(has_label("Store Selling Price"), "Store-specific listing price becomes editable only after selecting Edit Listing")
	var original_listing_price: int = Stores.listing(app.sim.state, store_id, 0).price
	press("Cancel")
	expect(Stores.listing(app.sim.state, int(app.sim.state.stores[1].id), 0).price > 0,
		"Existing websites retain their independent listing prices through the My Products transition")
	app.navigate("My Products")
	press("Manage " + Catalog.PRODUCTS[0].name)
	press("Edit Listing")
	field_for_label("Store Selling Price").text = "123.45"
	press("Cancel")
	expect(Stores.listing(app.sim.state, store_id, 0).price == original_listing_price,
		"Cancel discards unsaved store listing changes in My Products")
	await settle("phase3-store-listings")
	expect(Slots.latest_for_game(app.active_game_id).state.advertising.campaigns.size() == 1 and Slots.latest_for_game(app.active_game_id).state.stores.size() == 2
		and Slots.latest_for_game(app.active_game_id).state.stores[1].domain == "direct.aster.shop"
		and Slots.latest_for_game(app.active_game_id).state.stores[1].active and Slots.latest_for_game(app.active_game_id).state.stores[1].setup_cost == website_setup_cost,
		"Campaign, website domain, activation, and setup cost persist through autosave")
	var migrated_slot := Slots.latest_for_game(app.active_game_id)
	expect(Saves.valid(migrated_slot.get("state", {}))
		and migrated_slot.state.advertising.campaigns.size() == 1
		and migrated_slot.state.stores.size() == 2
		and migrated_slot.state.stores[1].domain == "direct.aster.shop"
		and migrated_slot.state.stores[1].setup_cost == website_setup_cost,
		"Game-scoped Save & Load preserves campaign, website, product, and company state")
	print("Phase 3 UI (390 × 844): %d failures" % failures)
	quit(0 if failures == 0 else 1)
