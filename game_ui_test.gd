extends "res://phase1_ui_test.gd"

const Games = preload("res://game_store.gd")
const CEO = preload("res://ceo_profile.gd")
const Sim = preload("res://simulation.gd")
const Ads = preload("res://advertising.gd")

var legacy_game_id := ""
var first_game_id := ""
var second_game_id := ""
var sibling_company_id := ""
var legacy_blank_company_id := ""
var legacy_stores: Array = []
var legacy_products: Dictionary = {}
var legacy_campaigns: Dictionary = {}

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty() or not Games.list_games().is_empty():
		push_error("Run game UI checks with a fresh isolated profile.")
		quit(1)
		return
	_seed_legacy_game()
	root.size = Vector2i(1280, 720)
	app = Main.instantiate()
	root.add_child(app)
	await process_frame
	test_legacy_game_is_visible()
	test_required_new_game_identity()
	test_independent_game_saves_and_profiles()
	await test_delete_confirmation_is_scoped()
	app.queue_free()
	await process_frame
	_cleanup()
	print("Game selection UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func test_legacy_game_is_visible() -> void:
	var legacy := Games.get_game(legacy_game_id)
	expect(not legacy.is_empty() and legacy.get("legacy", false), "Legacy save migration creates a visible legacy game entry")
	expect(CEO.load_profile().full_name == "Legacy UI Founder" and not Slots.read(Slots.AUTOSAVE).is_empty(),
		"Legacy profile and original autosave remain available after the menu migration")
	expect(has_label("Legacy UI Founder"), "Title screen lists the migrated legacy CEO identity")
	var card := _game_card(legacy_game_id)
	expect(card != null and _button_in(card, "Continue Game") != null and _button_in(card, "Load Saves") != null,
		"Migrated game exposes resume and game-scoped load actions")
	app.open_game_slots(legacy_game_id)
	app.load_slot(1)
	if app.confirmation != null: app.confirmation.confirmed.emit()
	expect(app.screen == "Entrepreneur name" and has_label("Enter your entrepreneur name to continue this saved company."),
		"Legacy save without an entrepreneur name prompts for identity before loading")
	var legacy_name_field := field_for_label("Entrepreneur Name")
	if legacy_name_field != null: legacy_name_field.text = "Different Legacy Name"
	press("Save and continue")
	expect(app.screen == "CEO identity conflict", "Conflicting legacy name requires an explicit migration choice")
	press("Use Current CEO Profile")
	expect(app.screen == "Game" and app.sim.state.owner == "Legacy UI Founder"
		and app.sim.state.company_id == legacy_blank_company_id and app.sim.state.stores == legacy_stores
		and app.sim.state.products == legacy_products and app.sim.state.advertising.campaigns == legacy_campaigns,
		"Resolving legacy identity preserves company, product, store, and campaign history")
	app.leave_game()

func test_required_new_game_identity() -> void:
	press("New Game")
	expect(app.screen == "New Game", "New Game asks for the CEO identity before company registration")
	press("Continue to Company Registration")
	expect(Games.list_games().size() == 1 and app.notice.to_lower().contains("ceo name"), "Blank CEO name is required and does not create a game")
	var name_field := field_for_label("CEO Name")
	if name_field == null:
		expect(false, "New Game displays a CEO Name field")
		return
	name_field.text = "Avery Founder"
	press("Continue to Company Registration")
	expect(app.screen == "Setup" and app.active_game_id != "", "A valid CEO identity creates a game and opens company registration")
	first_game_id = app.active_game_id
	press("Register company")
	expect(app.screen == "Setup" and app.sim == null, "Company name remains required after CEO identity is saved")
	var company_field := field_for_label("Company Name")
	if company_field == null:
		expect(false, "Company registration displays a Company name field")
		return
	company_field.text = "Avery Retail"
	press("Register company")
	expect(app.sim != null and app.sim.state.owner == "Avery Founder" and app.sim.state.company == "Avery Retail",
		"Registration stores the CEO and company names independently")
	var sibling := Sim.register("Avery Founder", "Avery Wholesale", "", 1, 1, 0, 1002)
	sibling_company_id = str(sibling.company_id)
	sibling_company_id = str(sibling.company_id)
	var sibling_profile := CEO.register_company(CEO.load_game_profile(first_game_id), sibling)
	expect(Games.update_game_profile(first_game_id, sibling_profile) == OK
		and Saves.save(sibling, CEO.company_path_for_game(first_game_id, str(sibling.company_id))) == OK
		and Slots.write_for_game(first_game_id, 2, sibling, sibling_profile) == OK,
		"A second owned company has its own archive and manual save in the same game")
	Games.write_slot(first_game_id, Slots.AUTOSAVE, app.sim.state, sibling_profile)
	app.ceo_profile = sibling_profile
	app.leave_game()
	expect(app.screen == "Title" and app.active_game_id.is_empty(), "Returning to Main Menu clears the selected game context")
	var card := _game_card(first_game_id)
	expect(card != null and _button_in(card, "Continue Game") != null, "Registered game appears on the title screen with Continue Game")

func test_independent_game_saves_and_profiles() -> void:
	press("New Game")
	var name_field := field_for_label("CEO Name")
	if name_field == null:
		expect(false, "Second game has an independent CEO identity form")
		return
	name_field.text = "Riley Founder"
	press("Continue to Company Registration")
	var company_field := field_for_label("Company Name")
	if company_field == null:
		expect(false, "Second game reaches company registration")
		return
	company_field.text = "Riley Commerce"
	press("Register company")
	second_game_id = app.active_game_id
	expect(not second_game_id.is_empty() and second_game_id != first_game_id
		and app.sim.state.owner == "Riley Founder", "A second game has a separate CEO and game identity")
	app.open_screen("Save")
	press("Save to slot 1")
	var second_slot := Games.read_slot(second_game_id, 1)
	expect(not second_slot.is_empty() and second_slot.metadata.ceo_name == "Riley Founder"
		and second_slot.state.company == "Riley Commerce", "Manual save is labeled and stored under the selected game")
	app.leave_game()
	app.resume_game(first_game_id)
	expect(app.active_game_id == first_game_id and app.sim != null and app.sim.state.owner == "Avery Founder",
		"Resume loads the first game's CEO and company, not the most recently played game")
	var first_slot_before := Games.read_slot(first_game_id, 1)
	app.open_screen("Save")
	press("Save to slot 1")
	var first_slot := Games.read_slot(first_game_id, 1)
	expect(first_slot.state.company == "Avery Retail" and first_slot.metadata.ceo_name == "Avery Founder"
		and first_slot_before.is_empty() and Games.read_slot(second_game_id, 1).state.company == "Riley Commerce",
		"Same-number manual slots remain isolated between games")
	app.open_screen("Game")
	app.navigate("Profile")
	press("Edit Profile")
	expect(field_for_label("Professional Title") == null and has_button("Save Changes"),
		"Career title is read-only while CEO identity can be edited")
	var full_name := field_for_label("Full Name")
	if full_name == null:
		expect(false, "Profile editing exposes the CEO name field")
		return
	full_name.text = "Avery Updated"
	press("Save Changes")
	var renamed := Games.get_game(first_game_id)
	var renamed_slot := Games.read_slot(first_game_id, Slots.AUTOSAVE)
	expect(renamed.ceo_name == "Avery Updated" and renamed_slot.metadata.ceo_name == "Avery Updated"
		and renamed_slot.state.owner == "Avery Updated" and renamed_slot.state.company == "Avery Retail",
		"CEO profile edits update game/save labels without changing company identity")
	expect(Games.get_game(second_game_id).ceo_name == "Riley Founder"
		and Games.read_slot(second_game_id, 1).metadata.ceo_name == "Riley Founder",
		"Editing one CEO profile leaves other game metadata and saves unchanged")
	app.open_screen("Save")
	press("Save to slot 3")
	app.open_game_slots(first_game_id)
	expect(app.active_game_id == first_game_id and not has_label("Riley Commerce"),
		"Load Saves is scoped to the selected game")
	var slot_card := _slot_card(3)
	expect(slot_card != null and has_label(Games.save_label(Games.read_slot(first_game_id, 3))),
		"Manual slot list shows the current game, CEO, company, and slot label")
	app.load_slot(3)
	expect(app.screen == "Game" and app.active_game_id == first_game_id and app.sim.state.owner == "Avery Updated" and app.sim.state.company == "Avery Retail",
		"Loading a manual slot restores only its owning game's company")

func test_delete_confirmation_is_scoped() -> void:
	app.leave_game()
	app.choose_company_in_game(first_game_id)
	var company_card := _company_card("Avery Wholesale")
	var company_delete := _button_in(company_card, "Delete Company") if company_card != null else null
	expect(company_delete != null, "Company selection exposes Delete Company only for owned businesses")
	if company_delete != null:
		company_delete.pressed.emit()
		expect(app.confirmation != null and app.confirmation.dialog_text.contains("CEO profile")
			and app.confirmation.dialog_text.contains("other games"), "Company deletion requires confirmation and states the preserved scope")
		if app.confirmation != null: app.confirmation.confirmed.emit()
		await process_frame
		var first_profile := CEO.load_game_profile(first_game_id)
		expect(CEO.company_index(first_profile, sibling_company_id) == -1
			and first_profile.companies.size() == 1 and first_profile.companies[0].name == "Avery Retail",
			"Deleting an owned company removes its portfolio entry while preserving the other same-game company and CEO career")
		expect(Games.read_slot(first_game_id, 2).is_empty() and not Games.read_slot(first_game_id, 1).is_empty()
			and Games.read_slot(second_game_id, 1).state.company == "Riley Commerce"
			and Saves.load_state(CEO.company_path_for_game(first_game_id, str(sibling_company_id))).is_empty(),
			"Company deletion removes only matching slots and archive; other company and game saves remain")
	else:
		expect(false, "Second owned company is available for scoped deletion verification")
	app.show_screen("Title")
	var card := _game_card(second_game_id)
	var delete_button := _button_in(card, "Delete Game") if card != null else null
	expect(delete_button != null, "Each saved game has its own Delete Game action")
	if delete_button == null: return
	delete_button.pressed.emit()
	expect(app.confirmation != null and app.confirmation.dialog_text.contains("Other games"),
		"Deleting a game requires explicit confirmation that explains its limited scope")
	if app.confirmation != null: app.confirmation.get_cancel_button().pressed.emit()
	expect(not Games.get_game(second_game_id).is_empty(), "Cancel leaves the selected game untouched")
	card = _game_card(second_game_id)
	delete_button = _button_in(card, "Delete Game") if card != null else null
	if delete_button != null: delete_button.pressed.emit()
	if app.confirmation != null: app.confirmation.confirmed.emit()
	await process_frame
	expect(Games.get_game(second_game_id).is_empty() and Games.get_game(first_game_id).ceo_name == "Avery Updated"
		and Games.get_game(legacy_game_id).legacy,
		"Confirmed deletion removes only the selected game and preserves other new and migrated games")

func _seed_legacy_game() -> void:
	var state := Sim.register("Legacy UI Founder", "Legacy Retail", "", 0, 1, 0, 992)
	var missing_owner := Sim.register("Legacy UI Founder", "Legacy Identity Recovery", "", 1, 1, 0, 993)
	var profile := CEO.ensure({}, "Legacy UI Founder")
	profile = CEO.register_company(profile, state)
	profile = CEO.register_company(profile, missing_owner)
	legacy_blank_company_id = str(missing_owner.company_id)
	missing_owner.stores = Stores.migration_defaults(missing_owner)
	Stores.set_listing(missing_owner, int(missing_owner.stores[0].id), 0, 12500, true)
	Ads.create(missing_owner, {"name": "Legacy Awareness", "store_id": int(missing_owner.stores[0].id),
		"platform": 0, "product": 0, "daily_budget": 1000, "audience": 0, "objective": 0,
		"bid_strategy": 0, "bid": 0, "creative": 0, "draft": true})
	legacy_stores = missing_owner.stores.duplicate(true)
	legacy_products = missing_owner.products.duplicate(true)
	legacy_campaigns = missing_owner.advertising.campaigns.duplicate(true)
	missing_owner.owner = ""
	CEO.save_profile(profile)
	Saves.save(state, CEO.company_path(str(state.company_id)), 10.0)
	Saves.save(missing_owner, CEO.company_path(legacy_blank_company_id), 15.0)
	Slots.write(Slots.AUTOSAVE, state, 10.0)
	Slots.write(1, missing_owner, 20.0)
	legacy_game_id = "legacy-game-" + _hash("ceo:" + str(profile.ceo_id)).substr(0, 32)

func _company_card(company_name: String) -> Control:
	for node in controls(app, "VBoxContainer"):
		if node.get_parent() is PanelContainer and node.get_child_count() > 0 and node.get_child(0) is Label and node.get_child(0).text == company_name:
			return node
	return null

func _game_card(game_id: String) -> Control:
	var game := Games.get_game(game_id)
	if game.is_empty(): return null
	for node in controls(app, "VBoxContainer"):
		if node.get_parent() is PanelContainer and node.get_child_count() > 0 and node.get_child(0) is Label and node.get_child(0).text == str(game.game_name):
			return node
	return null

func _button_in(node: Node, title: String) -> Button:
	if node == null: return null
	for button in controls(node, "Button"):
		if button.text == title: return button
	return null

func _slot_card(slot: int) -> Control:
	for node in controls(app, "VBoxContainer"):
		if node.get_parent() is PanelContainer and node.get_child_count() > 0 and node.get_child(0) is Label and node.get_child(0).text == Slots.name_for(slot):
			return node
	return null

func _hash(value: String) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(value.to_utf8_buffer())
	return hasher.finish().hex_encode().substr(0, 32)

func _cleanup() -> void:
	for game in Games.list_games(): Games.delete_game_data(str(game.game_id))
	for path in [CEO.PATH, Saves.PATH]: _clean_file(path)
	for slot in range(Slots.COUNT): _clean_file(Slots.path_for(slot))

func _clean_file(path: String) -> void:
	for suffix in [".tmp", ".bak", ".deleted", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
