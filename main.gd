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
const AvatarCrop = preload("res://avatar_crop_viewport.gd")
const FinanceManagement = preload("res://finance_management.gd")
const FinanceChart = preload("res://ads_chart.gd")
const ChartLegend = preload("res://chart_legend.gd")
const CompanySale = preload("res://company_sale.gd")
const InventoryOverview = preload("res://dashboard_inventory.gd")
const PortraitFrame = preload("res://portrait_frame.gd")
const GameStore = preload("res://game_store.gd")
const NAV := ["Dashboard", "Market", "Order", "Business", "Marketing", "Finance", "Profile"]
const NAV_ICON_PATHS := {
	"Dashboard": "res://assets/navigation/dashboard.svg",
	"Market": "res://assets/navigation/market.svg",
	"Order": "res://assets/navigation/orders.svg",
	"Business": "res://assets/navigation/business.svg",
	"Marketing": "res://assets/navigation/marketing.svg",
	"Finance": "res://assets/navigation/finance.svg",
	"Profile": "res://assets/navigation/profile.svg",
}
const DRAWER_ICON_PATHS := {
	"Menu": "res://assets/navigation/menu.svg",
	"Close": "res://assets/navigation/close.svg",
	"Save Game": "res://assets/navigation/save.svg",
	"Main Menu": "res://assets/navigation/exit.svg",
}
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
var category_last_page := {"Dashboard": "Dashboard", "Market": "Market", "Order": "Orders", "Business": "Business", "Marketing": "Advertising", "Finance": "Finance"}
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
var active_game_id := ""
var pending_ceo_name := ""
var identity_conflict_record: Dictionary = {}
var avatar_picker_callback: JavaScriptObject
var profile_editing := false
var profile_edit_snapshot: Dictionary = {}
var company_profile_editing := false
var store_listing_editing := false
var campaign_editing := false
var shipping_settings_editing := false
var display_settings_editing := false
var avatar_crop_source: Image
var navigation_overlay: Control
var navigation_drawer: PanelContainer
var navigation_open := false
var navigation_toggle: Button
var bank_balance_label: Label

func _ready() -> void:
	theme = Style.build()
	var migration := GameStore.migrate_legacy()
	if not str(migration.get("error", "")).is_empty():
		notice = "Some older saves could not be migrated yet. Their original files remain available. " + str(migration.error)
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
	Style.apply_button_role(node, Style.ROLE_PRIMARY if accent else Style.button_role_for_action(title))
	parent.add_child(node)
	return node

func secondary_tab(parent: Node, title: String, callback: Callable, selected: bool = false) -> Button:
	var node := action(parent, title, callback)
	node.custom_minimum_size = Vector2(120, 44)
	node.add_theme_font_size_override("font_size", 12)
	Style.secondary(node)
	node.add_theme_stylebox_override("normal", Style.box(Style.SURFACE, Style.GOLD if selected else Style.LINE, 8, 7))
	node.add_theme_stylebox_override("hover", Style.box(Style.SURFACE.lightened(0.08), Style.GOLD if selected else Style.LINE.lightened(0.16), 8, 7))
	if selected:
		node.add_theme_color_override("font_color", Style.GOLD)
		node.add_theme_color_override("font_hover_color", Style.GOLD)
	return node

func _style_secondary_navigation_tab(node: Button, selected: bool) -> void:
	node.flat = true
	node.custom_minimum_size.y = 44
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.border_color = Style.GOLD if selected else Color.TRANSPARENT
	normal.border_width_bottom = 2 if selected else 0
	normal.set_content_margin_all(7)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Style.SURFACE.lightened(0.05)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Style.GOLD
	focus.set_border_width_all(1)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_color_override("font_color", Style.GOLD if selected else Style.MUTED)
	node.add_theme_color_override("font_hover_color", Style.TEXT)
	node.add_theme_color_override("font_pressed_color", Style.GOLD)

func action_title(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.begins_with("Manage "):
		return "Manage " + trimmed.substr(7)
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
	var line: BoxContainer = VBoxContainer.new() if size.x < 600.0 else row(parent)
	if line is VBoxContainer:
		line.add_theme_constant_override("separation", 2)
		parent.add_child(line)
	var name := label(caption, 15, Style.MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(name)
	var amount := label(value, 15, color)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var inventory_panel := find_child("DashboardInventoryOverview", true, false) as PanelContainer
	var mobile_layout := viewport_width < 600.0
	if inventory_panel != null and bool(inventory_panel.get_meta("mobile_layout", false)) != mobile_layout:
		var inventory_parent := inventory_panel.get_parent()
		var inventory_index := inventory_panel.get_index()
		inventory_parent.remove_child(inventory_panel)
		inventory_panel.queue_free()
		var replacement := InventoryOverview.build(sim, mobile_layout)
		inventory_parent.add_child(replacement)
		inventory_parent.move_child(replacement, inventory_index)
	var date_label := find_child("GameDate", true, false) as Label
	if date_label != null and sim != null:
		date_label.text = _game_date_text(viewport_width)
		date_label.tooltip_text = Calendar.format(sim.state.day) + " | " + Catalog.COUNTRIES[sim.state.country]
	if page == "Profile":
		var identity_layout := find_child("CEOIdentityLayout", true, false) as BoxContainer
		if identity_layout != null:
			if (identity_layout is HBoxContainer) != (viewport_width >= 600.0):
				render()
				return
	if is_instance_valid(page_shell):
		var horizontal_margin := 20 if viewport_width >= 900.0 else 12
		page_shell.custom_minimum_size.x = minf(1100.0, maxf(280.0, viewport_width - horizontal_margin * 2.0))
	if is_instance_valid(page_grid):
		page_grid.columns = 2 if viewport_width >= 900.0 else 1
		_reflow_page_cards()
	if is_instance_valid(navigation_drawer):
		var drawer_width := clampf(viewport_width * 0.78, 260.0, 320.0)
		navigation_drawer.offset_right = drawer_width
	if is_instance_valid(navigation_toggle):
		navigation_toggle.custom_minimum_size.x = 72 if viewport_width < 600.0 else 92
	if is_instance_valid(bank_balance_label):
		bank_balance_label.custom_minimum_size.x = 128 if viewport_width < 600.0 else 245
		_refresh_bank_balance()
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
	_refresh_bank_balance()

func _refresh_bank_balance() -> void:
	if not is_instance_valid(bank_balance_label) or sim == null or screen != "Game":
		return
	var balance := money(int(sim.state.get("cash", 0)))
	if size.x < 600.0:
		bank_balance_label.text = "Bank Balance\n" + balance
		bank_balance_label.tooltip_text = "Available bank balance"
		var compact_font := 12
		var mobile_font_resource := bank_balance_label.get_theme_default_font()
		while compact_font > 8 and mobile_font_resource.get_string_size(balance, HORIZONTAL_ALIGNMENT_LEFT, -1, compact_font).x > bank_balance_label.custom_minimum_size.x - 4:
			compact_font -= 1
		bank_balance_label.add_theme_font_size_override("font_size", compact_font)
	else:
		var display_text := "Bank Balance  ·  " + balance
		bank_balance_label.text = display_text
		var desktop_font := 14
		var desktop_font_resource := bank_balance_label.get_theme_default_font()
		while desktop_font > 9 and desktop_font_resource.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, desktop_font).x > bank_balance_label.custom_minimum_size.x - 4:
			desktop_font -= 1
		bank_balance_label.add_theme_font_size_override("font_size", desktop_font)

func persist(message: String) -> void:
	_sync_ceo_profile()
	write_progress(Slots.AUTOSAVE, message)

func write_progress(slot: int, message: String) -> bool:
	_sync_ceo_profile()
	var archive_path := CEOProfile.company_path_for_game(active_game_id, str(sim.state.get("company_id", "")))
	var archive_result := Saves.save(sim.state, archive_path, Time.get_unix_time_from_system())
	var result := Slots.write_for_game(active_game_id, slot, sim.state, ceo_profile)
	if result != OK:
		dirty = dirty or slot == Slots.AUTOSAVE
		var reason := "Game data failed validation." if result == ERR_INVALID_DATA else error_string(result)
		set_notice("%s save failed. Progress is still in memory. %s" % [Slots.name_for(slot), reason], true)
		return false
	if archive_result != OK:
		set_notice("%s saved, but the CEO company recovery copy failed. %s" % [Slots.name_for(slot), error_string(archive_result)], true)
		return false
	var profile_result := ERR_FILE_CORRUPT if ceo_profile_corrupt else GameStore.update_game_profile(active_game_id, ceo_profile)
	if profile_result != OK:
		set_notice("%s saved, but this game's CEO profile could not be saved. %s" % [Slots.name_for(slot), error_string(profile_result)], true)
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
	_reset_edit_modes()
	screen = target
	set_notice("")
	render()

func start_new_game() -> void:
	active_game_id = ""
	ceo_profile = {}
	pending_ceo_name = ""
	show_screen("New Game")

func create_game_for_ceo(name: String) -> void:
	var ceo_name := name.strip_edges()
	if not _valid_ceo_name(ceo_name):
		set_notice("Enter a CEO name of 1–48 characters without control characters.", true)
		return
	var created := GameStore.create_game(ceo_name)
	if not str(created.get("error", "")).is_empty():
		set_notice(str(created.error), true)
		return
	active_game_id = str(created.game.game_id)
	ceo_profile = created.profile
	ceo_profile_corrupt = false
	pending_ceo_name = ceo_name
	show_screen("Setup")

func resume_game(game_id: String) -> void:
	if not _select_game(game_id): return
	var latest := Slots.latest_for_game(game_id)
	if latest.is_empty():
		if ceo_profile.get("companies", []).is_empty(): show_screen("Setup")
		else: show_company_selection("No slot save was found; choose an owned company archive.")
		return
	request_load(latest)

func resume_setup(game_id: String) -> void:
	if _select_game(game_id): show_screen("Setup")

func choose_company_in_game(game_id: String) -> void:
	if _select_game(game_id): show_company_selection()

func open_game_slots(game_id: String) -> void:
	if not _select_game(game_id): return
	open_screen("Load")

func _select_game(game_id: String) -> bool:
	var game := GameStore.get_game(game_id)
	var profile := CEOProfile.load_game_profile(game_id)
	if game.is_empty() or profile.is_empty():
		set_notice("This game's saved profile is unavailable. Other games remain untouched.", true)
		return false
	active_game_id = game_id
	ceo_profile = profile
	ceo_profile_corrupt = false
	return true

func delete_game(game_id: String) -> void:
	var game := GameStore.get_game(game_id)
	if game.is_empty(): return
	confirm_action("Delete %s?" % str(game.get("game_name", "Game")),
		"Permanently remove this game's profile, companies, autosave and manual saves. Other games and retained legacy source files remain untouched.",
		"Delete Game", func():
			var result := GameStore.delete_game_data(game_id)
			if result != OK:
				set_notice("Could not delete this game. " + error_string(result), true)
				return
			if active_game_id == game_id:
				active_game_id = ""
				ceo_profile = {}
				sim = null
				dirty = false
				profile_editing = false
				profile_edit_snapshot.clear()
			show_screen("Title")
	)

func delete_company(company_id: String) -> void:
	if active_game_id.is_empty() or sim != null:
		set_notice("Open company selection before removing a company from this game.", true)
		return
	var index := CEOProfile.company_index(ceo_profile, company_id)
	if index < 0 or str(ceo_profile.companies[index].get("ownership_status", "owned")) != "owned":
		set_notice("Only an owned company in this game can be deleted. Sold company history is retained.", true)
		return
	var name := str(ceo_profile.companies[index].get("name", "Company"))
	confirm_action("Delete %s?" % name,
		"Permanently remove this owned company's game-scoped save slots and recovery archive. The CEO profile, career progress, other companies in this game, and all other games will remain. Sold company history is kept in the CEO career record.",
		"Delete Company", func():
			var result := GameStore.delete_company_data(active_game_id, company_id)
			if result.has("profile"): ceo_profile = result.profile
			if not str(result.get("error", "")).is_empty():
				set_notice(str(result.error), true)
				return
			ceo_profile = result.profile
			show_company_selection("%s and only its company-specific saves were deleted. CEO career progress and other games were preserved." % name)
	)

func _valid_ceo_name(value: String) -> bool:
	if value.strip_edges().is_empty() or value.length() > 48:
		return false
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true

func continue_game() -> void:
	if active_game_id.is_empty(): return
	request_load(Slots.latest_for_game(active_game_id))

func load_slot(slot: int) -> void:
	request_load(Slots.read_for_game(active_game_id, slot))

func request_load(record: Dictionary) -> void:
	if record.is_empty():
		set_notice("No readable save was found.", true)
		return
	var loaded_company_id := str(record.state.get("company_id", ""))
	var owned_index := CEOProfile.company_index(ceo_profile, loaded_company_id) if not loaded_company_id.is_empty() else -1
	if owned_index >= 0 and str(ceo_profile.companies[owned_index].get("ownership_status", "owned")) == "sold":
		show_company_selection("This company has been sold. Its saved history remains available in the CEO profile.")
		return
	var autosave := Slots.read_for_game(active_game_id, Slots.AUTOSAVE)
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
		if ceo_profile.is_empty() or str(ceo_profile.get("full_name", "")).strip_edges().is_empty():
			ceo_profile = CEOProfile.ensure_for_game(ceo_profile, name, active_game_id,
				str(GameStore.get_game(active_game_id).get("game_name", "")))
			ceo_profile.full_name = name
			ceo_profile.title = CEOProfile.progression_title(ceo_profile)
			var profile_result := GameStore.update_game_profile(active_game_id, ceo_profile)
			if profile_result != OK:
				set_notice("Could not save this game's CEO name. " + error_string(profile_result), true)
				return
		if not ceo_profile.is_empty() and str(ceo_profile.get("full_name", "")).strip_edges().to_lower() != name.to_lower():
			identity_record.state = updated
			identity_record.owner_candidate = name
			identity_conflict_record = identity_record.duplicate(true)
			show_screen("CEO identity conflict")
			return
		var result := Slots.write_for_game(active_game_id, identity_record.slot, updated, ceo_profile, identity_record.saved_at)
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
	var result := Slots.write_for_game(active_game_id, slot, state, ceo_profile, float(identity_conflict_record.get("saved_at", 0)))
	if result != OK:
		set_notice("Could not apply the identity choice. " + error_string(result), true)
		return
	var context := str(identity_conflict_record.get("context", ""))
	identity_conflict_record.clear()
	identity_record.clear()
	ceo_profile = CEOProfile.sync_company(ceo_profile, state)
	var archive_error := Saves.save(state, CEOProfile.company_path_for_game(active_game_id, str(state.company_id)), Time.get_unix_time_from_system())
	if archive_error != OK or GameStore.update_game_profile(active_game_id, ceo_profile) != OK:
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
		ceo_profile = CEOProfile.ensure_for_game({}, str(sim.state.get("owner", "")), active_game_id, str(GameStore.get_game(active_game_id).get("game_name", "")))
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
	if str(entry.get("ownership_status", "owned")) != "owned":
		set_notice("This company has been sold and cannot be reopened for management.", true)
		return
	var state := Saves.load_state(str(entry.get("save_path", CEOProfile.company_path_for_game(active_game_id, company_id))))
	if state.is_empty() or str(state.get("company_id", "")) != company_id:
		set_notice("The saved company could not be recovered. Other companies were left untouched.", true)
		return
	var change := func():
		var archive_result := Saves.save(state, CEOProfile.company_path_for_game(active_game_id, company_id), Time.get_unix_time_from_system())
		if archive_result != OK:
			set_notice("Could not preserve the selected company. " + error_string(archive_result), true)
			return
		enter_game(state)
		if sim != null: write_progress(Slots.AUTOSAVE, "Switched company and updated this game's autosave.")
	if dirty:
		confirm_action("Switch company?", "Save the current company before switching to %s?" % str(entry.get("name", "Company")), "Switch Company", func():
			if write_progress(Slots.AUTOSAVE, "Current company preserved."):
				change.call()
		)
	else:
		change.call()

func show_company_selection(message: String = "") -> void:
	sim = null
	dirty = false
	screen = "Company Selection"
	page = "Dashboard"
	set_notice(message)
	render()

func sell_current_company() -> void:
	if sim == null or not CEOProfile.owns_company(ceo_profile, str(sim.state.get("company_id", ""))):
		set_notice("Only an owned company can be sold.", true)
		return
	if has_form_edits():
		set_notice("Save or cancel company detail edits before selling the company.", true)
		return
	var value := CompanySale.preview(sim.state)
	if not str(value.get("error", "")).is_empty():
		set_notice(str(value.error), true)
		return
	var details := "Estimated equity proceeds: %s\nMethod: %s\n\nThis permanently transfers company ownership. Proceeds are recorded in your CEO personal ledger; company cash will not be moved to another company. The sold company's save and accounting history will be retained." % [sale_money(int(value.equity_value), str(value.currency)), str(value.method)]
	confirm_action("Sell %s?" % str(value.company_name), details, "Confirm Company Sale", func(): _complete_company_sale())

func _complete_company_sale() -> void:
	if sim == null:
		set_notice("The active company could not be found.", true)
		return
	var company_state: Dictionary = sim.state.duplicate(true)
	var company_id := str(company_state.get("company_id", ""))
	if not CEOProfile.owns_company(ceo_profile, company_id):
		set_notice("This company has already been sold or is no longer owned.", true)
		return
	var archive_error := Saves.save(company_state, CEOProfile.company_path_for_game(active_game_id, company_id), Time.get_unix_time_from_system())
	if archive_error != OK:
		set_notice("The company history could not be archived. The sale was not completed. " + error_string(archive_error), true)
		return
	var sale := CompanySale.sell(ceo_profile, company_state)
	if not str(sale.get("error", "")).is_empty():
		set_notice(str(sale.error), true)
		return
	var profile_error := GameStore.update_game_profile(active_game_id, sale.profile)
	if profile_error != OK:
		set_notice("The sale could not be recorded in the CEO profile. The company remains owned. " + error_string(profile_error), true)
		return
	ceo_profile = sale.profile
	var autosave_error := Slots.delete_for_game(active_game_id, Slots.AUTOSAVE)
	sim = null
	dirty = false
	screen = "Company Selection"
	page = "Dashboard"
	set_notice("%s was sold for %s. Its company records were preserved.%s" % [str(sale.record.company_name), sale_money(int(sale.record.amount), str(sale.record.currency)), " Autosave cleanup needs attention; sold-company loads are blocked." if autosave_error != OK else ""])
	render()

func sale_money(amount: int, currency: String) -> String:
	return "%s %s" % [currency, amount_text(amount)]

func company_entry_currency(entry: Dictionary) -> String:
	var country := _company_entry_country_index(entry)
	return Catalog.CURRENCIES[country] if country in range(Catalog.CURRENCIES.size()) else ""

func company_entry_country(entry: Dictionary) -> String:
	var country := _company_entry_country_index(entry)
	return Catalog.COUNTRIES[country] if country in range(Catalog.COUNTRIES.size()) else "Country unavailable"

func _company_entry_country_index(entry: Dictionary) -> int:
	var saved_country := str(entry.get("country", ""))
	if saved_country.is_valid_int(): return saved_country.to_int()
	return Catalog.COUNTRIES.find(saved_country)

func company_selection() -> void:
	var view := wide_card("Choose a Company")
	view.add_child(label("Each owned company keeps separate operations, accounts, and saved progress.", 14, Style.MUTED))
	var owned: Array[Dictionary] = CEOProfile.owned_companies(ceo_profile)
	if owned.is_empty():
		view.add_child(label("You do not currently own a company. Start a new company to continue your career.", 15, Style.MUTED))
		action(view, "Start a New Company", func(): show_screen("Setup"), true)
	else:
		for entry in owned:
			var row := card(str(entry.get("name", "Company")))
			metric(row, "Country", company_entry_country(entry))
			metric(row, "Lifetime net sales", sale_money(int(entry.get("lifetime_sales", 0)), company_entry_currency(entry)))
			metric(row, "Lifetime net profit", sale_money(int(entry.get("lifetime_profit", 0)), company_entry_currency(entry)))
			action(row, "Open Company", switch_company.bind(str(entry.get("company_id", ""))), true)
			action(row, "Delete Company", delete_company.bind(str(entry.get("company_id", ""))))
		action(view, "Start Another Company", func(): show_screen("Setup"))
	var sold: Array[Dictionary] = []
	for entry in ceo_profile.get("companies", []):
		if entry is Dictionary and str(entry.get("ownership_status", "owned")) == "sold": sold.append(entry)
	if not sold.is_empty():
		var archive := card("Sold Company Records")
		archive.add_child(label("Sold businesses remain in your career history and cannot be reopened or deleted.", 13, Style.MUTED))
		for entry in sold:
			var sale: Dictionary = entry.get("sale_record", {})
			archive.add_child(label("%s · Sold for %s · %s" % [str(entry.get("name", "Company")), sale_money(int(sale.get("amount", 0)), str(sale.get("currency", ""))), str(sale.get("date", "Date unavailable"))], 14, Style.GOLD))
	action(view, "Back to Title", func(): show_screen("Title"))

func profile_page() -> void:
	if ceo_profile_corrupt:
		var damaged := wide_card("CEO Profile Unavailable")
		damaged.add_child(label("The CEO profile could not be read. Your company saves are safe. Recover this browser profile before editing identity details or switching companies.", 15, Style.RED))
		damaged.add_child(label("This profile will not be replaced automatically.", 14, Style.MUTED))
		return
	var info := wide_card("CEO Profile")
	var identity_layout: BoxContainer = HBoxContainer.new() if size.x >= 600.0 else VBoxContainer.new()
	identity_layout.name = "CEOIdentityLayout"
	identity_layout.add_theme_constant_override("separation", 18)
	info.add_child(identity_layout)
	var portrait := VBoxContainer.new()
	portrait.add_theme_constant_override("separation", 8)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	identity_layout.add_child(portrait)
	var portrait_width := 170.0 if size.x >= 600.0 else minf(150.0, maxf(132.0, size.x * 0.38))
	var portrait_frame := PortraitFrame.new()
	portrait_frame.set_portrait(_profile_avatar_texture(), portrait_width)
	portrait.add_child(portrait_frame)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	identity_layout.add_child(details)
	if profile_editing:
		var full_name := field(details, "Full Name", str(ceo_profile.get("full_name", sim.state.get("owner", ""))))
		var residence := field(details, "Country of Residence", str(ceo_profile.get("country", "")))
		full_name.text_changed.connect(func(value: String): ceo_profile.full_name = value)
		residence.text_changed.connect(func(value: String): ceo_profile.country = value)
		watch_edits([full_name, residence])
		var photo_actions := row(details)
		action(photo_actions, "Change Photo", open_avatar_picker)
		if not str(ceo_profile.get("avatar_data", "")).is_empty():
			action(photo_actions, "Remove Photo", func():
				CEOProfile.clear_avatar(ceo_profile)
				set_notice("Photo removal will take effect when you save your profile.")
				refresh_view()
			)
		action(details, "Save Changes", func():
			if not _valid_ceo_name(full_name.text.strip_edges()):
				set_notice("Enter a CEO name of 1–48 characters without control characters.", true)
				return
			var previous := ceo_profile.duplicate(true)
			var previous_owner: String = sim.state.owner
			ceo_profile.full_name = full_name.text.strip_edges()
			ceo_profile.country = residence.text.strip_edges()
			ceo_profile.title = CEOProfile.progression_title(ceo_profile)
			sim.state.owner = ceo_profile.full_name
			_sync_ceo_profile()
			var result := GameStore.update_game_profile(active_game_id, ceo_profile)
			if result != OK:
				ceo_profile = previous
				sim.state.owner = previous_owner
				set_notice("Profile changes could not be saved. " + error_string(result), true)
				return
			profile_editing = false
			profile_edit_snapshot.clear()
			if not write_progress(Slots.AUTOSAVE, "CEO profile updated."):
				ceo_profile = previous
				sim.state.owner = previous_owner
				GameStore.update_game_profile(active_game_id, ceo_profile)
				profile_editing = true
				profile_edit_snapshot = previous.duplicate(true)
				return
			set_notice("Profile changes saved.")
			refresh_view()
		, true)
		action(details, "Cancel", func():
			profile_editing = false
			if not profile_edit_snapshot.is_empty():
				ceo_profile = profile_edit_snapshot.duplicate(true)
				profile_edit_snapshot.clear()
			edit_checks.clear()
			set_notice("")
			refresh_view()
		)
	else:
		var country_name := str(ceo_profile.get("country", "")).strip_edges()
		if country_name.is_empty(): country_name = "Not provided"
		var professional_title := CEOProfile.progression_title(ceo_profile)
		metric(details, "Full Name", str(ceo_profile.get("full_name", sim.state.get("owner", ""))), Style.GOLD)
		metric(details, "Country of Residence", country_name)
		metric(details, "Professional Title", professional_title)
		action(details, "Edit Profile", func():
			profile_edit_snapshot = ceo_profile.duplicate(true)
			profile_editing = true
			refresh_view()
		)
	var career := card("Career Progression")
	metric(career, "Career Level", "%d · %d XP" % [CEOProfile.level(ceo_profile), int(ceo_profile.get("xp", 0))], Style.GOLD)
	metric(career, "Career Title", CEOProfile.progression_title(ceo_profile), Style.GOLD)
	career.add_child(label("A progression label based on career level, not an employment claim.", 13, Style.MUTED))
	metric(career, "XP Until Next Level", str(CEOProfile.xp_to_next_level(ceo_profile)))
	metric(career, "Personal Reputation", "%d / 100" % int(ceo_profile.get("personal_reputation", 0)))
	var additional := card("Additional Information")
	var company_records: Array = ceo_profile.get("companies", [])
	var active_companies := 0
	for company_record in company_records:
		if str(company_record.get("ownership_status", "owned")) == "owned" and not bool(company_record.get("bankrupt", false)):
			active_companies += 1
	var ceo_id := str(ceo_profile.get("ceo_id", ""))
	var career_start := str(ceo_profile.get("career_start_date", ""))
	metric(additional, "CEO ID", ceo_id if not ceo_id.is_empty() else "Not available")
	metric(additional, "Career Start Date", career_start if not career_start.is_empty() else "Not available")
	metric(additional, "Total Companies Founded", str(company_records.size()))
	metric(additional, "Active Companies", str(active_companies))
	var achievements := card("Achievements")
	var earned: Array = ceo_profile.get("achievements", [])
	if earned.is_empty():
		achievements.add_child(label("Achievements recognize career milestones.", 15, Style.MUTED))
	for item in earned:
		achievements.add_child(label("• %s" % _title_case(str(item.get("title", item.get("id", "Achievement")))), 15))
	var finance_card := card("Personal Finance")
	finance_card.add_child(label("Personal cash and net worth remain untracked. Known company-sale proceeds are recorded separately by currency.", 14, Style.MUTED))
	var proceeds := CompanySale.known_sale_proceeds_by_currency(ceo_profile)
	if proceeds.is_empty():
		finance_card.add_child(label("No company sale proceeds have been recorded.", 14, Style.MUTED))
	else:
		var currencies: Array = proceeds.keys()
		currencies.sort()
		for currency in currencies:
			metric(finance_card, "Known Sale Proceeds · %s" % str(currency), sale_money(int(proceeds[currency]), str(currency)), Style.GOLD)
	for transaction in ceo_profile.get("personal_finance_ledger", []):
		if transaction is Dictionary and str(transaction.get("type", "")) == "company_sale":
			metric(finance_card, "%s · %s" % [str(transaction.get("company_name", "Company sale")), str(transaction.get("date", "Date unavailable"))], sale_money(int(transaction.get("amount", 0)), str(transaction.get("currency", ""))))
	finance_card.add_child(label("Company funds and profit remain separate from personal finances.", 14, Style.MUTED))
	var companies := card("Owned Companies")
	companies.add_child(label("Each company keeps separate operations, accounts, and save data.", 14, Style.MUTED))
	for entry in ceo_profile.get("companies", []):
		var company_row := VBoxContainer.new()
		company_row.add_theme_constant_override("separation", 8)
		companies.add_child(company_row)
		var description := label("%s · %s" % [str(entry.get("name", "Company")), str(entry.get("country", ""))], 15, Style.GOLD)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		company_row.add_child(description)
		if str(entry.get("ownership_status", "owned")) == "sold":
			var sale: Dictionary = entry.get("sale_record", {})
			company_row.add_child(label("Sold · %s · %s" % [str(sale.get("date", "Date unavailable")), sale_money(int(sale.get("amount", 0)), str(sale.get("currency", "")))], 14, Style.MUTED))
		elif str(entry.get("company_id", "")) == str(sim.state.get("company_id", "")):
			company_row.add_child(label("Current Company", 14, Style.GREEN))
		else:
			action(company_row, "Switch", switch_company.bind(str(entry.get("company_id", ""))))
	action(companies, "Start Another Company", start_new_game, true)

func _title_case(value: String) -> String:
	var words := value.split(" ", false)
	for index in words.size():
		var word: String = words[index]
		if word.to_upper() in ["XP", "CEO", "ID", "UI"]:
			words[index] = word.to_upper()
		else:
			words[index] = word.capitalize()
	return " ".join(words)

func _profile_avatar_texture() -> Texture2D:
	var encoded := str(ceo_profile.get("avatar_data", ""))
	if encoded.is_empty():
		return load("res://icon.svg")
	var bytes := Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	if image.load_jpg_from_buffer(bytes) != OK:
		return load("res://icon.svg")
	return ImageTexture.create_from_image(image)

func open_avatar_crop(image: Image) -> void:
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		set_notice("Choose a readable photo file.", true)
		return
	if not profile_editing:
		set_notice("Edit your profile before changing its photo.", true)
		return
	avatar_crop_source = image.duplicate()
	set_notice("")
	render()
	call_deferred("_show_avatar_crop_modal")

func _show_avatar_crop_modal() -> void:
	if avatar_crop_source == null or avatar_crop_source.is_empty() or screen != "Game" or page != "Profile" or not profile_editing:
		return
	var overlay := Control.new()
	overlay.name = "AvatarCropModal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 12)
	center.add_theme_constant_override("margin_right", 12)
	center.add_theme_constant_override("margin_top", 12)
	center.add_theme_constant_override("margin_bottom", 12)
	overlay.add_child(center)
	var modal_width := minf(760.0, size.x - 24.0)
	var editor_card := PanelContainer.new()
	editor_card.name = "AvatarCropDialog"
	editor_card.custom_minimum_size.x = maxf(280.0, modal_width)
	editor_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	editor_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	editor_card.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.GOLD, 15, 16))
	center.add_child(editor_card)
	var content := stack(editor_card, 4)
	content.add_child(label("Crop Profile Photo", 22))
	content.add_child(label("Drag to reposition the photo or adjust the zoom. The preview uses a 3:4 portrait ratio.", 14, Style.MUTED))
	var mobile_crop := size.x < 600.0
	var composition := VBoxContainer.new()
	composition.alignment = BoxContainer.ALIGNMENT_CENTER
	composition.add_theme_constant_override("separation", 8)
	content.add_child(composition)
	var crop_width := minf(200.0 if mobile_crop else 300.0, maxf(180.0 if mobile_crop else 240.0, size.x - (64.0 if mobile_crop else 88.0)))
	var preview_section := VBoxContainer.new()
	preview_section.name = "AvatarCropPreviewSection"
	preview_section.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_section.add_theme_constant_override("separation", 6)
	preview_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	composition.add_child(preview_section)
	var preview_title := label("Live Preview", 17, Style.GOLD)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_section.add_child(preview_title)
	var crop := AvatarCrop.new()
	crop.name = "AvatarCropViewport"
	crop.custom_minimum_size = Vector2(crop_width, crop_width * 4.0 / 3.0)
	crop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crop.set_image(avatar_crop_source)
	preview_section.add_child(crop)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	controls.custom_minimum_size.x = crop_width
	controls.add_theme_constant_override("separation", 6)
	composition.add_child(controls)
	controls.add_child(label("Zoom", 14, Style.MUTED))
	var zoom := HSlider.new()
	zoom.name = "AvatarCropZoom"
	zoom.min_value = 1.0
	zoom.max_value = 3.0
	zoom.step = 0.05
	zoom.value = 1.0
	zoom.custom_minimum_size.y = TOUCH_HEIGHT
	zoom.value_changed.connect(func(value: float): crop.set_zoom(value))
	controls.add_child(zoom)
	action(controls, "Reset", func():
		crop.reset_crop()
		zoom.value = 1.0
	)
	var buttons := row(content)
	action(buttons, "Cancel", func():
		avatar_crop_source = null
		overlay.queue_free()
		set_notice("")
	)
	action(buttons, "Apply Crop", func():
		var finalized := crop.crop_image()
		var error := CEOProfile.set_avatar_image(ceo_profile, finalized)
		if error != OK:
			set_notice("The cropped photo could not be stored. Choose a smaller image.", true)
			return
		avatar_crop_source = null
		overlay.queue_free()
		set_notice("Photo preview updated. Save your profile to keep this change.")
		refresh_view()
	, true)

func _load_avatar_image(mime: String, data: PackedByteArray) -> Image:
	if mime not in ["image/jpeg", "image/png", "image/webp"] or data.is_empty() or data.size() > 8 * 1024 * 1024:
		return null
	var image := Image.new()
	var result := image.load_jpg_from_buffer(data) if mime == "image/jpeg" else (image.load_png_from_buffer(data) if mime == "image/png" else image.load_webp_from_buffer(data))
	return image if result == OK and not image.is_empty() else null

func open_avatar_picker() -> void:
	if OS.has_feature("web"):
		avatar_picker_callback = JavaScriptBridge.create_callback(_on_web_avatar_selected)
		JavaScriptBridge.get_interface("window").obtAvatarSelected = avatar_picker_callback
		JavaScriptBridge.eval("(function(){const i=document.createElement('input');i.type='file';i.accept='image/jpeg,image/png,image/webp';i.onchange=function(){const f=i.files&&i.files[0];if(!f)return;if(f.size>8388608){window.obtAvatarSelected('error:Choose a photo under 8 MB.');return;}if(!['image/jpeg','image/png','image/webp'].includes(f.type)){window.obtAvatarSelected('error:Choose a JPEG, PNG, or WebP photo.');return;}const r=new FileReader();r.onerror=function(){window.obtAvatarSelected('error:The selected photo could not be read.');};r.onload=function(){window.obtAvatarSelected(f.type+','+String(r.result).split(',')[1]);};r.readAsDataURL(f);};i.click();})();")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.jpg, *.jpeg, *.png, *.webp", "Images")
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 8 * 1024 * 1024:
			set_notice("Choose a photo under 8 MB.", true)
		else:
			var image := Image.new()
			var error := image.load(path)
			if error != OK or image.is_empty():
				set_notice("The selected photo could not be read.", true)
			else:
				avatar_crop_source = image.duplicate()
				screen = "Avatar Crop"
				render()
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
	var image := _load_avatar_image(mime, Marshalls.base64_to_raw(parts[1]))
	if image == null:
		set_notice("The selected photo could not be read. Choose another JPEG, PNG, or WebP image under 8 MB.", true)
		return
	open_avatar_crop(image)

func enter_game(data: Dictionary) -> void:
	if active_game_id.is_empty():
		set_notice("Choose or create a game before loading a company.", true)
		return
	sim = Sim.new(data)
	_sync_ceo_profile()
	if not CEOProfile.owns_company(ceo_profile, str(sim.state.get("company_id", ""))):
		sim = null
		show_company_selection("This company is no longer owned. Choose another company or start a new one.")
		return
	var profile_error := ERR_FILE_CORRUPT if ceo_profile_corrupt else GameStore.update_game_profile(active_game_id, ceo_profile)
	var archive_error := Saves.save(sim.state, CEOProfile.company_path_for_game(active_game_id, str(sim.state.company_id)), Time.get_unix_time_from_system())
	var slot_error := Slots.write_for_game(active_game_id, Slots.AUTOSAVE, sim.state, ceo_profile)
	dirty = false
	screen = "Game"
	page = "Dashboard"
	selected_product = 0
	report_end = 0
	order_page = 0
	set_notice("")
	if profile_error != OK or archive_error != OK or slot_error != OK:
		set_notice("Company loaded, but its game-scoped profile or save recovery copy could not be saved.", true)
	render()

func save_to_slot(slot: int) -> void:
	var write := func():
		write_progress(slot, "Saved to manual slot %d." % slot)
		refresh_view()
	if Slots.occupied_for_game(active_game_id, slot):
		confirm_action("Overwrite manual slot %d?" % slot, "Replace the saved snapshot in this slot with your current game?", "Overwrite", write)
	else:
		write.call()

func delete_save(slot: int) -> void:
	confirm_action("Delete %s?" % Slots.name_for(slot).to_lower(),
		"Delete this save and its recovery copy?", "Delete", func():
		var error := Slots.delete_for_game(active_game_id, slot)
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
		active_game_id = ""
		ceo_profile = {}
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
	display_settings_editing = false
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
	if target == "Inventory Management": target = "My Products"
	if target == "Company Management": target = "Business"
	if target == "Campaign Management": target = "Campaign Manager"
	if target == "Ads Analytics": target = "Advertising Analytics"
	if target == "Order": target = "Orders"
	if target in NAV:
		if target == primary_category(page):
			if target == "Order": target = "Orders"
			elif target == "Marketing": target = "Advertising"
		else:
			target = str(category_last_page.get(target, target))
			if target == "Store Listings": target = "My Products"
	if target != "Management": show_new_store_form = false
	discard_form_then(func():
		if target != page:
			_reset_edit_modes()
		page = target
		category_last_page[primary_category(target)] = target
		set_notice("")
		render()
	)

func primary_category(target: String) -> String:
	if target in ["Market", "My Products", "Management", "Store Listings"]: return "Market"
	if target in ["Orders", "Pre-orders"]: return "Order"
	if target in ["Advertising", "Campaign Manager", "Campaign Details", "Advertising Analytics"]: return "Marketing"
	if target == "Marketing": return "Marketing"
	if target in ["Business", "Company Sale"]: return "Business"
	if target in ["Finance", "Expense Management", "Store Profitability"]: return "Finance"
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

func _reset_edit_modes() -> void:
	if profile_editing and not profile_edit_snapshot.is_empty():
		ceo_profile = profile_edit_snapshot.duplicate(true)
	profile_edit_snapshot.clear()
	profile_editing = false
	company_profile_editing = false
	store_listing_editing = false
	campaign_editing = false
	shipping_settings_editing = false
	display_settings_editing = false

func primary_navigation(parent: Node) -> Button:
	var heading := row(parent)
	var menu_button := action(heading, "Menu", toggle_navigation_drawer, false)
	menu_button.name = "NavigationMenuButton"
	menu_button.custom_minimum_size = Vector2(72 if size.x < 600.0 else 92, 48)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_button.tooltip_text = "Open navigation menu"
	_apply_drawer_icon(menu_button, DRAWER_ICON_PATHS.Menu, 20)
	navigation_toggle = menu_button
	var viewport_width := size.x
	var date_text := _game_date_text(viewport_width)
	var game_date := label(date_text, 13 if viewport_width < 600.0 else 14, Style.MUTED)
	game_date.name = "GameDate"
	game_date.custom_minimum_size.x = 0
	game_date.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(game_date)
	var balance := label("", 12 if viewport_width < 600.0 else 14, Style.GOLD)
	balance.name = "CompanyBankBalance"
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance.size_flags_horizontal = Control.SIZE_SHRINK_END
	balance.custom_minimum_size.x = 152 if viewport_width < 600.0 else 245
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.clip_text = false
	balance.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	heading.add_child(balance)
	bank_balance_label = balance
	_refresh_bank_balance()
	_create_navigation_drawer()
	return menu_button

func _game_date_text(viewport_width: float) -> String:
	var country: String = Catalog.COUNTRIES[int(sim.state.country)]
	if viewport_width < 600.0:
		var date := Calendar.date_at(sim.state.day)
		return "D%d · %d %s | %s" % [sim.state.day, int(date.day), str(Calendar.MONTHS[int(date.month) - 1]), country]
	return "%s | %s" % [Calendar.format(sim.state.day), country]

func toggle_navigation_drawer() -> void:
	if not is_instance_valid(navigation_overlay):
		return
	navigation_open = not navigation_open
	navigation_overlay.visible = navigation_open
	if navigation_open:
		var active := navigation_drawer.find_child("Primary_" + primary_category(page), true, false) as Button
		if active != null and active.is_inside_tree():
			active.grab_focus()
	else:
		_restore_navigation_focus()

func close_navigation_drawer(restore_focus: bool = true) -> void:
	if not is_instance_valid(navigation_overlay):
		return
	navigation_open = false
	navigation_overlay.visible = false
	if restore_focus:
		_restore_navigation_focus()

func _restore_navigation_focus() -> void:
	if is_instance_valid(navigation_toggle) and navigation_toggle.is_inside_tree():
		navigation_toggle.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not navigation_open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		close_navigation_drawer()
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_TAB or not is_instance_valid(navigation_drawer):
		return
	var focusable: Array[Control] = []
	for button in navigation_drawer.find_children("*", "Button", true, false):
		if button is Button and button.focus_mode != Control.FOCUS_NONE and button.is_visible_in_tree():
			focusable.append(button)
	if focusable.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var index := focusable.find(owner)
	if index < 0:
		focusable[focusable.size() - 1 if event.shift_pressed else 0].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.shift_pressed and index == 0:
		focusable.back().grab_focus()
		get_viewport().set_input_as_handled()
	elif not event.shift_pressed and index == focusable.size() - 1:
		focusable.front().grab_focus()
		get_viewport().set_input_as_handled()

func _create_navigation_drawer() -> void:
	var overlay := ColorRect.new()
	overlay.name = "NavigationOverlay"
	overlay.color = Color(0.015, 0.025, 0.045, 0.76)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close_navigation_drawer()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch and event.pressed:
			close_navigation_drawer()
			get_viewport().set_input_as_handled()
	)
	add_child(overlay)
	navigation_overlay = overlay
	var drawer := PanelContainer.new()
	drawer.name = "PrimaryNavigation"
	drawer.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	drawer.offset_left = 0
	drawer.offset_top = 0
	drawer.offset_bottom = 0
	drawer.offset_right = clampf(size.x * 0.78, 260.0, 320.0)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.GOLD, 0, 16))
	overlay.add_child(drawer)
	navigation_drawer = drawer
	var content := stack(drawer, 10)
	var heading := row(content)
	var title := label("Navigation", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := action(heading, "Close", close_navigation_drawer)
	close_button.custom_minimum_size = Vector2(72, 44)
	_apply_drawer_icon(close_button, DRAWER_ICON_PATHS.Close, 18)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.name = "NavigationScroll"
	nav_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(nav_scroll)
	var nav_list := stack(nav_scroll, 8)
	nav_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in NAV.size():
		var target: String = NAV[index]
		var display_name := "Orders" if target == "Order" else target
		var item := action(nav_list, display_name, func():
			close_navigation_drawer(false)
			navigate(target)
		)
		item.name = "Primary_" + target
		item.tooltip_text = target
		item.custom_minimum_size.y = 50
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.focus_mode = Control.FOCUS_ALL
		_apply_drawer_icon(item, NAV_ICON_PATHS[target], 21)
		if target == primary_category(page):
			Style.primary(item)
			item.add_theme_color_override("icon_normal_color", Style.INK)
		else:
			Style.secondary(item)
			item.add_theme_color_override("icon_normal_color", Style.GOLD)
	divider(content)
	content.add_child(label("Actions", 13, Style.MUTED))
	var save_action := action(content, "Save Game", func():
		close_navigation_drawer(false)
		open_screen("Save")
	)
	save_action.name = "DrawerActionSave"
	save_action.custom_minimum_size.y = 46
	_apply_drawer_icon(save_action, DRAWER_ICON_PATHS["Save Game"], 20)
	var main_menu_action := action(content, "Main Menu", func():
		close_navigation_drawer(false)
		leave_game()
	)
	main_menu_action.name = "DrawerActionMainMenu"
	main_menu_action.custom_minimum_size.y = 46
	_apply_drawer_icon(main_menu_action, DRAWER_ICON_PATHS["Main Menu"], 20)
	Style.secondary(main_menu_action)

func _apply_drawer_icon(button: Button, path: String, max_width: int = 20) -> void:
	var icon := load(path) as Texture2D
	if icon == null:
		push_warning("Navigation icon failed to load: " + path)
		return
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

func secondary_navigation(parent: Node) -> void:
	var category := primary_category(page)
	var routes: Array = []
	match category:
		"Market": routes = [["Product Catalogue", "Market"], ["Inventory Management", "My Products"], ["Store Management", "Management"]]
		"Order": routes = [["Customer Orders", "Orders"], ["Pre-orders", "Pre-orders"], ["Returns and Service", "Returns & Service"]]
		"Business": routes = [["Company Management", "Business"]]
		"Marketing": routes = [["Overview", "Advertising"], ["Campaign Management", "Campaign Manager"], ["Ads Analytics", "Advertising Analytics"]]
		"Finance": routes = [["Statements", "Finance"], ["Expense Management", "Expense Management"], ["Store Profitability", "Store Profitability"]]
		_: return
	var scroller := ScrollContainer.new()
	scroller.name = "SecondaryNavigationScroll"
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.custom_minimum_size.y = 46
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroller)
	var strip := HBoxContainer.new()
	strip.name = "SecondaryNavigationTabs"
	strip.add_theme_constant_override("separation", 6)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scroller.add_child(strip)
	for route in routes:
		var title: String = route[0]
		var target: String = route[1]
		var selected := false
		if target == "Returns & Service": selected = page == "Orders" and orders_tab == 1
		elif target == "Pre-orders": selected = page == "Pre-orders"
		elif target == "Customer Orders": selected = page == "Orders" and orders_tab != 1
		elif target == "Store Profitability": selected = page == "Store Profitability"
		else: selected = page == target
		var tab := secondary_tab(strip, title, route_secondary.bind(target), selected)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_style_secondary_navigation_tab(tab, selected)

func render() -> void:
	edit_checks.clear()
	navigation_overlay = null
	navigation_drawer = null
	navigation_toggle = null
	bank_balance_label = null
	navigation_open = false
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
	var shell := page_shell
	var masthead := stack(shell, 3)
	if screen != "Title":
		masthead.add_child(label("ONLINE BUSINESS TYCOON", 13, Style.GOLD))
	if screen == "Game":
		primary_navigation(masthead)
		var heading := row(masthead)
		heading.name = "PageHeading"
		var page_title := page
		match page:
			"Business": page_title = "Company Management"
			"Management": page_title = "Store Management"
			"My Products": page_title = "Inventory Management"
			"Advertising": page_title = "Marketing"
			"Campaign Manager": page_title = "Campaign Management"
			"Advertising Analytics": page_title = "Ads Analytics"
		var title := label(page_title, 26 if viewport_width < 600.0 else 30)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
	elif screen == "Title":
		Menu.brand(self, masthead)
	else:
		var titles := {"Setup": "Start your business", "Load": "Load Game", "Save": "Save Game", "Settings": "Settings",
			"Campaign Manager": "Campaign Management", "Campaign Details": "Campaign Details", "Company Selection": "Choose a Company",
			"Advertising Analytics": "Ads Analytics", "Management": "Store Management", "Store Listings": "Store Listings", "Avatar Crop": "Crop Profile Photo",
		"CEO identity conflict": "Identity choice", "New Game": "Create a Game"}
		masthead.add_child(label(titles.get(screen, screen), 30))
	var scroll := ScrollContainer.new()
	scroll.name = "GameContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	shell.add_child(scroll)
	body = stack(scroll, 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_space := Control.new()
	right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(right_space)
	if screen == "Game":
		secondary_navigation(body)
	divider(body)
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
	body.add_child(status)
	if screen != "Game":
		match screen:
			"Title": Menu.title(self)
			"New Game": new_game_identity()
			"Setup": setup()
			"Company Selection": company_selection()
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
		"Expense Management": expense_management()
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
	var details := card("Company Registration")
	details.add_child(label("Register your company and entrepreneur profile. Create stores later under Market / Store Management.", 15, Style.MUTED))
	if active_game_id.is_empty() or ceo_profile.is_empty():
		details.add_child(label("Choose or create a game and CEO identity before registering a company.", 15, Style.RED))
		action(details, "Back to Games", func(): show_screen("Title"))
		return
	metric(details, "Game", str(ceo_profile.get("game_name", "Game")), Style.GOLD)
	metric(details, "Entrepreneur / CEO", str(ceo_profile.get("full_name", "")))
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
	watch_edits([company, country, difficulty])
	action(details, "Register company", func():
		var owner_name := str(ceo_profile.get("full_name", "")).strip_edges()
		var company_name := company.text.strip_edges()
		if owner_name.is_empty() or company_name.is_empty():
			set_notice("Enter a company name. The CEO name is saved with this game.", true)
			return
		var new_state := Sim.register(owner_name, company_name, "",
			country.selected, difficulty.selected, 0, randi())
		ceo_profile = CEOProfile.register_company(ceo_profile, new_state)
		var profile_result := GameStore.update_game_profile(active_game_id, ceo_profile)
		if profile_result != OK:
			set_notice("Could not save this game's company ownership. " + error_string(profile_result), true)
			return
		enter_game(new_state)
		persist("Company registered.")
	, true)
	action(details, "Back to Games", open_screen.bind("Title"))

func new_game_identity() -> void:
	var details := card("New Game · CEO Identity")
	details.add_child(label("Each game keeps its own CEO career, companies, and save slots. Enter the CEO name before registering a company.", 15, Style.MUTED))
	var owner := field(details, "CEO Name", pending_ceo_name)
	watch_edits([owner])
	action(details, "Continue to Company Registration", func(): create_game_for_ceo(owner.text), true)
	action(details, "Back", func(): show_screen("Title"))

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
	page_wide.add_child(InventoryOverview.build(sim, size.x < 600.0))
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
	var time := card("Advance Time")
	time.add_child(label("Each simulated day generates orders and charges operating expenses.", 14, Style.MUTED))
	var controls := row(time)
	for days in [1, 2, 7, 30]:
		action(controls, "+%d" % days, advance.bind(days), days == 1)
	var has_listing := false
	for item in sim.state.products.values():
		if item.listed:
			has_listing = true
	if not has_listing:
		var next := card("Open Your Store")
		next.add_child(label("Choose a product in Market, purchase stock from a supplier, then publish your listing.", 15, Style.MUTED))
		action(next, "Browse Product Catalogue", navigate.bind("Market"), true)
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
	var channels := card("Sales by Channel")
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
	var profile := card("Company Management")
	metric(profile, "Owned Stores", str(sim.state.stores.size()))
	metric(profile, "Registration", "Active")
	metric(profile, "Difficulty", Catalog.DIFFICULTIES[sim.state.difficulty])
	if company_profile_editing:
		var owner := field(profile, "Entrepreneur / CEO", str(ceo_profile.get("full_name", sim.state.owner)))
		var company := field(profile, "Company Name", sim.state.company)
		watch_edits([owner, company])
		action(profile, "Save Changes", func():
			var owner_name := owner.text.strip_edges()
			var company_name := company.text.strip_edges()
			if owner_name.is_empty() or company_name.is_empty():
				set_notice("Enter an entrepreneur name and company name.", true)
				return
			var previous_profile := ceo_profile.duplicate(true)
			var previous_owner: String = sim.state.owner
			var previous_company: String = sim.state.company
			ceo_profile.full_name = owner_name
			sim.state.owner = owner_name
			sim.state.company = company_name
			_sync_ceo_profile()
			var result := GameStore.update_game_profile(active_game_id, ceo_profile)
			if result != OK:
				ceo_profile = previous_profile
				sim.state.owner = previous_owner
				sim.state.company = previous_company
				set_notice("Company details could not be saved. " + error_string(result), true)
				return
			company_profile_editing = false
			if write_progress(Slots.AUTOSAVE, "Company profile saved."):
				set_notice("Company details saved.")
			refresh_view()
		, true)
		action(profile, "Cancel", func():
			company_profile_editing = false
			edit_checks.clear()
			set_notice("")
			refresh_view()
		)
	else:
		metric(profile, "Entrepreneur / CEO", str(ceo_profile.get("full_name", sim.state.owner)))
		metric(profile, "Company Name", sim.state.company)
		action(profile, "Edit Company Details", func():
			company_profile_editing = true
			refresh_view()
		)
	company_sale_panel(profile)
	action(card("Store Management"), "Store Management", navigate.bind("Management"), true)
	action(card("Inventory Management"), "Inventory Management", navigate.bind("My Products"))
	action(card("Marketing"), "Marketing", navigate.bind("Marketing"))
	var saves := card("Local Progress")
	saves.add_child(label("Progress saves automatically when you make changes or advance time.", 14, Style.MUTED))
	var controls := row(saves)
	action(controls, "Manage Saves", open_screen.bind("Save"))
	action(controls, "Load Game", open_screen.bind("Load"))

func company_sale_panel(parent: Control) -> void:
	parent.add_child(label("Sell Company", 18, Style.GOLD))
	if not CEOProfile.owns_company(ceo_profile, str(sim.state.get("company_id", ""))):
		parent.add_child(label("Only companies still owned by this CEO can be sold.", 14, Style.MUTED))
		return
	var value := CompanySale.preview(sim.state)
	if not str(value.get("error", "")).is_empty():
		parent.add_child(label(str(value.error), 14, Style.RED))
		return
	metric(parent, "Company", str(value.company_name), Style.GOLD)
	metric(parent, "Estimated equity sale proceeds", sale_money(int(value.equity_value), str(value.currency)), Style.GOLD)
	metric(parent, "Normalized annual revenue", sale_money(int(value.annual_revenue), str(value.currency)))
	metric(parent, "Normalized annual operating profit", sale_money(int(value.annual_operating_profit), str(value.currency)), profit_color(int(value.annual_operating_profit)))
	metric(parent, "Company reputation", "%d / 100" % int(value.reputation))
	metric(parent, "Assets · Company cash", "%s · %s" % [sale_money(int(value.inventory_value + value.goods_in_transit_value), str(value.currency)), sale_money(int(value.cash), str(value.currency))])
	metric(parent, "Outstanding liabilities", sale_money(int(value.liabilities), str(value.currency)))
	var explanation := "%s. %d operating days; multiple %.2fx. Inventory is included once in earnings value, or counted as a verified asset in the fallback. Sale proceeds go to the CEO's personal sale ledger; corporate funds are not transferred." % [str(value.method), int(value.operating_days), float(value.multiple)]
	parent.add_child(label(explanation, 13, Style.MUTED))
	action(parent, "Sell Company", sell_current_company, true)

func finance() -> void:
	var anchor: int = report_end if report_end > 0 else sim.state.day
	var boundaries := Calendar.bounds(period, anchor)
	var report := sim.calendar_report(period, anchor)
	financial_dashboard(report)
	var controls := card("Financial Statements")
	var selection := dropdown(controls, Calendar.PERIODS, period)
	selection.item_selected.connect(func(index: int):
		period = index
		render()
	)
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

func financial_dashboard(report: Dictionary) -> void:
	var view := card("Financial Dashboard")
	var summary := FinanceManagement.dashboard(sim.state, report)
	var kpis := GridContainer.new()
	kpis.columns = 3 if size.x >= 900.0 else 2
	kpis.add_theme_constant_override("h_separation", 10)
	kpis.add_theme_constant_override("v_separation", 10)
	view.add_child(kpis)
	for item in [
		["Company Cash", money(summary.cash)], ["Revenue", money(summary.revenue)],
		["Expenses", money(-summary.expenses)], ["Gross Profit", money(summary.gross_profit)],
		["Net Profit", money(summary.net_profit)],
		["Receivables", money(summary.receivables)], ["Supplier Payables", money(summary.payables)],
		["Customer Deposits Held", money(summary.customer_deposits)],
	]:
		var metric_card := PanelContainer.new()
		metric_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metric_card.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 10, 10))
		var content := VBoxContainer.new()
		content.add_child(label(str(item[0]), 12, Style.MUTED))
		content.add_child(label(str(item[1]), 16, Style.GOLD))
		metric_card.add_child(content)
		kpis.add_child(metric_card)
	view.add_child(label("Delivered sales settle under existing revenue rules. Supplier purchases may be paid in cash or financed through trade credit, which creates a payable until repayment or return adjustment. Customer deposits remain a liability until delivery or refund.", 13, Style.MUTED))
	var forecast := card("Known Fixed-Cost Estimate")
	metric(forecast, "Known next-day fixed costs", money(-int(summary.known_fixed_costs)))
	metric(forecast, "Cash after known fixed costs", money(int(summary.cash_after_known_fixed_costs)), profit_color(int(summary.cash_after_known_fixed_costs)))
	forecast.add_child(label("Informational estimate only. It excludes future sales, variable expenses, advertising, new supplier orders, and unsettled receipts. Forecast cash is not available cash.", 13, Style.MUTED))
	var trend := card("Financial Trends · Last 7 Recorded Days")
	var daily := FinanceManagement.daily_totals(sim.state, maxi(1, sim.state.day - 7), sim.state.day - 1)
	var trend_labels: Array[String] = []
	var revenue: Array[float] = []
	var expenses: Array[float] = []
	var profit: Array[float] = []
	for row in daily:
		var day := int(row.day)
		trend_labels.append("D%d" % day)
		revenue.append(float(sim.state.ledger[day - 1].sales))
		expenses.append(float(row.expenses))
		profit.append(float(row.net_profit))
	var chart := FinanceChart.new()
	chart.custom_minimum_size.y = 170
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.configure(trend_labels, [
		{"name": "Revenue", "values": revenue, "color": Style.GREEN},
		{"name": "Expenses", "values": expenses, "color": Style.GOLD},
		{"name": "Net Profit", "values": profit, "color": Color("#83b7ff")},
	])
	trend.add_child(chart)
	trend.add_child(ChartLegend.build([
		{"name": "Revenue", "color": Style.GREEN},
		{"name": "Expenses", "color": Style.GOLD},
		{"name": "Net Profit", "color": Color("#83b7ff")},
	]))

func expense_management() -> void:
	var controls := card("Expense Reporting Period")
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
	var dates := row(controls)
	var older := action(dates, "Previous", change_report_end.bind(boundaries.x - 1))
	older.disabled = boundaries.x <= 1
	var newer := action(dates, "Next", change_report_end.bind(boundaries.y + 1))
	newer.disabled = boundaries.y >= sim.state.day
	var categories := card("Expense Breakdown")
	var entries := FinanceManagement.expense_categories(report)
	if entries.is_empty():
		categories.add_child(label("No expenses were recorded for this period.", 14, Style.MUTED))
	else:
		for entry in entries:
			metric(categories, str(entry.label), money(-int(entry.amount)))
	var inventory_paid_total: int = int(report.purchases) + int(report.direct_purchases) + int(report.inbound_freight)
	if inventory_paid_total > 0:
		categories.add_child(label("Inventory purchase and freight cash payments are tracked separately from expenses because unsold inventory remains an asset; Cost of Goods Sold is recognized when units sell.", 13, Style.MUTED))
		metric(categories, "Inventory and freight cash payments", money(-inventory_paid_total))
	var history := card("Daily Ledger History")
	var daily := FinanceManagement.daily_totals(sim.state, report.start, report.end)
	if daily.is_empty():
		history.add_child(label("No recorded daily entries are available for this period.", 14, Style.MUTED))
	for entry in daily:
		var day_card := PanelContainer.new()
		day_card.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 8, 10))
		var day_content := VBoxContainer.new()
		day_content.add_child(label(Calendar.format(int(entry.day)), 15, Style.GOLD))
		metric(day_content, "Sales · Total expenses", "%s · %s" % [money(int(entry.sales)), money(-int(entry.expenses))])
		metric(day_content, "Net profit · Cash movement", "%s · %s" % [money(int(entry.net_profit)), money(int(entry.cash_change))])
		day_card.add_child(day_content)
		history.add_child(day_card)

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
	if report.get("inventory_returns", 0) > 0:
		metric(view, "Supplier return loss", money(report.supplier_refunds - report.inventory_returns))
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
	metric(view, "Supplier Payables", money(report.get("supplier_payables", 0)))
	metric(view, "Contributed capital", money(report.equity_capital))
	metric(view, "Retained earnings", money(report.retained))
	metric(view, "Total liabilities and equity", money(report.overdraft + report.customer_deposits + report.get("supplier_payables", 0) + report.equity_capital + report.retained), Style.GOLD)

func cash_flow(report: Dictionary) -> void:
	var view := card(STATEMENTS[2])
	var lines := FinanceManagement.cash_flow_lines(report)
	metric(view, "Opening cash", money(report.opening_cash))
	divider(view)
	metric(view, "Receipts from customers", money(lines.customer_receipts))
	metric(view, "Customer refunds paid", money(lines.customer_refunds))
	metric(view, "Warehouse goods paid", money(lines.warehouse_goods))
	metric(view, "Supplier-direct goods paid", money(lines.supplier_direct_goods))
	metric(view, "Inbound freight paid", money(lines.inbound_freight))
	metric(view, "Supplier repayments", money(lines.supplier_repayments))
	metric(view, "Supplier refunds received", money(lines.supplier_refunds))
	metric(view, "Outbound shipping paid", money(lines.outbound_shipping))
	metric(view, "Advertising paid", money(lines.advertising))
	metric(view, "Store setup paid", money(lines.store_setup))
	metric(view, "Additional store expenses paid", money(lines.store_expenses))
	metric(view, "Other operating payments", money(lines.other_operating))
	metric(view, "Owner investment", money(lines.owner_investment))
	if int(lines.total) != Sim.cash_change(report):
		view.add_child(label("Cash flow reconciliation error: the displayed lines do not match recorded cash movement.", 13, Style.RED))
	metric(view, "Net change in cash", money(Sim.cash_change(report)), profit_color(Sim.cash_change(report)))
	divider(view)
	metric(view, "Closing cash", money(report.closing_cash), Style.GOLD)
