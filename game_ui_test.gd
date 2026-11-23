extends "res://phase1_ui_test.gd"

const Games = preload("res://game_store.gd")
const CEO = preload("res://ceo_profile.gd")
const Sim = preload("res://simulation.gd")
const Ads = preload("res://advertising.gd")
const Style = preload("res://corporate_theme.gd")
const MenuView = preload("res://menu_view.gd")

var legacy_game_id := ""
var first_game_id := ""
var second_game_id := ""
var sibling_company_id := ""
var duplicate_company_id := ""
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
	_test_main_menu_layout()
	test_legacy_game_is_visible()
	test_required_new_game_identity()
	test_independent_game_saves_and_profiles()
	test_save_cards_hide_internal_ids()
	await test_delete_confirmation_is_scoped()
	app.queue_free()
	await process_frame
	_cleanup()
	print("Game selection UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _test_main_menu_layout() -> void:
	var actions := app.find_child("MainMenuActions", true, false) as VBoxContainer
	var primary_grid := app.find_child("MainMenuPrimaryActions", true, false) as GridContainer
	var new_game := app.find_child("MainMenuNewGame", true, false) as Button
	var load_game := app.find_child("MainMenuLoadGame", true, false) as Button
	var settings_button := app.find_child("MainMenuSettings", true, false) as Button
	expect(MenuView.play_heading([]) == "Start Playing" and MenuView.play_heading([{"game_id": "saved"}]) == "Continue Playing",
		"Main Menu play heading reflects whether a recoverable game exists")
	expect(has_label("Continue Playing"), "Main Menu shows Continue Playing when a saved game exists")
	expect(actions != null and primary_grid != null and primary_grid.columns == 2 and new_game != null and load_game != null
		and settings_button != null and new_game.get_parent() == primary_grid and load_game.get_parent() == primary_grid
		and settings_button.get_parent() == actions,
		"Main Menu places New Game and Load Game together with Settings on its own full-width row")
	if new_game == null or load_game == null or settings_button == null or primary_grid == null:
		return
	var new_style := new_game.get_theme_stylebox("normal") as StyleBoxFlat
	var load_style := load_game.get_theme_stylebox("normal") as StyleBoxFlat
	var settings_style := settings_button.get_theme_stylebox("normal") as StyleBoxFlat
	expect(new_style != null and new_style.bg_color == Style.GOLD,
		"New Game uses the visible gold primary button style")
	expect(load_style != null and load_style.bg_color == Style.INPUT and load_style.border_color == Style.LINE
		and settings_style != null and settings_style.bg_color == Style.INPUT and settings_style.border_color == Style.LINE,
		"Load Game and Settings use visible dark secondary button styles")
	expect([new_game, load_game, settings_button].all(func(button): return button.custom_minimum_size.y >= 44.0),
		"Main Menu buttons preserve minimum 44px touch targets")
	settings_button.pressed.emit()
	expect(app.screen == "Settings", "Settings opens the existing settings screen")
	app.open_screen("Title")
	load_game = app.find_child("MainMenuLoadGame", true, false) as Button
	if load_game == null:
		expect(false, "Main Menu Load Game action remains present after returning from Settings")
		return
	load_game.pressed.emit()
	expect(app.screen == "Load", "Load Game opens the existing save-loading screen")
	app.open_screen("Title")
	for viewport in [Vector2i(360, 800), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = viewport
		app._update_responsive_layout()
		await process_frame
		await process_frame
		var viewport_grid := app.find_child("MainMenuPrimaryActions", true, false) as GridContainer
		var viewport_new := app.find_child("MainMenuNewGame", true, false) as Button
		var viewport_load := app.find_child("MainMenuLoadGame", true, false) as Button
		var viewport_settings := app.find_child("MainMenuSettings", true, false) as Button
		var grid_rect := viewport_grid.get_global_rect() if viewport_grid != null else Rect2()
		var new_rect := viewport_new.get_global_rect() if viewport_new != null else Rect2()
		var load_rect := viewport_load.get_global_rect() if viewport_load != null else Rect2()
		var settings_rect := viewport_settings.get_global_rect() if viewport_settings != null else Rect2()
		expect(viewport_grid != null and viewport_new != null and viewport_load != null and viewport_settings != null
			and grid_rect.size.x > 0.0 and new_rect.position.x >= grid_rect.position.x - 1.0
			and load_rect.end.x <= grid_rect.end.x + 1.0 and new_rect.end.x <= load_rect.position.x
			and settings_rect.size.x >= grid_rect.size.x - 1.0,
			"Main Menu buttons align without clipping at %dx%d" % [viewport.x, viewport.y])
	root.size = Vector2i(1280, 720)
	app._update_responsive_layout()
	await process_frame

func test_legacy_game_is_visible() -> void:
	var legacy := Games.get_game(legacy_game_id)
	expect(not legacy.is_empty() and legacy.get("legacy", false), "Legacy save migration creates a visible legacy game entry")
	expect(CEO.load_profile().full_name == "Legacy UI Founder" and not Slots.read(Slots.AUTOSAVE).is_empty(),
		"Legacy profile and original autosave remain available after the menu migration")
	expect(has_label("Legacy UI Founder"), "Title screen lists the migrated legacy CEO identity")
	var card := _game_card(legacy_game_id)
	expect(card != null and _button_in(card, "Continue Game") != null and _button_in(card, "Load Saves") != null,
		"Migrated game exposes resume and game-scoped load actions")
	var legacy_card_labels := controls(card, "Label").map(func(node): return str(node.text)) if card != null else []
	var latest_legacy_slot := Games.latest(legacy_game_id)
	var latest_legacy_company := str(latest_legacy_slot.get("state", {}).get("company", ""))
	expect(card != null and card.get_child(0) is Label and str(card.get_child(0).text) == latest_legacy_company
		and legacy_card_labels.count(latest_legacy_company) == 1 and legacy_card_labels.count("Legacy UI Founder") == 1,
		"Main Menu company card uses one company title and one CEO line without repeating save/game labels")
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
	var duplicate := Sim.register("Avery Founder", "Avery Retail", "", 2, 1, 0, 1003)
	duplicate_company_id = str(duplicate.company_id)
	sibling_profile = CEO.register_company(sibling_profile, duplicate)
	expect(Games.update_game_profile(first_game_id, sibling_profile) == OK
		and Saves.save(duplicate, CEO.company_path_for_game(first_game_id, duplicate_company_id)) == OK,
		"An identically named company is saved as a distinct owned company record")
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
	app.web_storage_sync_pending = true
	app.dirty = true
	app.notice = "Saving Manual slot 1 to browser storage…"
	app.render()
	expect(has_label("Saving to browser storage… Keep this page open until the save completes."),
		"Save Game puts the pending browser durability state above the slot list")
	press("Save to slot 1")
	expect(Games.read_slot(second_game_id, 1).is_empty()
		and app.notice.contains("before saving again"),
		"A second manual save cannot race an in-flight browser-storage write")
	app.web_storage_sync_pending = false
	app.dirty = false
	app.notice = "Saved to manual slot 1."
	app.render()
	expect(has_label("Saved to manual slot 1."), "Save Game shows the durable completion message above the slot list")
	app.notice = ""
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
	var slot_labels := controls(slot_card, "Label").map(func(node): return str(node.text)) if slot_card != null else []
	expect(slot_card != null and "Avery Retail" in slot_labels and "Avery Updated" in slot_labels
		and "Country" in slot_labels and "Simulation Date" in slot_labels and "Save Type" in slot_labels and "Last Saved" in slot_labels,
		"Manual slot card shows company, CEO, country, simulation date, save type, and last saved date without a concatenated duplicate label")
	var saved_company_id := str(first_slot.get("state", {}).get("company_id", ""))
	expect(not slot_labels.any(func(text): return text.contains(saved_company_id)),
		"Manual save card keeps the company ID in save data but omits it from displayed text")
	app.load_slot(3)
	expect(app.screen == "Game" and app.active_game_id == first_game_id and app.sim.state.owner == "Avery Updated" and app.sim.state.company == "Avery Retail",
		"Loading a manual slot restores only its owning game's company")

func test_save_cards_hide_internal_ids() -> void:
	var duplicate_created := Games.create_game("Avery Founder", "Duplicate Name QA")
	var duplicate_game: Dictionary = duplicate_created.get("game", {})
	if duplicate_game.is_empty():
		expect(false, "Duplicate-name QA game is created for save-card display verification")
		return
	var duplicate_game_id := str(duplicate_game.get("game_id", ""))
	var duplicate_state := Sim.register("Avery Founder", "Avery Retail", "", 1, 1, 0, 2004)
	var duplicate_profile := CEO.register_company(duplicate_created.profile, duplicate_state)
	expect(Games.write_slot(duplicate_game_id, Slots.AUTOSAVE, duplicate_state, duplicate_profile) == OK,
		"Duplicate company name is stored in an independent autosave with its original internal ID")
	app.leave_game()
	var saved_card := _game_card(duplicate_game_id)
	var card_labels := controls(saved_card, "Label").map(func(node): return str(node.text)) if saved_card != null else []
	var company_id := str(duplicate_state.get("company_id", ""))
	expect(saved_card != null and saved_card.get_child(0) is Label
		and str(saved_card.get_child(0).text) == "Avery Retail"
		and not str(saved_card.get_child(0).text).contains(duplicate_game_id.right(6))
		and not card_labels.any(func(text): return text.contains(company_id) or text.contains(duplicate_game_id.right(6)))
		and "Avery Founder" in card_labels and "Country" in card_labels and "Simulation Date" in card_labels
		and "Save Type" in card_labels and "Last Saved" in card_labels,
		"Duplicate company names display without an internal identifier while CEO and save metadata remain visible")
	expect(_button_in(saved_card, "Continue Game") != null and _button_in(saved_card, "Choose Company") != null
		and _button_in(saved_card, "Load Saves") != null and _button_in(saved_card, "Delete Game") != null,
		"Hiding the identifier preserves Continue, Choose Company, Load Saves, and Delete Game actions")
	var delete_action := _button_in(saved_card, "Delete Game")
	if delete_action != null:
		delete_action.pressed.emit()
		expect(app.confirmation != null, "Delete Game still requires confirmation after its card title is compacted")
		if app.confirmation != null: app.confirmation.get_cancel_button().pressed.emit()
	expect(not Games.get_game(duplicate_game_id).is_empty(), "Cancelling save-card deletion preserves the correct game record")
	app.open_game_slots(duplicate_game_id)
	var autosave_card := _slot_card(Slots.AUTOSAVE)
	var autosave_labels := controls(autosave_card, "Label").map(func(node): return str(node.text)) if autosave_card != null else []
	expect(autosave_card != null and "Avery Retail" in autosave_labels and "Avery Founder" in autosave_labels
		and not autosave_labels.any(func(text): return text.contains(company_id) or text.contains(duplicate_game_id.right(6)))
		and _button_in(autosave_card, "Load Autosave") != null,
		"Autosave cards display company identity and metadata without exposing IDs, and remain loadable")

func test_delete_confirmation_is_scoped() -> void:
	app.leave_game()
	app.choose_company_in_game(first_game_id)
	var company_card := _company_card("Avery Wholesale")
	var duplicate_card := _company_card("Avery Retail · " + duplicate_company_id.right(6))
	expect(duplicate_card != null and _company_card("Avery Retail") == null,
		"Duplicate company names receive a stable short identifier in Choose Company")
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
				and first_profile.companies.size() == 2 and first_profile.companies.any(func(entry): return entry.name == "Avery Retail")
				and first_profile.companies.any(func(entry): return str(entry.company_id) == duplicate_company_id),
				"Deleting one owned company removes only its portfolio entry while preserving both distinct Avery Retail records and CEO career")
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
	var long_game_name := "Riley's International Online Business Career with Multiple Marketplace Brands"
	var long_name_profile: Dictionary = CEO.load_game_profile(second_game_id)
	long_name_profile.game_name = long_game_name
	expect(Games.update_game_profile(second_game_id, long_name_profile) == OK,
		"Long game title fixture updates only the disposable test profile")
	delete_button.pressed.emit()
	expect(app.confirmation != null and app.confirmation.title == "Delete Game?"
		and app.confirmation.dialog_text.contains(long_game_name) and app.confirmation.dialog_text.contains("Other games"),
		"Delete confirmation keeps a compact title and shows the full long game name and deletion scope in its body")
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
	return app.find_child("SavedGame_%s" % game_id, true, false) as Control

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
