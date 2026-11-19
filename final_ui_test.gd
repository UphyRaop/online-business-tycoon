extends "res://phase1_ui_test.gd"

func first_store_id() -> int:
	return int(app.sim.state.stores.front().id)

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run with a fresh isolated profile.")
		quit(1)
		return
	root.size = Vector2i(390, 844)
	app = Main.instantiate()
	root.add_child(app)
	await settle("final-title")
	expect(app.screen == "Title", "New session opens on the title menu")
	press("Settings")
	expect(controls(app, "OptionButton").is_empty() and has_button("Edit Display Settings"),
		"Display preference is read-only until editing is explicitly activated")
	press("Edit Display Settings")
	select(controls(app, "OptionButton")[0], 1)
	press("Save Changes")
	expect(app.large_text, "Settings changes text size")
	press("Back")
	press("New Game")
	register_company("Aster Holdings")
	app.sim.state.seed = 153
	expect(Slots.read(0).state.company == "Aster Holdings", "Registration writes autosave")
	press("My Products")
	expect(has_label("Active products") and has_label("Prepare a listing"), "Empty product portfolio is usable")
	press("Browse catalog")
	open_first_store_listing()
	press("Edit Listing")
	var inputs := controls(app, "LineEdit")
	inputs[0].text = "83"
	select(controls(app, "OptionButton")[1], 0)
	press("Save Changes")
	expect(Stores.listing(app.sim.state, first_store_id(), 0).price == 8300 and not Stores.listing(app.sim.state, first_store_id(), 0).listed,
		"Store-specific draft keeps its own price and unpublished status")
	press("Dashboard")
	press("My Products")
	expect(has_label("Draft"), "Prepared products show as Draft")
	press("Manage Portable Blender")
	open_first_store_listing()
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 1)
	press("Save Changes")
	press("Dashboard")
	press("My Products")
	expect(has_label("Out of Stock") and app.sim.active_product_count() == 0, "Out-of-stock products are separate from the active total")
	press("Manage Portable Blender")
	press("Purchase stock")
	open_first_store_listing()
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 0)
	press("Save Changes")
	press("Dashboard")
	press("+7")
	press("My Products")
	press("Manage Portable Blender")
	open_first_store_listing()
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 1)
	press("Save Changes")
	press("Dashboard")
	press("My Products")
	expect(app.sim.active_product_count() == 1 and has_label("Active"),
		"A published product with stock shows as Active (count %d, listing %s, stock %d)" % [
		app.sim.active_product_count(), str(Stores.listing(app.sim.state, first_store_id(), 0)), app.sim.stock(0)])
	press("Dashboard")
	press("+7")
	press("My Products")
	expect(has_label("Net revenue") and has_label("Product profit"), "Product portfolio shows sales and profit")
	await settle("final-products")
	press("Browse catalog")
	select(controls(app, "OptionButton")[0], 4)
	open_first_store_listing()
	press("Edit Listing")
	select(controls(app, "OptionButton")[1], 0)
	press("Save Changes")
	expect(Stores.listing(app.sim.state, first_store_id(), 0).listed and not Stores.listing(app.sim.state, first_store_id(), 4).listed,
		"Two products have independent store-specific listing states")
	press("Business")
	press("Save Game")
	press("Save to slot 1")
	expect(Slots.read(1).state.company == "Aster Holdings", "An empty manual slot saves without confirmation")
	press("Save to slot 1")
	await settle("final-overwrite")
	resolve_dialog(false)
	expect(app.screen == "Save", "Cancel overwrite stays on the slot screen")
	await process_frame
	press("Save to slot 1")
	resolve_dialog(true)
	await settle("final-slots")
	press("Back")
	press("Edit Company Details")
	inputs = controls(app, "LineEdit")
	inputs[0].text = "Unapplied name"
	press("Menu")
	resolve_dialog(false)
	expect(app.screen == "Game" and inputs[0].text == "Unapplied name", "Cancel discard keeps unsaved edits")
	await process_frame
	press("Menu")
	resolve_dialog(true)
	expect(app.screen == "Title", "Confirmed discard returns to title")
	await process_frame
	press("New Game")
	resolve_dialog(false)
	expect(app.screen == "Title", "Cancel autosave replacement stays at title")
	await process_frame
	press("New Game")
	resolve_dialog(true)
	register_company("Second Company")
	expect(Slots.read(0).state.company == "Second Company" and Slots.read(1).state.company == "Aster Holdings", "New game replaces only autosave")
	press("Menu")
	press("Continue Game")
	expect(app.sim.state.company == "Second Company", "Continue loads the latest save")
	press("Menu")
	press("Load Game")
	press("Load slot 1")
	resolve_dialog(true)
	expect(app.sim.state.company == "Aster Holdings" and Stores.listing(app.sim.state, first_store_id(), 0).price == 8300,
		"Load restores a specific company and its store-specific product listing")
	expect(Slots.read(0).state.company == "Second Company", "Loading alone does not overwrite autosave")
	press("Save Game")
	press("Save to slot 2")
	expect(Slots.read(2).state.company == "Aster Holdings" and has_label("Saved to manual slot 2."), "Manual save works directly after loading")
	press("Delete slot 2")
	resolve_dialog(false)
	await process_frame
	expect(Slots.occupied(2), "Cancel deletion preserves manual save")
	press("Delete slot 2")
	resolve_dialog(true)
	expect(not Slots.occupied(2) and has_label("Manual slot 2 deleted."), "Confirmed deletion clears only that slot")
	expect(Slots.occupied(1) and Slots.occupied(0), "Other slots survive deletion")
	press("Back")
	press("Finance")
	expect(has_label("Cash Flow Statement") or has_label("Income Statement"), "Dated financial statements remain available after load")
	await settle("corrective-finance")
	app.queue_free()
	await process_frame
	app = Main.instantiate()
	root.add_child(app)
	expect(app.large_text, "Display setting persists across launch")
	print("Phase 2 final UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func register_company(name: String) -> void:
	var inputs := controls(app, "LineEdit")
	inputs[0].text = "Mira"
	inputs[1].text = name
	select(controls(app, "OptionButton")[1], 2)
	press("Register company")
	expect(app.sim.state.stores.is_empty() and not app.sim.channel_enabled(0) and not app.sim.channel_enabled(1),
		"New registration starts without marketplace or website destinations")
	press("Business")
	press("Management")
	press("Open New Store")
	inputs = controls(app, "LineEdit")
	inputs[0].text = name + " Market"
	inputs[1].text = name + " Brand"
	press("Create store")
	expect(app.sim.state.stores.size() == 1 and app.sim.channel_enabled(0),
		"A marketplace becomes available only after manual Management creation")
	press("Dashboard")

func resolve_dialog(confirm: bool) -> void:
	for dialog in controls(app, "ConfirmationDialog"):
		if dialog.visible:
			if confirm:
				dialog.get_ok_button().pressed.emit()
			else:
				dialog.get_cancel_button().pressed.emit()
			return
	expect(false, "Expected a visible confirmation dialog")
