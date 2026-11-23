extends RefCounted

const Catalog = preload("res://catalog.gd")
const Slots = preload("res://save_slots.gd")
const Style = preload("res://corporate_theme.gd")
const Calendar = preload("res://game_calendar.gd")
const CEOProfile = preload("res://ceo_profile.gd")
const GameStore = preload("res://game_store.gd")
const LOGO = preload("res://icon.svg")

static func brand(app: Control, parent: Node) -> HBoxContainer:
	var header: HBoxContainer = app.row(parent)
	header.add_theme_constant_override("separation", Style.INFO_ROW_GAP)
	var mark := TextureRect.new()
	mark.texture = LOGO
	mark.custom_minimum_size = Vector2(48, 48)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(mark)
	var name: Label = app.label("Online Business Tycoon", Style.FONT_HEADING, Style.GOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name)
	return header

static func title(app: Control) -> void:
	var games := GameStore.list_games()
	var play: VBoxContainer = app.wide_card(play_heading(games))
	var actions := VBoxContainer.new()
	actions.name = "MainMenuActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Style.BUTTON_GROUP_GAP)
	play.add_child(actions)
	var primary_actions := GridContainer.new()
	primary_actions.name = "MainMenuPrimaryActions"
	primary_actions.columns = 2
	primary_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_actions.add_theme_constant_override("h_separation", Style.BUTTON_GROUP_GAP)
	primary_actions.add_theme_constant_override("v_separation", Style.BUTTON_GROUP_GAP)
	actions.add_child(primary_actions)
	for item in [["New Game", app.start_new_game, true], ["Load Game", app.open_screen.bind("Load"), false]]:
		var button: Button = app.action(primary_actions, item[0], item[1], item[2])
		button.name = "MainMenu%s" % str(item[0]).replace(" ", "")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(150 if app.size.x < 600.0 else 172, Style.BUTTON_TOUCH_HEIGHT)
		if item[0] == "Load Game": _style_menu_secondary(button)
	var settings_button: Button = app.action(actions, "Settings", app.open_screen.bind("Settings"))
	settings_button.name = "MainMenuSettings"
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_menu_secondary(settings_button)
	if games.is_empty():
		play.add_child(app.label("No saved games yet. Start a New Game to begin.", Style.FONT_BODY, Style.MUTED))
	else:
		var game_names := {}
		for game in games:
			var latest := GameStore.latest(str(game.game_id))
			var company_name := str(latest.get("state", {}).get("company", ""))
			if not company_name.is_empty(): game_names[company_name] = int(game_names.get(company_name, 0)) + 1
		var cards := GridContainer.new()
		cards.name = "SavedGameCards"
		cards.columns = 3 if app.size.x >= 900.0 else (2 if app.size.x >= 600.0 else 1)
		cards.add_theme_constant_override("h_separation", Style.CARD_GRID_GAP)
		cards.add_theme_constant_override("v_separation", Style.CARD_GRID_GAP)
		play.add_child(cards)
		for game in games:
			_game_card(app, game, true, cards, game_names)

static func play_heading(games: Array) -> String:
	return "Continue Playing" if not games.is_empty() else "Start Playing"

static func _style_menu_secondary(button: Button) -> void:
	Style.secondary(button)

static func slots(app: Control, saving: bool) -> void:
	var back: VBoxContainer = app.wide_card("")
	var back_row: HBoxContainer = app.row(back)
	app.action(back_row, "Back", app.open_screen.bind("Game" if app.sim != null else "Title"))
	if app.web_storage_sync_pending:
		back.add_child(app.label("Saving to browser storage… Keep this page open until the save completes.", 14, Style.GOLD))
	elif app.dirty and app.error_notice and not app.notice.is_empty():
		back.add_child(app.label(app.notice, 14, Style.RED))
	elif app.notice.begins_with("Saved to "):
		back.add_child(app.label(app.notice, 14, Style.GREEN))
	if app.active_game_id.is_empty():
		if saving:
			back.add_child(app.label("Choose a game before saving.", 14, Style.RED))
			return
		var games := GameStore.list_games()
		if games.is_empty():
			back.add_child(app.label("No saved games are available.", 14, Style.MUTED))
		var cards := GridContainer.new()
		cards.name = "LoadGameCards"
		cards.columns = 3 if app.size.x >= 900.0 else (2 if app.size.x >= 600.0 else 1)
		cards.add_theme_constant_override("h_separation", Style.CARD_GRID_GAP)
		cards.add_theme_constant_override("v_separation", Style.CARD_GRID_GAP)
		back.add_child(cards)
		for game in games:
			_game_card(app, game, true, cards, {})
		return
	var order := [1, 2, 3, 0] if saving else [0, 1, 2, 3]
	var slots_grid := GridContainer.new()
	slots_grid.name = "GameSaveSlots"
	slots_grid.columns = 3 if app.size.x >= 900.0 else (2 if app.size.x >= 600.0 else 1)
	slots_grid.add_theme_constant_override("h_separation", Style.CARD_GRID_GAP)
	slots_grid.add_theme_constant_override("v_separation", Style.CARD_GRID_GAP)
	back.add_child(slots_grid)
	for id in order:
		var slot := Slots.read_for_game(app.active_game_id, id)
		var view: VBoxContainer = app._create_card(slots_grid, Slots.name_for(id))
		if slot.is_empty():
			view.add_child(app.label("Unreadable save" if Slots.occupied_for_game(app.active_game_id, id) else "Empty", Style.FONT_BODY, Style.MUTED))
		else:
			describe(app, view, slot)
		if saving:
			if id != Slots.AUTOSAVE:
				app.action(view, "Save to slot %d" % id, app.save_to_slot.bind(id), true)
		if not slot.is_empty():
			app.action(view, "Load autosave" if id == Slots.AUTOSAVE else "Load slot %d" % id, app.load_slot.bind(id), not saving)
		if Slots.occupied_for_game(app.active_game_id, id):
			app.action(view, "Delete autosave" if id == Slots.AUTOSAVE else "Delete slot %d" % id, app.delete_save.bind(id))

static func describe(app: Control, parent: Node, slot: Dictionary) -> void:
	var state: Dictionary = slot.state
	var metadata: Dictionary = slot.get("metadata", {})
	parent.add_child(app.label(state.company, Style.FONT_HEADING, Style.GOLD))
	parent.add_child(app.label(str(metadata.get("ceo_name", state.get("owner", "CEO not recorded"))), 14, Style.MUTED))
	app.metric(parent, "Country", str(Catalog.COUNTRIES[int(state.country)]))
	app.metric(parent, "Simulation Date", Calendar.format(int(state.day)))
	app.metric(parent, "Save Type", str(metadata.get("slot_name", Slots.name_for(int(slot.get("slot", Slots.AUTOSAVE))))))
	app.metric(parent, "Last Saved", Slots.timestamp_text(float(slot.saved_at)))
	if slot.get("recovered", false):
		parent.add_child(app.label("Recovered backup", 14, Style.GOLD))

static func _game_card(app: Control, game: Dictionary, show_slot_summary: bool, parent: Node, duplicate_company_names: Dictionary) -> void:
	var game_id := str(game.get("game_id", ""))
	if game_id.is_empty(): return
	var latest := GameStore.latest(game_id)
	var profile := CEOProfile.load_game_profile(game_id)
	var companies: Array = profile.get("companies", [])
	var company_name := str(latest.get("state", {}).get("company", ""))
	if company_name.is_empty() and not companies.is_empty(): company_name = str(companies[0].get("name", ""))
	if company_name.is_empty(): company_name = "New Game Setup"
	if int(duplicate_company_names.get(company_name, 0)) > 1:
		company_name += " · %s" % game_id.right(6)
	var view: VBoxContainer = app._create_card(parent, company_name)
	view.name = "SavedGame_%s" % game_id
	view.add_child(app.label(str(game.get("ceo_name", "CEO not recorded")), 14, Style.MUTED))
	if latest.is_empty():
		if profile.get("companies", []).is_empty():
			app.metric(view, "Status", "No company registered")
			app.action(view, "Continue Setup", app.resume_setup.bind(game_id), true)
		else:
			app.metric(view, "Status", "Choose an owned company")
			app.action(view, "Choose Company", app.choose_company_in_game.bind(game_id), true)
	else:
		var state: Dictionary = latest.state
		app.metric(view, "Country", str(Catalog.COUNTRIES[int(state.country)]))
		app.metric(view, "Simulation Date", Calendar.format(int(state.day)))
		app.metric(view, "Last Saved", Slots.timestamp_text(float(latest.saved_at)))
		app.metric(view, "Save Type", str(latest.get("metadata", {}).get("slot_name", "Autosave")))
		app.action(view, "Continue Game", app.resume_game.bind(game_id), true)
		app.action(view, "Choose Company", app.choose_company_in_game.bind(game_id))
		if show_slot_summary: app.action(view, "Load Saves", app.open_game_slots.bind(game_id))
	app.action(view, "Delete Game", app.delete_game.bind(game_id))

static func settings(app: Control) -> void:
	var view: VBoxContainer = app.card("Display Settings")
	if app.display_settings_editing:
		view.add_child(app.label("Text Size", 14, Style.MUTED))
		var size: OptionButton = app.dropdown(view, ["Standard", "Large"], 1 if app.large_text else 0)
		size.custom_minimum_size.y = 44
		app.watch_edits([size])
		app.action(view, "Save Changes", func(): app.apply_text_setting(size.selected == 1), true)
		app.action(view, "Cancel", func():
			app.display_settings_editing = false
			app.edit_checks.clear()
			app.render()
		)
	else:
		app.metric(view, "Text Size", "Large" if app.large_text else "Standard")
		app.action(view, "Edit Display Settings", func():
			app.display_settings_editing = true
			app.render()
		)
	app.action(view, "Back", app.open_screen.bind("Title"))
