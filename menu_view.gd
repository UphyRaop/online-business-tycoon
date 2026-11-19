extends RefCounted

const Catalog = preload("res://catalog.gd")
const Slots = preload("res://save_slots.gd")
const Style = preload("res://corporate_theme.gd")
const Calendar = preload("res://game_calendar.gd")
const CEOProfile = preload("res://ceo_profile.gd")
const GameStore = preload("res://game_store.gd")
const LOGO = preload("res://icon.svg")

static func brand(app: Control, parent: Node) -> void:
	var header: HBoxContainer = app.row(parent)
	header.add_theme_constant_override("separation", 14)
	var mark := TextureRect.new()
	mark.texture = LOGO
	mark.custom_minimum_size = Vector2(72, 72)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(mark)
	var name: Label = app.label("Online Business Tycoon", 30, Style.GOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name)

static func title(app: Control) -> void:
	var play: VBoxContainer = app.card("Build Your Business")
	play.add_child(app.label("Each New Game has its own CEO identity, companies, finances, and save slots.", 14, Style.MUTED))
	app.action(play, "New Game", app.start_new_game, true)
	var games := GameStore.list_games()
	if games.is_empty():
		play.add_child(app.label("No saved games yet. Start a New Game to begin.", 15, Style.MUTED))
	else:
		for game in games:
			_game_card(app, game, true)
	app.action(play, "Load Game", app.open_screen.bind("Load"))
	app.action(play, "Settings", app.open_screen.bind("Settings"))

static func slots(app: Control, saving: bool) -> void:
	var back: VBoxContainer = app.card("Game Saves" if not app.active_game_id.is_empty() else "Saved Games")
	app.action(back, "Back", app.open_screen.bind("Game" if app.sim != null else "Title"))
	if saving:
		back.add_child(app.label("Save a snapshot to a manual slot. Committed gameplay changes also update Autosave.", 14, Style.MUTED))
	if app.active_game_id.is_empty():
		if saving:
			back.add_child(app.label("Choose a game before saving.", 14, Style.RED))
			return
		var games := GameStore.list_games()
		if games.is_empty():
			back.add_child(app.label("No saved games are available.", 14, Style.MUTED))
		for game in games:
			_game_card(app, game, false)
		return
	var order := [1, 2, 3, 0] if saving else [0, 1, 2, 3]
	for id in order:
		var slot := Slots.read_for_game(app.active_game_id, id)
		var view: VBoxContainer = app.card(Slots.name_for(id))
		if slot.is_empty():
			view.add_child(app.label("Unreadable save" if Slots.occupied_for_game(app.active_game_id, id) else "Empty", 15, Style.MUTED))
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
	var game_label := GameStore.save_label(slot) if not metadata.is_empty() else ""
	if not game_label.is_empty(): parent.add_child(app.label(game_label, 13, Style.GOLD))
	parent.add_child(app.label(state.company, 18, Style.GOLD))
	parent.add_child(app.label("%s · %s" % [Calendar.format(state.day), Catalog.COUNTRIES[state.country]], 15, Style.MUTED))
	parent.add_child(app.label("Saved %s" % Slots.timestamp_text(slot.saved_at) if slot.saved_at > 0 else Slots.timestamp_text(slot.saved_at), 14, Style.MUTED))
	if slot.get("recovered", false):
		parent.add_child(app.label("Recovered backup", 14, Style.GOLD))

static func _game_card(app: Control, game: Dictionary, show_slot_summary: bool) -> void:
	var game_id := str(game.get("game_id", ""))
	if game_id.is_empty(): return
	var view: VBoxContainer = app.card(str(game.get("game_name", "Saved Game")))
	app.metric(view, "CEO", str(game.get("ceo_name", "CEO not recorded")), Style.GOLD)
	var latest := GameStore.latest(game_id)
	if latest.is_empty():
		var profile := CEOProfile.load_game_profile(game_id)
		if profile.get("companies", []).is_empty():
			view.add_child(app.label("No company has been registered in this game yet.", 14, Style.MUTED))
			app.action(view, "Continue Setup", app.resume_setup.bind(game_id), true)
		else:
			view.add_child(app.label("No slot save is available. Choose an owned company archive.", 14, Style.MUTED))
			app.action(view, "Choose Company", app.choose_company_in_game.bind(game_id), true)
	else:
		if show_slot_summary: describe(app, view, latest)
		else: app.metric(view, "Last Played", Slots.timestamp_text(float(latest.get("saved_at", 0))))
		app.action(view, "Continue Game", app.resume_game.bind(game_id), true)
		app.action(view, "Choose Company", app.choose_company_in_game.bind(game_id))
	app.action(view, "Load Saves", app.open_game_slots.bind(game_id))
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
