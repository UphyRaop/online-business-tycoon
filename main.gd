extends Control

const Catalog = preload("res://catalog.gd")
const Sim = preload("res://simulation.gd")
const Slots = preload("res://save_slots.gd")
const Style = preload("res://corporate_theme.gd")
const Market = preload("res://market_view.gd")
const Operations = preload("res://operations_view.gd")
const Products = preload("res://products_view.gd")
const Menu = preload("res://menu_view.gd")
const Calendar = preload("res://game_calendar.gd")
const AdsView = preload("res://advertising_view.gd")
const StoresView = preload("res://stores_view.gd")
const StoreManager = preload("res://store_manager.gd")
const CEOProfile = preload("res://ceo_profile.gd")
const Saves = preload("res://save_store.gd")
const NAV := ["Dashboard", "Market", "Order", "Business", "Finance", "Profile"]
const STATEMENTS := ["Income Statement", "Balance Sheet", "Cash Flow Statement"]
const TOUCH_HEIGHT := 54
const PREFERENCES := "user://display.cfg"

var sim: Sim
var screen := "Title"
var large_text := false
var dirty := false
var edit_checks: Array[Callable] = []
var confirmation: ConfirmationDialog
var page := "Dashboard"
var body: VBoxContainer
var status: Label
var notice := ""
var error_notice := false
var selected_product := 0
var catalog_category := -1
var catalog_search := ""
var category_last_page := {"Dashboard": "Dashboard", "Market": "Market", "Order": "Orders", "Business": "Business", "Finance": "Finance"}
var period := 0
var statement := 0
var report_end := 0
var orders_tab := 0
var order_filter := 0
var order_page := 0
var analytics_window := 1
var campaign_id := 0
var selected_store_id := 0
var page_shell: VBoxContainer
var page_wide: VBoxContainer
var page_grid: GridContainer
var page_left_column: VBoxContainer
var page_right_column: VBoxContainer
var page_cards: Array[Control] = []
var ad_period := 0
var ad_period_end := 0
var ad_platform_filter := -1
var ad_store_filter := -1
var ad_product_filter := -1
var ad_status_filter := -1
var ads_tab := "Overview"
var stores_tab := "Stores"
var show_new_store_form := false
var ceo_profile: Dictionary = {}
var ceo_profile_corrupt := false
var identity_conflict_record: Dictionary = {}
var avatar_picker_callback: JavaScriptObject

func _ready() -> void:
	theme = Style.build()
	ceo_profile = CEOProfile.load_profile()
	ceo_profile_corrupt = (FileAccess.file_exists(CEOProfile.PATH) or FileAccess.file_exists(CEOProfile.PATH + ".bak")) and ceo_profile.is_empty()
	if ceo_profile_corrupt:
		notice = "The CEO profile could not be read. Company saves remain available; profile data was not overwritten."
		error_notice = true
	get_viewport().size_changed.connect(_update_responsive_layout)
	var settings := ConfigFile.new()
	if settings.load(PREFERENCES) == OK:
		large_text = settings.get_value("display", "large_text", false) == true
	theme.default_font_size = 18 if large_text else 16
	render()

func label(text: String, font_size: int = 16, color: Color = Style.TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size + (2 if large_text else 0))
	node.add_theme_color_override("font_color", color)
	return node

func stack(parent: Node, gap: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	if OS.has_feature("web"):
		box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func row(parent: Node) -> HBoxContainer:
	var box := HBoxContainer.new()
	if OS.has_feature("web"):
		box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	return box

func action(parent: Node, title: String, callback: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	if OS.has_feature("web"):
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.text = action_title(title)
	node.custom_minimum_size.y = TOUCH_HEIGHT
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(callback)
	var action_name := title.strip_edges().to_lower()
	if accent or action_name.begins_with("create") or action_name.begins_with("save") or action_name.begins_with("register") or action_name.begins_with("continue") or action_name.begins_with("apply") or action_name.begins_with("launch") or action_name.begins_with("open "):
		Style.primary(node)
	elif action_name.contains("delete") or action_name.contains("permanently remove") or action_name == "stop" or action_name == "deactivate":
		Style.danger(node)
	elif action_name.contains("confirm") or action_name.contains("complete") or action_name.contains("approve") or action_name.contains("refund"):
		Style.success(node)
	elif action_name == "cancel" or action_name == "back" or action_name == "close" or action_name.begins_with("discard") or action_name == "previous" or action_name == "next":
		Style.secondary(node)
	parent.add_child(node)
	return node

func action_title(value: String) -> String:
	var parts := value.split(" ", false)
	for index in parts.size():
		var word: String = parts[index]
		if word.is_empty(): continue
		var acronym := word.to_upper() in ["CPM", "CPC", "CTR", "CPA", "ROAS", "SKU", "ROI", "CEO", "ID", "UI"]
		if acronym:
			parts[index] = word.to_upper()
		else:
			parts[index] = word.substr(0, 1).to_upper() + word.substr(1)
	return " ".join(parts)

func dropdown(parent: Node, choices: Array, selected: int) -> OptionButton:
	var node := OptionButton.new()
	if OS.has_feature("web"):
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		node.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	node.custom_minimum_size.y = TOUCH_HEIGHT
	node.fit_to_longest_item = false
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for item in choices:
		node.add_item(str(item))
	node.selected = selected
	parent.add_child(node)
	return node

func field(parent: Node, caption: String, value: String, max_length: int = 48) -> LineEdit:
	parent.add_child(label(caption, 14, Style.MUTED))
	var input := LineEdit.new()
	input.text = value
	input.max_length = max_length
	input.custom_minimum_size.y = TOUCH_HEIGHT
	parent.add_child(input)
	return input

func card(title: String) -> VBoxContainer:
	return _create_card(page_grid if is_instance_valid(page_grid) else body, title)

func wide_card(title: String) -> VBoxContainer:
	return _create_card(page_wide if is_instance_valid(page_wide) else body, title)

func _create_card(parent: Node, title: String) -> VBoxContainer:
	var surface := PanelContainer.new()
	if OS.has_feature("web"):
		surface.mouse_filter = Control.MOUSE_FILTER_PASS
	surface.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.LINE, 15, 16))
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(surface)
	if parent == page_grid:
		page_cards.append(surface)
	var content := stack(surface)
	content.add_child(label(title, 20))
	return content

func divider(parent: Node) -> void:
	var line := HSeparator.new()
	parent.add_child(line)

func metric(parent: Node, caption: String, value: String, color: Color = Style.TEXT) -> void:
	var line := row(parent)
	var name := label(caption, 15, Style.MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	var amount := label(value, 15, color)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(amount)

func amount_text(cents: int, trim_zero: bool = false) -> String:
	var absolute := absi(cents)
	@warning_ignore("integer_division")
	var whole := str(absolute / 100)
	var grouped := ""
	for i in whole.length():
		if i > 0 and (whole.length() - i) % 3 == 0:
			grouped += ","
		grouped += whole[i]
	var decimals := "" if trim_zero and absolute % 100 == 0 else ".%02d" % (absolute % 100)
	return ("−" if cents < 0 else "") + grouped + decimals

func money(cents: int) -> String:
	return "%s %s" % [Catalog.CURRENCIES[sim.state.country], amount_text(cents)]

func profit_color(cents: int) -> Color:
	return Style.GREEN if cents >= 0 else Style.RED

func _update_responsive_layout() -> void:
	var viewport_width := size.x
	if is_instance_valid(page_shell):
		var horizontal_margin := 20 if viewport_width >= 900.0 else 12
		page_shell.custom_minimum_size.x = minf(1100.0, maxf(280.0, viewport_width - horizontal_margin * 2.0))
	if is_instance_valid(page_grid):
		page_grid.columns = 2 if viewport_width >= 900.0 else 1
		_reflow_page_cards()
	var nav := find_child("PrimaryNavigation", true, false) as GridContainer
	if nav != null:
		nav.columns = 3 if viewport_width < 1024.0 else 6
		for item in nav.get_children():
			if item is Button:
				item.custom_minimum_size.x = 70 if viewport_width < 600.0 else (100 if viewport_width < 1024.0 else 145)
				item.add_theme_font_size_override("font_size", 12 if viewport_width < 600.0 else 13)
	var kpis := find_child("DashboardKpis", true, false) as GridContainer
	if kpis != null:
		kpis.columns = 4 if viewport_width >= 900.0 else 2

func _reflow_page_cards() -> void:
	if not is_instance_valid(page_grid):
		return
	for panel in page_cards:
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
	for column in [page_left_column, page_right_column]:
		if is_instance_valid(column):
			if column.get_parent() == page_grid:
				page_grid.remove_child(column)
			column.queue_free()
	page_left_column = null
	page_right_column = null
	if page_cards.size() == 1 and page_grid.columns >= 2:
		page_wide.add_child(page_cards[0])
		return
	if page_grid.columns >= 2 and page_cards.size() > 1:
		page_left_column = VBoxContainer.new()
		page_left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_left_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		page_left_column.add_theme_constant_override("separation", 18)
		page_right_column = VBoxContainer.new()
		page_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_right_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		page_right_column.add_theme_constant_override("separation", 18)
		page_grid.add_child(page_left_column)
		page_grid.add_child(page_right_column)
		for panel in page_cards:
			var left_height := page_left_column.get_combined_minimum_size().y
			var right_height := page_right_column.get_combined_minimum_size().y
			if left_height <= right_height:
				page_left_column.add_child(panel)
			else:
				page_right_column.add_child(panel)
		return
	for panel in page_cards:
		page_grid.add_child(panel)

func _finish_responsive_content() -> void:
	_reflow_page_cards()

func set_notice(message: String, error: bool = false) -> void:
	notice = message
	error_notice = error
	if is_instance_valid(status):
		status.text = notice
		status.visible = not notice.is_empty()
		status.add_theme_color_override("font_color", Style.RED if error else Style.GREEN)

func persist(message: String) -> void:
	_sync_ceo_profile()
	write_progress(Slots.AUTOSAVE, message)

func write_progress(slot: int, message: String) -> bool:
	_sync_ceo_profile()
	var archive_path := CEOProfile.company_path(str(sim.state.get("company_id", "")))
	var archive_result := Saves.save(sim.state, archive_path, Time.get_unix_time_from_system())
	var result := Slots.write(slot, sim.state)
	if result != OK:
		dirty = dirty or slot == Slots.AUTOSAVE
		var reason := "Game data failed validation." if result == ERR_INVALID_DATA else error_string(result)
		set_notice("%s save failed. Progress is still in memory. %s" % [Slots.name_for(slot), reason], true)
		return false
	if archive_result != OK:
		set_notice("%s saved, but the CEO company recovery copy failed. %s" % [Slots.name_for(slot), error_string(archive_result)], true)
		return false
	var profile_result := ERR_FILE_CORRUPT if ceo_profile_corrupt else CEOProfile.save_profile(ceo_profile)
	if profile_result != OK:
		set_notice("%s saved, but the global CEO profile could not be saved. %s" % [Slots.name_for(slot), error_string(profile_result)], true)
		return false
	dirty = OS.has_feature("web") and not OS.is_userfs_persistent()
	set_notice(message + " Browser storage is unavailable. Progress may be lost on reload." if dirty else message, dirty)
	return true

func watch_edits(nodes: Array) -> Callable:
	var values := func() -> Array:
		return nodes.map(func(node): return node.text if node is LineEdit else node.selected)
	var baseline: Array = values.call()
	edit_checks.append(func(): return values.call() != baseline)
	return func(): baseline.assign(values.call())

func has_form_edits() -> bool:
	for check in edit_checks:
		if check.call():
			return true
	return false

func confirm_action(title: String, message: String, confirm_text: String, callback: Callable) -> void:
	if is_instance_valid(confirmation):
		return
	var dialog := ConfirmationDialog.new()
	confirmation = dialog
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = confirm_text
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Style.primary(dialog.get_ok_button())
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		button.custom_minimum_size.y = TOUCH_HEIGHT
	add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.hide()
		callback.call()
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			confirmation = null
			dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(350, 0))

func discard_form_then(callback: Callable) -> void:
	if has_form_edits():
		confirm_action("Discard edits?", "Some fields have unapplied changes.", "Discard edits", callback)
	else:
		callback.call()

func open_screen(target: String) -> void:
	discard_form_then(func(): show_screen(target))

func show_screen(target: String) -> void:
	screen = target
	set_notice("")
	render()

func start_new_game() -> void:
	if ceo_profile_corrupt:
		set_notice("Starting another company is disabled until the damaged CEO profile is recovered. Existing saves are untouched.", true)
		return
	if Slots.occupied(Slots.AUTOSAVE):
		var latest := Slots.latest()
		if not latest.is_empty():
			var preserved: Dictionary = latest.state.duplicate(true)
			if not ceo_profile.is_empty() and str(ceo_profile.get("full_name", "")).strip_edges().to_lower() != str(preserved.get("owner", "")).strip_edges().to_lower():
				identity_conflict_record = latest.duplicate(true)
				identity_conflict_record.context = "new_company"
				show_screen("CEO identity conflict")
				return
			if ceo_profile.is_empty():
				ceo_profile = CEOProfile.ensure({}, str(preserved.get("owner", "")))
			ceo_profile = CEOProfile.sync_company(ceo_profile, preserved)
			var archive_result := Saves.save(preserved, CEOProfile.company_path(str(preserved.company_id)), float(latest.get("saved_at", 0)))
			if archive_result != OK:
				set_notice("Could not preserve the current company before starting another. " + error_string(archive_result), true)
				return
			if CEOProfile.save_profile(ceo_profile) != OK:
				set_notice("Could not save the CEO company list. Existing game was not changed.", true)
				return
		confirm_action("Start another company?", "The current company will remain in the CEO profile. Its autosave and manual slots are preserved.", "New Company", func(): show_screen("Setup"))
	else:
		show_screen("Setup")

func continue_game() -> void:
	request_load(Slots.latest())

func load_slot(slot: int) -> void:
	request_load(Slots.read(slot))

func request_load(record: Dictionary) -> void:
	if record.is_empty():
		set_notice("No readable save was found.", true)
		return
	var autosave := Slots.read(Slots.AUTOSAVE)
	var load := func():
		if str(record.state.get("owner", "")).strip_edges().is_empty():
			identity_record = record
			show_screen("Entrepreneur name")
			return
		if not ceo_profile.is_empty() and str(ceo_profile.get("full_name", "")).strip_edges().to_lower() != str(record.state.owner).strip_edges().to_lower():
			identity_conflict_record = record
			show_screen("CEO identity conflict")
			return
		enter_game(record.state)
		set_notice("Loaded %s%s." % [Slots.name_for(record.slot), " from backup" if record.get("recovered", false) else ""])
	var replaces_autosave: bool = record.slot != Slots.AUTOSAVE and not autosave.is_empty() and record.state != autosave.state
	if dirty or has_form_edits():
		var message := "Loading this save will discard the current unsaved progress."
		if replaces_autosave:
			message += " Future gameplay will replace the current autosave."
		confirm_action("Discard unsaved progress?", message, "Load game", load)
	elif replaces_autosave:
		confirm_action("Load manual save?", "Future gameplay will replace the current autosave. This manual slot will keep its snapshot.", "Load game", load)
	else:
		load.call()

var identity_record: Dictionary = {}

func complete_identity() -> void:
	var profile := card(identity_record.state.company)
	profile.add_child(label("Enter your entrepreneur name to continue this saved company.", 15, Style.MUTED))
	var owner := field(profile, "Entrepreneur name", "")
	action(profile, "Save and continue", func():
		var name := owner.text.strip_edges()
		if name.is_empty():
			set_notice("Enter your entrepreneur name.", true)
			return
		var updated: Dictionary = identity_record.state.duplicate(true)
		updated.owner = name
		if not ceo_profile.is_empty() and str(ceo_profile.get("full_name", "")).strip_edges().to_lower() != name.to_lower():
			identity_record.state = updated
			identity_record.owner_candidate = name
			identity_conflict_record = identity_record.duplicate(true)
			show_screen("CEO identity conflict")
			return
		var result := Slots.write(identity_record.slot, updated, identity_record.saved_at)
		if result != OK:
			set_notice("Could not update this save. " + error_string(result), true)
			return
		identity_record.clear()
		enter_game(updated)
	, true)
	action(profile, "Back", func():
		identity_record.clear()
		show_screen("Load")
	)

func resolve_identity_conflict(use_existing_identity: bool) -> void:
	if identity_conflict_record.is_empty():
		show_screen("Title")
		return
	if not use_existing_identity:
		identity_conflict_record.clear()
		show_screen("Title")
		return
	var state: Dictionary = identity_conflict_record.state.duplicate(true)
	state.owner = str(ceo_profile.get("full_name", ""))
	var slot := int(identity_conflict_record.get("slot", Slots.AUTOSAVE))
	var result := Slots.write(slot, state, float(identity_conflict_record.get("saved_at", 0)))
	if result != OK:
		set_notice("Could not apply the identity choice. " + error_string(result), true)
		return
	var context := str(identity_conflict_record.get("context", ""))
	identity_conflict_record.clear()
	identity_record.clear()
	ceo_profile = CEOProfile.sync_company(ceo_profile, state)
	var archive_error := Saves.save(state, CEOProfile.company_path(str(state.company_id)), Time.get_unix_time_from_system())
	if archive_error != OK or CEOProfile.save_profile(ceo_profile) != OK:
		set_notice("The save was migrated, but its CEO profile copy could not be confirmed.", true)
		return
	if context == "new_company":
		show_screen("Setup")
	else:
		enter_game(state)

func identity_conflict_screen() -> void:
	var view := card("CEO identity needs your choice")
	view.add_child(label("This older company save names %s, while this browser profile is linked to %s. The two identities will not be merged silently." % [str(identity_conflict_record.get("state", {}).get("owner", "an earlier entrepreneur")), str(ceo_profile.get("full_name", "the current CEO"))], 15, Style.MUTED))
	view.add_child(label("You can associate this company with the current CEO profile. Company accounts and operations stay separate. Cancel leaves the save unchanged.", 14, Style.MUTED))
	action(view, "Use Current CEO Profile", func(): resolve_identity_conflict(true), true)
	action(view, "Cancel", func(): resolve_identity_conflict(false))

func _sync_ceo_profile() -> void:
	if sim == null or ceo_profile_corrupt:
		return
	if ceo_profile.is_empty():
		ceo_profile = CEOProfile.ensure({}, str(sim.state.get("owner", "")))
	if str(ceo_profile.get("full_name", "")).strip_edges().is_empty():
		ceo_profile.full_name = str(sim.state.get("owner", ""))
	sim.state.owner = str(ceo_profile.get("full_name", sim.state.get("owner", "")))
	ceo_profile = CEOProfile.sync_company(ceo_profile, sim.state)

func switch_company(company_id: String) -> void:
	var index := CEOProfile.company_index(ceo_profile, company_id)
	if index < 0:
		set_notice("That company is no longer in this CEO profile.", true)
		return
	var entry: Dictionary = ceo_profile.companies[index]
	var state := Saves.load_state(str(entry.get("save_path", CEOProfile.company_path(company_id))))
	if state.is_empty() or str(state.get("company_id", "")) != company_id:
		set_notice("The saved company could not be recovered. Other companies were left untouched.", true)
		return
	var change := func():
		var archive_result := Saves.save(state, CEOProfile.company_path(company_id), Time.get_unix_time_from_system())
		if archive_result != OK:
			set_notice("Could not preserve the selected company. " + error_string(archive_result), true)
			return
		enter_game(state)
	if dirty:
		confirm_action("Switch company?", "Save the current company before switching to %s?" % str(entry.get("name", "Company")), "Switch Company", func():
			if write_progress(Slots.AUTOSAVE, "Current company preserved."):
				change.call()
		)
	else:
		change.call()

func profile_page() -> void:
	if ceo_profile_corrupt:
		var damaged := card("CEO profile unavailable")
		damaged.add_child(label("The profile file and its backup are unreadable. Company saves remain intact. Recover the browser profile data before editing the CEO identity or switching companies.", 15, Style.RED))
		damaged.add_child(label("The game will not replace these files with a new profile automatically.", 14, Style.MUTED))
		return
	var info := card("CEO identity")
	var avatar := TextureRect.new()
	avatar.name = "CEOAvatar"
	avatar.custom_minimum_size = Vector2(128, 128)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.texture = _profile_avatar_texture()
	info.add_child(avatar)
	var full_name := field(info, "Full name", str(ceo_profile.get("full_name", sim.state.get("owner", ""))))
	var residence := field(info, "Country of residence", str(ceo_profile.get("country", "")))
	var title := field(info, "Entrepreneur title", str(ceo_profile.get("title", "Entrepreneur")))
	watch_edits([full_name, residence, title])
	var save_identity := func():
		if full_name.text.strip_edges().is_empty() or title.text.strip_edges().is_empty():
			set_notice("Enter a name and entrepreneur title.", true)
			return
		ceo_profile.full_name = full_name.text.strip_edges()
		ceo_profile.country = residence.text.strip_edges()
		ceo_profile.title = title.text.strip_edges()
		sim.state.owner = ceo_profile.full_name
		_sync_ceo_profile()
		var result := CEOProfile.save_profile(ceo_profile)
		if result != OK:
			set_notice("The CEO profile could not be saved. " + error_string(result), true)
			return
		write_progress(Slots.AUTOSAVE, "CEO profile updated.")
		refresh_view()
	action(info, "Save Profile", save_identity, true)
	action(info, "Choose Photo", open_avatar_picker)
	if not str(ceo_profile.get("avatar_data", "")).is_empty():
		action(info, "Remove Photo", func():
			CEOProfile.clear_avatar(ceo_profile)
			if write_progress(Slots.AUTOSAVE, "Profile photo removed."):
				set_notice("Profile photo removed.")
			refresh_view()
		)
	info.add_child(label("Photo stays in this browser profile. Clearing browser data or using private browsing may remove it; it is never uploaded.", 14, Style.MUTED))
	var career := card("Career progression")
	career.add_child(label("Level %d · %d XP" % [CEOProfile.level(ceo_profile), int(ceo_profile.get("xp", 0))], 20, Style.GOLD))
	career.add_child(label("%d XP to the next level" % CEOProfile.xp_to_next_level(ceo_profile), 15, Style.MUTED))
	career.add_child(label("Personal reputation: %d / 100" % int(ceo_profile.get("personal_reputation", 0)), 15, Style.MUTED))
	var achievements := card("Achievements")
	var earned: Array = ceo_profile.get("achievements", [])
	if earned.is_empty():
		achievements.add_child(label("Achievements are awarded for career milestones.", 15, Style.MUTED))
	for item in earned:
		achievements.add_child(label("• %s" % str(item.get("title", item.get("id", "Achievement"))), 15))
	var finance_card := card("Personal finance")
	finance_card.add_child(label("Personal cash: Unavailable · personal compensation accounting is not implemented.", 14, Style.MUTED))
	finance_card.add_child(label("Personal net worth: Unavailable · company assets are excluded.", 14, Style.MUTED))
	finance_card.add_child(label("Company funds and profits are separate from your personal finances.", 14, Style.MUTED))
	var companies := card("Owned companies")
	companies.add_child(label("Each company keeps its own save, operations, and accounts.", 14, Style.MUTED))
	for entry in ceo_profile.get("companies", []):
		var company_row := row(companies)
		var description := label("%s · %s" % [str(entry.get("name", "Company")), str(entry.get("country", ""))], 15, Style.GOLD)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		company_row.add_child(description)
		if str(entry.get("company_id", "")) == str(sim.state.get("company_id", "")):
			company_row.add_child(label("Current", 14, Style.GREEN))
		else:
			action(company_row, "Switch", switch_company.bind(str(entry.get("company_id", ""))))
	action(companies, "Start Another Company", start_new_game, true)

func _profile_avatar_texture() -> Texture2D:
	var encoded := str(ceo_profile.get("avatar_data", ""))
	if encoded.is_empty():
		return load("res://icon.svg")
	var bytes := Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	if image.load_jpg_from_buffer(bytes) != OK:
		return load("res://icon.svg")
	return ImageTexture.create_from_image(image)

func open_avatar_picker() -> void:
	if OS.has_feature("web"):
		avatar_picker_callback = JavaScriptBridge.create_callback(_on_web_avatar_selected)
		JavaScriptBridge.get_interface("window").obtAvatarSelected = avatar_picker_callback
		JavaScriptBridge.eval("(function(){const i=document.createElement('input');i.type='file';i.accept='image/jpeg,image/png,image/webp';i.onchange=function(){const f=i.files&&i.files[0];if(!f)return;if(f.size>8388608){window.obtAvatarSelected('error:Photo must be 8 MB or smaller.');return;}if(!['image/jpeg','image/png','image/webp'].includes(f.type)){window.obtAvatarSelected('error:Choose a JPEG, PNG, or WebP image.');return;}const r=new FileReader();r.onerror=function(){window.obtAvatarSelected('error:The selected image could not be read.');};r.onload=function(){const im=new Image();im.onerror=function(){window.obtAvatarSelected('error:The selected image is invalid.');};im.onload=function(){const n=256,c=document.createElement('canvas');c.width=n;c.height=n;const x=c.getContext('2d'),s=Math.min(im.width,im.height),l=(im.width-s)/2,t=(im.height-s)/2;x.drawImage(im,l,t,s,s,0,0,n,n);window.obtAvatarSelected(c.toDataURL('image/jpeg',0.82));};im.src=r.result;};r.readAsDataURL(f);};i.click();})();")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.jpg, *.jpeg, *.png, *.webp", "Images")
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var image := Image.new()
		var error := image.load(path)
		if error != OK:
			set_notice("Could not read the selected image.", true)
		else:
			var data := image.save_png_to_buffer()
			error = CEOProfile.add_avatar(ceo_profile, "image/png", data)
			if error != OK:
				set_notice("Could not store this photo. Try an image under 512 KB.", true)
			else:
				write_progress(Slots.AUTOSAVE, "Profile photo saved locally.")
				refresh_view()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func _on_web_avatar_selected(args: Array) -> void:
	if args.is_empty():
		return
	var value := str(args[0])
	if value.begins_with("error:"):
		set_notice(value.trim_prefix("error:"), true)
		return
	var parts := value.split(",", false, 1)
	if parts.size() != 2:
		set_notice("The selected image could not be decoded.", true)
		return
	var mime := parts[0].trim_prefix("data:").get_slice(";", 0)
	var result := CEOProfile.add_avatar(ceo_profile, mime, Marshalls.base64_to_raw(parts[1]))
	if result != OK:
		set_notice("Could not store the selected image. Choose another photo.", true)
		return
	write_progress(Slots.AUTOSAVE, "Profile photo saved locally.")
	refresh_view()

func enter_game(data: Dictionary) -> void:
	sim = Sim.new(data)
	_sync_ceo_profile()
	var profile_error := ERR_FILE_CORRUPT if ceo_profile_corrupt else CEOProfile.save_profile(ceo_profile)
	var archive_error := Saves.save(sim.state, CEOProfile.company_path(str(sim.state.company_id)), Time.get_unix_time_from_system())
	dirty = false
	screen = "Game"
	page = "Dashboard"
	selected_product = 0
	report_end = 0
	order_page = 0
	set_notice("")
	if profile_error != OK or archive_error != OK:
		set_notice("Company loaded, but its CEO profile recovery copy could not be saved.", true)
	render()

func save_to_slot(slot: int) -> void:
	var write := func():
		write_progress(slot, "Saved to manual slot %d." % slot)
		refresh_view()
	if Slots.occupied(slot):
		confirm_action("Overwrite manual slot %d?" % slot, "Replace the saved snapshot in this slot with your current game?", "Overwrite", write)
	else:
		write.call()

func delete_save(slot: int) -> void:
	confirm_action("Delete %s?" % Slots.name_for(slot).to_lower(),
		"Delete this save and its recovery copy?", "Delete", func():
		var error := Slots.delete_slot(slot)
		if error == OK:
			set_notice("%s deleted." % Slots.name_for(slot))
		else:
			set_notice("Could not delete %s. %s" % [Slots.name_for(slot).to_lower(), error_string(error)], true)
		refresh_view()
	)

func leave_game() -> void:
	var exit_to_title := func():
		sim = null
		dirty = false
		show_screen("Title")
	if dirty or has_form_edits():
		confirm_action("Discard unsaved progress?", "Returning to the main menu will discard your unsaved progress or edits.", "Main Menu", exit_to_title)
	else:
		exit_to_title.call()

func apply_text_setting(enabled: bool) -> void:
	var settings := ConfigFile.new()
	settings.set_value("display", "large_text", enabled)
	var result := settings.save(PREFERENCES)
	large_text = enabled
	theme.default_font_size = 18 if enabled else 16
	set_notice("Settings saved." if result == OK else "Applied for this session. Settings could not be saved.", result != OK)
	render()

func set_store_active(store_id: int, enabled: bool) -> void:
	var error := StoreManager.set_active(sim.state, store_id, enabled)
	if not error.is_empty():
		set_notice(error, true)
		return
	var store: Dictionary = StoreManager.get_store(sim.state, store_id)
	persist("%s is now %s." % [store.name, "active" if enabled else "inactive"])
	refresh_view()

func navigate(target: String) -> void:
	# Older in-session or serialized navigation targets remain valid.
	if target == "Growth": target = "Advertising"
	# Retain compatibility with the previous route label without changing saves.
	if target == "Store Management": target = "Management"
	if target == "Order": target = "Orders"
	if target in NAV:
		if target == primary_category(page):
			target = "Orders" if target == "Order" else target
		else:
			target = str(category_last_page.get(target, target))
	if target != "Management": show_new_store_form = false
	discard_form_then(func():
		page = target
		category_last_page[primary_category(target)] = target
		set_notice("")
		render()
	)

func primary_category(target: String) -> String:
	if target in ["Market", "My Products", "Management", "Store Listings"]: return "Market"
	if target in ["Orders", "Pre-orders"]: return "Order"
	if target in ["Business", "Advertising", "Campaign Manager", "Campaign Details", "Advertising Analytics"]: return "Business"
	if target in ["Finance", "Store Profitability"]: return "Finance"
	if target == "Profile": return "Profile"
	return "Dashboard"

func route_secondary(target: String) -> void:
	if target == "Pre-orders":
		discard_form_then(func():
			page = target
			category_last_page["Order"] = target
			set_notice("")
			render()
		)
		return
	if target == "Returns & Service":
		orders_tab = 1
		target = "Orders"
	navigate(target)

func primary_navigation(parent: Node) -> void:
	var viewport_width := size.x
	var nav := GridContainer.new()
	nav.name = "PrimaryNavigation"
	nav.size_flags_horizontal = Control.SIZE_FILL
	nav.columns = 3 if viewport_width < 1024.0 else 6
	nav.add_theme_constant_override("h_separation", 6)
	nav.add_theme_constant_override("v_separation", 6)
	parent.add_child(nav)
	for target in NAV:
		var tab := action(nav, target, navigate.bind(target), target == primary_category(page))
		tab.add_theme_font_size_override("font_size", 12 if viewport_width < 600.0 else 13)
		tab.clip_text = true
		tab.custom_minimum_size.x = 70 if viewport_width < 600.0 else (100 if viewport_width < 1024.0 else 145)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for button_state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style: StyleBox = tab.get_theme_stylebox(button_state).duplicate()
			style.content_margin_left = 4
			style.content_margin_right = 4
			tab.add_theme_stylebox_override(button_state, style)

func secondary_navigation(parent: Node) -> void:
	var category := primary_category(page)
	var routes: Array = []
	match category:
		"Market": routes = [["Product Catalogue", "Market"], ["My Products", "My Products"], ["Management", "Management"], ["Product Listings", "Store Listings"]]
		"Order": routes = [["Customer Orders", "Orders"], ["Pre-orders", "Pre-orders"], ["Returns and Service", "Returns & Service"]]
		"Business": routes = [["Company Profile", "Business"], ["Advertising", "Advertising"], ["Campaign Manager", "Campaign Manager"], ["Advertising Analytics", "Advertising Analytics"]]
		"Finance": routes = [["Statements", "Finance"], ["Store Profitability", "Store Profitability"]]
		_: return
	var strip := FlowContainer.new()
	strip.add_theme_constant_override("h_separation", 8)
	strip.add_theme_constant_override("v_separation", 6)
	parent.add_child(strip)
	for route in routes:
		var title: String = route[0]
		var target: String = route[1]
		var selected := false
		if target == "Returns & Service": selected = page == "Orders" and orders_tab == 1
		elif target == "Pre-orders": selected = page == "Pre-orders"
		elif target == "Customer Orders": selected = page == "Orders" and orders_tab != 1
		elif target == "Store Profitability": selected = page == "Store Profitability"
		else: selected = page == target
		var tab: Button = action(strip, title, route_secondary.bind(target), selected)
		tab.custom_minimum_size.x = 150

func render() -> void:
	edit_checks.clear()
	page_shell = null
	page_wide = null
	page_grid = null
	page_left_column = null
	page_right_column = null
	page_cards.clear()
	for child in get_children():
		if child == confirmation:
			confirmation.hide()
		remove_child(child)
		child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.color = Style.BG
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_width := size.x
	var horizontal_margin := 20 if viewport_width >= 900.0 else 12
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, horizontal_margin if side in ["left", "right"] else 16)
	var centering := HBoxContainer.new()
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centering.add_theme_constant_override("separation", 0)
	margin.add_child(centering)
	var left_space := Control.new()
	left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(left_space)
	page_shell = stack(centering, 12)
	page_shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_shell.custom_minimum_size.x = minf(1100.0, maxf(280.0, viewport_width - horizontal_margin * 2.0))
	var right_space := Control.new()
	right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(right_space)
	var shell := page_shell
	var masthead := stack(shell, 3)
	if screen != "Title":
		masthead.add_child(label("ONLINE BUSINESS TYCOON", 13, Style.GOLD))
	if screen == "Game":
		var heading := row(masthead)
		var title := label(page, 30)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		action(heading, "Save Game", open_screen.bind("Save")).size_flags_horizontal = Control.SIZE_SHRINK_END
		action(heading, "Menu", leave_game).size_flags_horizontal = Control.SIZE_SHRINK_END
		var game_date := label("%s  /  %s" % [Calendar.format(sim.state.day), Catalog.COUNTRIES[sim.state.country]], 14, Style.MUTED)
		game_date.name = "GameDate"
		masthead.add_child(game_date)
		primary_navigation(masthead)
	elif screen == "Title":
		Menu.brand(self, masthead)
	else:
		var titles := {"Setup": "Start your business", "Load": "Load Game", "Save": "Save Game", "Settings": "Settings",
			"Campaign Manager": "Campaign Manager", "Campaign Details": "Campaign Details",
			"Advertising Analytics": "Advertising Analytics", "Management": "Management", "Store Listings": "Store Listings",
			"CEO identity conflict": "Identity choice"}
		masthead.add_child(label(titles.get(screen, screen), 30))
	if screen == "Game":
		secondary_navigation(shell)
	divider(shell)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	shell.add_child(scroll)
	body = stack(scroll, 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_wide = stack(body, 12)
	page_wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_grid = GridContainer.new()
	page_grid.columns = 2 if size.x >= 900.0 else 1
	page_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_grid.add_theme_constant_override("h_separation", 18)
	page_grid.add_theme_constant_override("v_separation", 18)
	body.add_child(page_grid)
	status = label(notice, 14, Style.RED if error_notice else Style.GREEN)
	status.visible = not notice.is_empty()
	shell.add_child(status)
	if screen != "Game":
		match screen:
			"Title": Menu.title(self)
			"Setup": setup()
			"Entrepreneur name": complete_identity()
			"CEO identity conflict": identity_conflict_screen()
			"Load": Menu.slots(self, false)
			"Save": Menu.slots(self, true)
			"Settings": Menu.settings(self)
			"Campaign Manager": AdsView.manager(self)
			"Campaign Details": AdsView.details(self)
			"Advertising Analytics": AdsView.analytics(self)
			"Management": StoresView.management(self)
			"Store Listings": StoresView.listings(self)
		_finish_responsive_content()
		return
	match page:
		"Dashboard": dashboard()
		"Market": Market.show(self)
		"My Products": Products.show(self)
		"Orders": Operations.show(self)
		"Pre-orders": Operations.preorders(self)
		"Business": business()
		"Finance": finance()
		"Profile": profile_page()
		"Advertising": AdsView.overview(self)
		"Campaign Manager": AdsView.manager(self)
		"Campaign Details": AdsView.details(self)
		"Advertising Analytics": AdsView.analytics(self)
		"Management": StoresView.management(self)
		"Store Profitability": StoresView.profitability(self)
		"Store Listings": StoresView.listings(self)
	_finish_responsive_content()

func setup() -> void:
	var details := card("Company registration")
	details.add_child(label("Register your company and entrepreneur profile. Create stores later under Market / Management.", 15, Style.MUTED))
	var owner := field(details, "Entrepreneur name", str(ceo_profile.get("full_name", "")))
	if not ceo_profile.is_empty():
		owner.editable = false
		details.add_child(label("This company will belong to your existing CEO profile.", 14, Style.MUTED))
	var company := field(details, "Company name", "")
	details.add_child(label("Starting country", 14, Style.MUTED))
	var country := dropdown(details, Catalog.COUNTRIES, 0)
	details.add_child(label("Difficulty", 14, Style.MUTED))
	var difficulty := dropdown(details, Catalog.DIFFICULTIES, 1)
	var capital := label("", 14, Style.GOLD)
	details.add_child(capital)
	var update_capital := func(_index: int):
		var cents := Catalog.local_cents(country.selected, Catalog.CAPITAL[difficulty.selected])
		capital.text = "Opening capital  %s %s" % [Catalog.CURRENCIES[country.selected], amount_text(cents)]
	country.item_selected.connect(update_capital)
	difficulty.item_selected.connect(update_capital)
	update_capital.call(0)
	watch_edits([owner, company, country, difficulty])
	action(details, "Register company", func():
		var owner_name := owner.text.strip_edges()
		var company_name := company.text.strip_edges()
		if owner_name.is_empty() or company_name.is_empty():
			set_notice("Enter an entrepreneur name and a company name.", true)
			return
		if not ceo_profile.is_empty():
			owner_name = str(ceo_profile.get("full_name", owner_name))
		var new_state := Sim.register(owner_name, company_name, "",
			country.selected, difficulty.selected, 0, randi())
		enter_game(new_state)
		persist("Company registered.")
	, true)
	action(details, "Back", open_screen.bind("Title"))

func dashboard() -> void:
	var totals := sim.report(sim.state.day)
	var overview := wide_card(sim.state.company)
	overview.add_child(label(sim.state.owner + ", CEO", 16, Style.MUTED))
	var active_marketplaces := 0
	var active_websites := 0
	for store in sim.state.stores:
		if not store.active: continue
		if int(store.type) == 0: active_marketplaces += 1
		else: active_websites += 1
	var active_campaigns := 0
	for campaign in sim.state.advertising.campaigns.values():
		if campaign.status == "active": active_campaigns += 1
	var kpis := GridContainer.new()
	kpis.columns = 4 if size.x >= 900.0 else 2
	kpis.add_theme_constant_override("h_separation", 8)
	kpis.add_theme_constant_override("v_separation", 8)
	kpis.name = "DashboardKpis"
	overview.add_child(kpis)
	_add_kpi(kpis, "Bank Balance", money(totals.closing_cash), Style.GOLD)
	_add_kpi(kpis, "Lifetime net sales", money(totals.sales - totals.refunds))
	_add_kpi(kpis, "Lifetime net profit", money(Sim.net(totals)), profit_color(Sim.net(totals)))
	_add_kpi(kpis, "Orders fulfilled", str(totals.channels[0].orders + totals.channels[1].orders + totals.channels[2].orders))
	_add_kpi(kpis, "Open orders", str(sim.state.active_orders.size()))
	_add_kpi(kpis, "Store reputation", "%d / 100" % sim.state.reputation)
	_add_kpi(kpis, "Marketplace stores · Websites", "%d · %d" % [active_marketplaces, active_websites])
	_add_kpi(kpis, "Active campaigns · Lifetime spend", "%d · %s" % [active_campaigns, money(totals.advertising)])
	action(overview, "My Products", navigate.bind("My Products"))
	var alerts: VBoxContainer = card("Business Alerts")
	if active_marketplaces == 0 and active_websites == 0:
		alerts.add_child(label("Create a marketplace store or website to start selling.", 14, Style.GOLD))
	if active_campaigns == 0:
		alerts.add_child(label("No advertising campaigns are currently active.", 14, Style.MUTED))
	var outstanding_preorders := 0
	var overdue_preorders := 0
	for order in sim.state.orders.values():
		if order.get("preorder", false) and order.status not in ["delivered", "cancelled"]:
			outstanding_preorders += 1
			if int(order.get("expected_restock", 0)) > 0 and sim.state.day > int(order.expected_restock): overdue_preorders += 1
	if outstanding_preorders > 0:
		alerts.add_child(label("%d customer pre-orders are waiting for stock or fulfillment." % outstanding_preorders, 14, Style.GOLD))
	if overdue_preorders > 0:
		alerts.add_child(label("%d pre-orders are past their estimated replenishment date." % overdue_preorders, 14, Style.RED))
	var delayed_shipments := 0
	for batch in sim.state.inbound:
		if batch.get("delayed", false): delayed_shipments += 1
	if delayed_shipments > 0:
		alerts.add_child(label("%d supplier shipments are delayed." % delayed_shipments, 14, Style.GOLD))
	if alerts.get_child_count() == 1:
		alerts.add_child(label("No business alerts.", 14, Style.MUTED))
	var time := card("Advance time")
	time.add_child(label("Each simulated day generates orders and charges operating expenses.", 14, Style.MUTED))
	var controls := row(time)
	for days in [1, 2, 7, 30]:
		action(controls, "+%d" % days, advance.bind(days), days == 1)
	var has_listing := false
	for item in sim.state.products.values():
		if item.listed:
			has_listing = true
	if not has_listing:
		var next := card("Open your store")
		next.add_child(label("Choose a product in Market, purchase stock from a supplier, then publish your listing.", 15, Style.MUTED))
		action(next, "Browse product catalog", navigate.bind("Market"), true)
	channel_cards(totals, "Lifetime")

func _add_kpi(parent: GridContainer, caption: String, value: String, color: Color = Style.TEXT) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 9, 10))
	panel.custom_minimum_size.x = 105
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := stack(panel, 3)
	content.add_child(label(caption, 12, Style.MUTED))
	content.add_child(label(value, 16, color))

func advance(days: int) -> void:
	sim.advance(days)
	report_end = 0
	var result := sim.report(days, sim.state.day - 1)
	var orders: int = result.channels[0].orders + result.channels[1].orders
	var placed: int = result.channels[0].placed + result.channels[1].placed
	persist("Advanced %d %s · %d placed · %d delivered" % [days, "day" if days == 1 else "days", placed, orders])
	render()

func channel_cards(report: Dictionary, scope: String) -> void:
	var channels := card("Sales by channel")
	channels.add_child(label(scope, 14, Style.MUTED))
	for channel in Catalog.FEES.size():
		if channel > 0:
			divider(channels)
		var channel_title: String = Catalog.CHANNELS[channel]
		channels.add_child(label(channel_title, 17, Style.GOLD))
		var totals: Dictionary = report.channels[channel]
		if not sim.channel_enabled(channel) and totals.orders == 0 and totals.hosting == 0 and totals.shipping == 0 and totals.refunds == 0:
			channels.add_child(label("Inactive", 14, Style.MUTED))
			continue
		metric(channels, "%d delivered · Net sales" % totals.orders, money(totals.sales - totals.refunds))
		var contribution: int = totals.sales - totals.refunds - totals.cogs - totals.fees - totals.hosting - totals.shipping
		metric(channels, "After channel costs", money(contribution), profit_color(contribution))
	if report.channels[2].orders > 0 or report.channels[2].sales != 0:
		divider(channels)
		metric(channels, "Prototype combined sales", money(report.channels[2].sales))
	if report.legacy != 0:
		channels.add_child(label("Prototype expenses appear in the Income Statement without a channel breakdown.", 13, Style.MUTED))

func open_product(product: int) -> void:
	discard_form_then(func():
		selected_product = product
		show_product_editor()
	)

func show_product_editor() -> void:
	page = "Market"
	set_notice("")
	render()

func refresh_view() -> void:
	var previous: int = body.get_parent().scroll_vertical
	render()
	body.get_parent().set_deferred("scroll_vertical", previous)

func price_cents(value: String) -> int:
	var text := value.strip_edges()
	if not text.is_valid_float():
		return 0
	var price := text.to_float()
	if not is_finite(price) or price < 0.01 or price > 100_000_000.0:
		return 0
	return roundi(price * 100.0)

func business() -> void:
	var profile := card("Company profile")
	metric(profile, "Owned stores", str(sim.state.stores.size()))
	metric(profile, "Registration", "Active")
	metric(profile, "Difficulty", Catalog.DIFFICULTIES[sim.state.difficulty])
	var owner := field(profile, "Entrepreneur / CEO", str(ceo_profile.get("full_name", sim.state.owner)))
	var company := field(profile, "Company name", sim.state.company)
	var names_saved := watch_edits([owner, company])
	action(profile, "Save company profile", func():
		var owner_name := owner.text.strip_edges()
		var company_name := company.text.strip_edges()
		if owner_name.is_empty() or company_name.is_empty():
			set_notice("Enter an entrepreneur name and company name.", true)
			return
		ceo_profile.full_name = owner_name
		sim.state.owner = owner_name
		sim.state.company = company_name
		_sync_ceo_profile()
		names_saved.call()
		persist("Company profile saved.")
	)
	action(card("Management"), "Management", navigate.bind("Management"), true)
	action(card("Inventory and listings"), "My Products", navigate.bind("My Products"))
	action(card("Business advertising"), "Advertising", navigate.bind("Advertising"))
	var saves := card("Local progress")
	saves.add_child(label("Progress saves automatically when you make changes or advance time.", 14, Style.MUTED))
	var controls := row(saves)
	action(controls, "Manage Saves", open_screen.bind("Save"))
	action(controls, "Load Game", open_screen.bind("Load"))

func finance() -> void:
	var controls := card("Financial statements")
	var selection := dropdown(controls, Calendar.PERIODS, period)
	selection.item_selected.connect(func(index: int):
		period = index
		render()
	)
	var anchor: int = report_end if report_end > 0 else sim.state.day
	var boundaries := Calendar.bounds(period, anchor)
	var report := sim.calendar_report(period, anchor)
	var scope := Calendar.format_range(boundaries.x, boundaries.y)
	controls.add_child(label(scope, 15, Style.GOLD))
	if report.start != boundaries.x or report.end != boundaries.y or report.end == sim.state.day:
		controls.add_child(label("Recorded: %s%s" % [Calendar.format_range(report.start, report.end),
			" · In progress" if report.end == sim.state.day else ""], 13, Style.MUTED))
	var dates := row(controls)
	var older := action(dates, "Previous", change_report_end.bind(boundaries.x - 1))
	older.disabled = boundaries.x <= 1
	var newer := action(dates, "Next", change_report_end.bind(boundaries.y + 1))
	newer.disabled = boundaries.y >= sim.state.day
	var selector := dropdown(controls, STATEMENTS, statement)
	selector.item_selected.connect(func(index: int):
		statement = index
		render()
	)
	match statement:
		0: income_statement(report)
		1: balance_sheet(report)
		2: cash_flow(report)
	channel_cards(report, scope)

func change_report_end(day: int) -> void:
	report_end = day
	render()

func income_statement(report: Dictionary) -> void:
	var view := card(STATEMENTS[0])
	metric(view, "Sales revenue", money(report.sales))
	metric(view, "Refunds", money(-report.refunds))
	metric(view, "Net sales", money(report.sales - report.refunds))
	metric(view, "Cost of goods sold", money(-report.cogs))
	view.add_child(label("Includes inbound freight on units sold.", 13, Style.MUTED))
	var gross: int = report.sales - report.refunds - report.cogs
	metric(view, "Gross profit", money(gross), profit_color(gross))
	divider(view)
	metric(view, "Channel fees", money(-report.fees))
	metric(view, "Outbound shipping", money(-report.shipping))
	metric(view, "Operating overhead", money(-report.overhead))
	metric(view, "Website hosting", money(-report.hosting))
	metric(view, "Advertising", money(-report.advertising))
	metric(view, "Store setup costs", money(-report.store_setup))
	metric(view, "Additional store operating costs", money(-report.store_expenses))
	if report.legacy != 0:
		metric(view, "Prototype expenses", money(-report.legacy))
	divider(view)
	metric(view, "Net profit", money(Sim.net(report)), profit_color(Sim.net(report)))

func balance_sheet(report: Dictionary) -> void:
	var view := card(STATEMENTS[1])
	view.add_child(label("As of %s" % Calendar.format(report.end), 14, Style.MUTED))
	metric(view, "Bank Balance", money(report.closing_cash))
	metric(view, "Inventory at cost", money(report.inventory))
	metric(view, "Supplier goods in transit", money(report.goods_in_transit))
	view.add_child(label("Inventory is on hand or reserved for warehouse fulfillment.", 13, Style.MUTED))
	metric(view, "Total assets", money(report.assets), Style.GOLD)
	divider(view)
	metric(view, "Overdraft liability", money(report.overdraft))
	metric(view, "Customer deposits", money(report.customer_deposits))
	metric(view, "Contributed capital", money(report.equity_capital))
	metric(view, "Retained earnings", money(report.retained))
	metric(view, "Total liabilities and equity", money(report.overdraft + report.customer_deposits + report.equity_capital + report.retained), Style.GOLD)

func cash_flow(report: Dictionary) -> void:
	var view := card(STATEMENTS[2])
	metric(view, "Opening cash", money(report.opening_cash))
	divider(view)
	metric(view, "Receipts from customers", money(report.sales + report.deposits))
	metric(view, "Refunds paid", money(-report.refunds))
	metric(view, "Warehouse goods paid", money(-(report.purchases - (report.inbound_freight - report.direct_inbound_freight))))
	metric(view, "Supplier-direct goods paid", money(-(report.direct_purchases - report.direct_inbound_freight)))
	metric(view, "Inbound freight paid", money(-report.inbound_freight))
	metric(view, "Outbound shipping paid", money(-report.shipping))
	metric(view, "Advertising paid", money(-report.advertising))
	metric(view, "Store setup paid", money(-report.store_setup))
	metric(view, "Additional store expenses paid", money(-report.store_expenses))
	metric(view, "Other operating payments", money(-report.fees - report.overhead - report.hosting - report.legacy))
	metric(view, "Owner investment", money(report.capital))
	metric(view, "Net change in cash", money(Sim.cash_change(report)), profit_color(Sim.cash_change(report)))
	divider(view)
	metric(view, "Closing cash", money(report.closing_cash), Style.GOLD)
