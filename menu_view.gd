extends RefCounted

const Catalog = preload("res://catalog.gd")
const Slots = preload("res://save_slots.gd")
const Style = preload("res://corporate_theme.gd")
const Calendar = preload("res://game_calendar.gd")
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
	var latest := Slots.latest()
	var play: VBoxContainer = app.card("Build your business")
	var resume: Button = app.action(play, "Continue Game", app.continue_game, true)
	resume.disabled = latest.is_empty()
	if not latest.is_empty():
		describe(app, play, latest)
	app.action(play, "New Game", app.start_new_game, latest.is_empty())
	app.action(play, "Load Game", app.open_screen.bind("Load"))
	app.action(play, "Settings", app.open_screen.bind("Settings"))

static func slots(app: Control, saving: bool) -> void:
	var back: VBoxContainer = app.card("Local saves")
	app.action(back, "Back", app.open_screen.bind("Game" if app.sim != null else "Title"))
	if saving:
		back.add_child(app.label("Save a snapshot to a manual slot. Committed gameplay changes also update Autosave.", 14, Style.MUTED))
	var order := [1, 2, 3, 0] if saving else [0, 1, 2, 3]
	for id in order:
		var slot := Slots.read(id)
		var view: VBoxContainer = app.card(Slots.name_for(id))
		if slot.is_empty():
			view.add_child(app.label("Unreadable save" if Slots.occupied(id) else "Empty", 15, Style.MUTED))
		else:
			describe(app, view, slot)
		if saving:
			if id != Slots.AUTOSAVE:
				app.action(view, "Save to slot %d" % id, app.save_to_slot.bind(id), true)
		if not slot.is_empty():
			app.action(view, "Load autosave" if id == Slots.AUTOSAVE else "Load slot %d" % id, app.load_slot.bind(id), not saving)
		if Slots.occupied(id):
			app.action(view, "Delete autosave" if id == Slots.AUTOSAVE else "Delete slot %d" % id, app.delete_save.bind(id))

static func describe(app: Control, parent: Node, slot: Dictionary) -> void:
	var state: Dictionary = slot.state
	parent.add_child(app.label(state.company, 18, Style.GOLD))
	parent.add_child(app.label("%s · %s" % [Calendar.format(state.day), Catalog.COUNTRIES[state.country]], 15, Style.MUTED))
	parent.add_child(app.label("Saved %s" % Slots.timestamp_text(slot.saved_at) if slot.saved_at > 0 else Slots.timestamp_text(slot.saved_at), 14, Style.MUTED))
	if slot.get("recovered", false):
		parent.add_child(app.label("Recovered backup", 14, Style.GOLD))

static func settings(app: Control) -> void:
	var view: VBoxContainer = app.card("Display")
	view.add_child(app.label("Text size", 15, Style.MUTED))
	var size: OptionButton = app.dropdown(view, ["Standard", "Large"], 1 if app.large_text else 0)
	app.watch_edits([size])
	app.action(view, "Apply settings", func(): app.apply_text_setting(size.selected == 1), true)
	app.action(view, "Back", app.open_screen.bind("Title"))
