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
const DevAPI = preload("res://developer_test_api.gd")
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
var developer_access_overlay: Control
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
var dev_preview_size_callback: JavaScriptObject
var dev_command_callback: JavaScriptObject
var dev_api := DevAPI.new()
var developer_mode_unlocked := false
var developer_console_visible := false
var developer_changes_active := false
var developer_original_viewport := Vector2i.ZERO
var developer_preview_active := false
var developer_overlay: Control
var developer_access_code_value := ""
var developer_access_error_message := ""
var developer_console_tab := "Home"
var developer_cheat_category := "Finance"
var developer_scenario := ""
var profile_editing := false
var profile_edit_snapshot: Dictionary = {}
var company_profile_editing := false
var store_listing_editing := false
var campaign_editing := false
var shipping_settings_editing := false
var display_settings_editing := false
var avatar_crop_source: Image
var navigation_panel: PanelContainer
var navigation_slot: Control
var navigation_open := false
var navigation_toggle: Button
var bank_balance_label: Label
var header_bank_balance_label: Label
var header_bank_balance_value: Label
var day_advance_pending := false
var day_advance_processing := false
var profile_sections_expanded := {"achievements": false, "technical": false}
var transaction_details_expanded: Dictionary = {}
var expanded_order_details: Dictionary = {}
var preorder_show_history := false
var ad_expanded_campaigns: Dictionary = {}
var header_mobile_layout := false
var header_compact_layout := false
var header_mobile_wrap_layout := false
var compact_landscape_layout := false
var header_date_label: Label
var header_title_label: Label
var header_company_label: Label

func _ready() -> void:
	theme = Style.build()
	if OS.has_feature("web"):
		dev_preview_size_callback = JavaScriptBridge.create_callback(_set_developer_preview_viewport)
		var js_window := JavaScriptBridge.get_interface("window")
		js_window.obtSetPreviewLogicalSize = dev_preview_size_callback
		var base_size := get_window().content_scale_size
		JavaScriptBridge.eval("window.obtPreviewDefaultLogicalSize = [%d, %d];" % [base_size.x, base_size.y])
		if OS.is_debug_build():
			dev_command_callback = JavaScriptBridge.create_callback(_receive_dev_command)
			js_window.obtRunDevCommand = dev_command_callback
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

func _set_developer_preview_viewport(args: Array) -> void:
	if args.size() < 2:
		return
	var width := maxi(1, int(args[0]))
	var height := maxi(1, int(args[1]))
	var requested := Vector2i(width, height)
	get_window().content_scale_size = requested
	developer_preview_active = developer_mode_unlocked and developer_original_viewport != Vector2i.ZERO and requested != developer_original_viewport

func _receive_dev_command(args: Array) -> void:
	var raw := str(args[0]) if not args.is_empty() else "{}"
	var command_data: Variant = JSON.parse_string(raw)
	var response: Dictionary
	if command_data is Dictionary:
		if str(command_data.get("command", "")) == "open_console":
			open_developer_mode()
			response = {"ok": true, "code": "console_opened", "message": "Developer console opened."}
		else:
			response = dev_api.execute(str(command_data.get("command", "")), command_data.get("args", {}), self)
	else:
		response = {"ok": false, "code": "invalid_command", "message": "Command must be a JSON object."}
	if OS.has_feature("web"):
		var serialized := JSON.stringify(response).json_escape()
		JavaScriptBridge.eval("window.OBTDevResult = JSON.parse(\"%s\");" % serialized)

func open_developer_mode() -> void:
	if sim == null:
		set_notice("Load an existing company before opening Developer Mode.", true)
		return
	developer_mode_unlocked = true
	developer_console_visible = true
	developer_changes_active = dirty
	if developer_original_viewport == Vector2i.ZERO:
		developer_original_viewport = get_window().content_scale_size
	_developer_sync_landscape_scale()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.OBTDevPreview && window.OBTDevPreview.enable();")
	set_notice("")
	render()

func _open_developer_mode_now() -> void:
	open_developer_mode()

func leave_developer_mode() -> void:
	if not developer_mode_unlocked: return
	if developer_original_viewport != Vector2i.ZERO and get_window().content_scale_size != developer_original_viewport:
		set_developer_preview("exit")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.OBTDevPreview && window.OBTDevPreview.disable();")
	developer_mode_unlocked = false
	developer_console_visible = false
	developer_original_viewport = Vector2i.ZERO
	set_notice("Developer Mode locked. Current game state is unchanged.")
	render()

func close_developer_console() -> void:
	if not developer_mode_unlocked: return
	developer_console_visible = false
	if not developer_preview_active:
		_developer_restore_original_scale()
	render()

func _developer_browser_viewport_size() -> Vector2i:
	if OS.has_feature("web"):
		var width := int(JavaScriptBridge.eval("window.innerWidth"))
		var height := int(JavaScriptBridge.eval("window.innerHeight"))
		if width > 0 and height > 0: return Vector2i(width, height)
	return Vector2i(roundi(size.x), roundi(size.y))

func _developer_sync_landscape_scale() -> void:
	_sync_gameplay_landscape_scale()

func _sync_gameplay_landscape_scale() -> void:
	if not OS.has_feature("web") or developer_preview_active or sim == null:
		return
	var base_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 430)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 760))
	)
	var browser_size := _developer_browser_viewport_size()
	var target := base_size
	# Scaling the portrait base by a short landscape height makes controls too
	# small. Match the Web logical viewport to the available landscape viewport.
	if browser_size.x > browser_size.y and browser_size.y <= 600:
		target = browser_size
	if get_window().content_scale_size != target:
		get_window().content_scale_size = target

func _developer_restore_original_scale() -> void:
	if developer_original_viewport != Vector2i.ZERO and get_window().content_scale_size != developer_original_viewport:
		get_window().content_scale_size = developer_original_viewport

func _set_developer_scroll_passthrough(control: Control) -> void:
	# Let wheel and touch-scroll input bubble through passive content and buttons
	# to the enclosing ScrollContainer. The overlay itself still blocks gameplay.
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in control.get_children():
		if child is Control:
			_set_developer_scroll_passthrough(child as Control)

func create_developer_backup() -> Dictionary:
	if not developer_mode_unlocked or sim == null or active_game_id.is_empty():
		return {"ok": false, "message": "Load an active company before backing it up."}
	var directory := "user://obt_dev_backups"
	var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if make_error != OK:
		return {"ok": false, "message": "Could not create the local backup folder: %s" % error_string(make_error)}
	var random_id := Crypto.new().generate_random_bytes(6).hex_encode()
	var backup_path := directory.path_join("%s-%d-%s.backup" % [active_game_id, Time.get_unix_time_from_system(), random_id])
	if FileAccess.file_exists(backup_path):
		return {"ok": false, "message": "A backup already exists at this path; no file was overwritten."}
	var backup := {
		"version": 1, "created_at": Time.get_unix_time_from_system(),
		"game_id": active_game_id, "screen": screen, "page": page,
		"state": sim.state.duplicate(true), "ceo_profile": ceo_profile.duplicate(true),
		"dirty_before_backup": dirty, "slots": {}
	}
	for slot in Slots.COUNT:
		var source_path := Slots.path_for_game(active_game_id, slot)
		if not source_path.is_empty() and FileAccess.file_exists(source_path):
			backup.slots[str(slot)] = FileAccess.get_file_as_bytes(source_path)
	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not write the backup: %s" % error_string(FileAccess.get_open_error())}
	file.store_var(backup, true)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "message": "Backup write failed: %s" % error_string(write_error)}
	return {"ok": true, "path": backup_path, "message": "Current company state and existing save slots backed up locally."}

func set_developer_preview(name: String) -> Dictionary:
	var presets := {"desktop": Vector2i(900, 1200), "tablet": Vector2i(768, 1024), "mobile": Vector2i(390, 844)}
	if name == "exit":
		developer_preview_active = false
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.OBTDevPreview && window.OBTDevPreview.exit();")
		get_window().content_scale_size = developer_original_viewport if developer_original_viewport != Vector2i.ZERO else Vector2i(430, 760)
		return {"ok": true, "code": "preview_restored", "message": "Original viewport restored."}
	if not presets.has(name): return {"ok": false, "code": "invalid_preview", "message": "Choose desktop, tablet, or mobile portrait."}
	var selected: Vector2i = presets[name]
	developer_preview_active = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.OBTDevPreview && window.OBTDevPreview.select('%s');" % name)
	else:
		get_window().content_scale_size = selected
		_update_responsive_layout()
	return {"ok": true, "code": "preview_selected", "message": "%s portrait preview selected." % name.capitalize(), "width": selected.x, "height": selected.y}

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
	var semantic_role := Style.button_role_for_action(title)
	if accent and semantic_role == Style.ROLE_SECONDARY:
		semantic_role = Style.ROLE_PRIMARY
	Style.apply_button_role(node, semantic_role)
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
	parent.add_child(label(Style.heading_text(caption), 14, Style.MUTED))
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
	if not title.is_empty():
		content.add_child(label(title, 20))
	return content

func divider(parent: Node) -> void:
	var line := HSeparator.new()
	parent.add_child(line)

func metric(parent: Node, caption: String, value: String, color: Color = Style.TEXT) -> void:
	var line := BoxContainer.new()
	line.name = "ResponsiveMetric"
	line.vertical = size.x < 600.0
	line.add_theme_constant_override("separation", 2 if line.vertical else 8)
	if OS.has_feature("web"):
		line.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_sync_gameplay_landscape_scale()
	var viewport_width := size.x
	var compact_landscape := size.y <= 450.0 and size.x > size.y
	if compact_landscape != compact_landscape_layout:
		render()
		return
	Market.update_responsive_layout(self)
	for metric_row in find_children("ResponsiveMetric", "BoxContainer", true, false):
		var responsive_metric := metric_row as BoxContainer
		responsive_metric.vertical = viewport_width < 600.0
		responsive_metric.add_theme_constant_override("separation", 2 if responsive_metric.vertical else 8)
	var inventory_panel := find_child("DashboardInventoryOverview", true, false) as PanelContainer
	var mobile_layout := viewport_width < 600.0
	if inventory_panel != null and bool(inventory_panel.get_meta("mobile_layout", false)) != mobile_layout:
		var inventory_parent := inventory_panel.get_parent()
		var inventory_index := inventory_panel.get_index()
		inventory_parent.remove_child(inventory_panel)
		inventory_panel.queue_free()
		var replacement := InventoryOverview.build(sim, mobile_layout, self)
		inventory_parent.add_child(replacement)
		inventory_parent.move_child(replacement, inventory_index)
	var date_label := find_child("GameDate", true, false) as Label
	if date_label != null and sim != null:
		if ((viewport_width < 600.0) != header_mobile_layout or (viewport_width < 760.0) != header_compact_layout
			or (viewport_width < 350.0) != header_mobile_wrap_layout):
			render()
			return
		date_label.text = _game_date_text()
		date_label.tooltip_text = Calendar.format(sim.state.day) + " | " + Catalog.COUNTRIES[sim.state.country]
		_update_header_text()
	if page == "Profile":
		var identity_layout := find_child("CEOIdentityLayout", true, false) as BoxContainer
		if identity_layout != null:
			if (identity_layout is HBoxContainer) != (viewport_width >= 600.0):
				render()
				return
	if is_instance_valid(page_shell):
		var horizontal_margin := 20 if viewport_width >= 900.0 else 12
		page_shell.custom_minimum_size.x = minf(1100.0, maxf(280.0, viewport_width - horizontal_margin * 2.0))
	if is_instance_valid(navigation_panel):
		navigation_panel.custom_minimum_size.x = clampf(viewport_width * 0.78, 260.0, 320.0)
		_sync_navigation_slot_size()
	if is_instance_valid(page_grid):
		page_grid.columns = 2 if viewport_width >= 768.0 else 1
		_reflow_page_cards()
	if is_instance_valid(navigation_toggle):
		navigation_toggle.custom_minimum_size.x = 40
	if is_instance_valid(bank_balance_label) or is_instance_valid(header_bank_balance_value): _refresh_bank_balance()
	var kpis := find_child("DashboardKpis", true, false) as GridContainer
	if kpis != null:
		kpis.columns = 4 if viewport_width >= 900.0 else 2
	var shortcuts := find_child("DashboardShortcuts", true, false) as GridContainer
	if shortcuts != null:
		shortcuts.columns = 3 if viewport_width >= 900.0 else (2 if viewport_width >= 600.0 else 1)
	for grid_name in ["SavedGameCards", "LoadGameCards", "GameSaveSlots", "ChooseCompanyCards"]:
		var grid := find_child(grid_name, true, false) as GridContainer
		if grid != null:
			grid.columns = 3 if viewport_width >= 900.0 else (2 if viewport_width >= 600.0 else 1)
	var menu_actions := find_child("MainMenuActions", true, false) as FlowContainer
	if menu_actions != null:
		menu_actions.custom_minimum_size.x = minf(580.0, maxf(0.0, viewport_width - 66.0))
		for child in menu_actions.get_children():
			var action_button := child as Button
			if action_button != null:
				action_button.custom_minimum_size.x = 150.0 if viewport_width < 600.0 else 172.0

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
	if sim == null:
		return
	var value := money(int(sim.state.get("cash", 0)))
	var color := Style.RED if int(sim.state.get("cash", 0)) < 0 else Style.GOLD
	for balance in [bank_balance_label, header_bank_balance_value]:
		if is_instance_valid(balance):
			balance.text = value
			balance.add_theme_color_override("font_color", color)

func persist(message: String) -> void:
	if developer_changes_active:
		dirty = true
		set_notice("Developer changes are still unsaved. Open Save Game and choose a save slot to keep them.", true)
		return
	_sync_ceo_profile()
	write_progress(Slots.AUTOSAVE, message)

func write_progress(slot: int, message: String, explicitly_selected: bool = false) -> bool:
	if developer_changes_active and slot == Slots.AUTOSAVE and not explicitly_selected:
		dirty = true
		set_notice("Autosave did not replace your existing save because developer changes are pending. Choose a save slot to save them.", true)
		return false
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
	developer_changes_active = false
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

func confirm_action(title: String, message: String, confirm_text: String, callback: Callable,
		cancel_callback: Callable = Callable()) -> void:
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
	dialog.canceled.connect(func():
		if confirmation == dialog:
			confirmation = null
		dialog.hide()
		if cancel_callback.is_valid():
			cancel_callback.call()
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
		var game_name := str(GameStore.get_game(active_game_id).get("game_name", ""))
		ceo_profile = CEOProfile.ensure_for_game({}, str(sim.state.get("owner", "")), active_game_id, game_name)
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
	var view := wide_card("")
	var actions := FlowContainer.new()
	actions.name = "CompanySelectionActions"
	actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.custom_minimum_size.x = minf(360.0, maxf(0.0, size.x - 66.0))
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	view.add_child(actions)
	var start_action := action(actions, "Start a New Company", func(): show_screen("Setup"), true)
	start_action.name = "StartAnotherCompany"
	start_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_action.custom_minimum_size.x = 184
	var back_action := action(actions, "Back to Title", func(): show_screen("Title"))
	back_action.name = "BackToTitle"
	back_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_action.custom_minimum_size.x = 160
	var owned: Array[Dictionary] = CEOProfile.owned_companies(ceo_profile)
	if owned.is_empty():
		view.add_child(label("You do not currently own a company.", 15, Style.MUTED))
	else:
		var name_counts := {}
		for entry in owned:
			var company_name := str(entry.get("name", "Company"))
			name_counts[company_name] = int(name_counts.get(company_name, 0)) + 1
		var companies_grid := GridContainer.new()
		companies_grid.name = "ChooseCompanyCards"
		companies_grid.columns = 2 if size.x >= 768.0 else 1
		companies_grid.add_theme_constant_override("h_separation", 12)
		companies_grid.add_theme_constant_override("v_separation", 10)
		view.add_child(companies_grid)
		for entry in owned:
			var company_name := str(entry.get("name", "Company"))
			var company_id := str(entry.get("company_id", ""))
			if int(name_counts.get(company_name, 0)) > 1:
				var short_id := company_id.right(6) if company_id.length() > 6 else company_id
				company_name += " · %s" % short_id
			var company_card := _create_card(companies_grid, company_name)
			company_card.name = "OwnedCompany_%s" % company_id
			metric(company_card, "Country", company_entry_country(entry))
			metric(company_card, "Lifetime Net Sales", sale_money(int(entry.get("lifetime_sales", 0)), company_entry_currency(entry)))
			metric(company_card, "Lifetime Net Profit", sale_money(int(entry.get("lifetime_profit", 0)), company_entry_currency(entry)))
			var card_actions := row(company_card)
			action(card_actions, "Open Company", switch_company.bind(company_id), true)
			action(card_actions, "Delete Company", delete_company.bind(company_id))
	var sold: Array[Dictionary] = []
	for entry in ceo_profile.get("companies", []):
		if entry is Dictionary and str(entry.get("ownership_status", "owned")) == "sold": sold.append(entry)
	if not sold.is_empty():
		var archive := _create_card(view, "Sold Company Records")
		archive.add_child(label("Sold businesses remain in your career history and cannot be reopened or deleted.", 13, Style.MUTED))
		for entry in sold:
			var sale: Dictionary = entry.get("sale_record", {})
			archive.add_child(label("%s · Sold for %s · %s" % [str(entry.get("name", "Company")), sale_money(int(sale.get("amount", 0)), str(sale.get("currency", ""))), str(sale.get("date", "Date unavailable"))], 14, Style.GOLD))

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
			var result: Error = GameStore.update_game_profile(active_game_id, ceo_profile)
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
	var current_level := CEOProfile.level(ceo_profile)
	var total_xp := int(ceo_profile.get("xp", 0))
	var current_level_xp := posmod(total_xp, CEOProfile.LEVEL_XP)
	metric(career, "Current Level", str(current_level), Style.GOLD)
	metric(career, "Career Title", CEOProfile.progression_title(ceo_profile), Style.GOLD)
	metric(career, "Current XP", _grouped_integer(total_xp))
	metric(career, "XP to Next Level", str(CEOProfile.xp_to_next_level(ceo_profile)))
	var progress := ProgressBar.new()
	progress.name = "CareerXPProgress"
	progress.min_value = 0
	progress.max_value = CEOProfile.LEVEL_XP
	progress.value = current_level_xp
	progress.show_percentage = false
	progress.custom_minimum_size.y = 14
	progress.tooltip_text = "%d / %d XP toward the next level" % [current_level_xp, CEOProfile.LEVEL_XP]
	career.add_child(progress)
	var next_title := CEOProfile.next_title(ceo_profile)
	if not str(next_title.get("title", "")).is_empty():
		metric(career, "Next Career Title", str(next_title.title))
		metric(career, "Unlocks at Level", str(next_title.level))
	else:
		metric(career, "Progression", "Highest career title reached")
	metric(career, "Personal Reputation", "%d / 100" % int(ceo_profile.get("personal_reputation", 0)))
	var additional := card("Career Statistics")
	var company_records: Array = ceo_profile.get("companies", [])
	var active_companies := 0
	for company_record in company_records:
		if str(company_record.get("ownership_status", "owned")) == "owned" and not bool(company_record.get("bankrupt", false)):
			active_companies += 1
	var ceo_id := str(ceo_profile.get("ceo_id", ""))
	var career_start := str(ceo_profile.get("career_start_date", ""))
	metric(additional, "Career Start Date", career_start if not career_start.is_empty() else "Not available")
	metric(additional, "Companies Founded", str(company_records.size()))
	metric(additional, "Active Companies", str(active_companies))
	var technical_toggle := action(additional,
		"Hide CEO Details" if bool(profile_sections_expanded.get("technical", false)) else "Show CEO Details",
		func():
			profile_sections_expanded.technical = not bool(profile_sections_expanded.get("technical", false))
			refresh_view()
	)
	technical_toggle.name = "ToggleTechnicalCEOProfileDetails"
	if bool(profile_sections_expanded.get("technical", false)):
		metric(additional, "CEO ID", ceo_id if not ceo_id.is_empty() else "Not available")
		metric(additional, "Game ID", str(ceo_profile.get("game_id", "Not available")))
		if not ceo_id.is_empty():
			action(additional, "Copy CEO ID", func():
				DisplayServer.clipboard_set(ceo_id)
				set_notice("CEO ID copied.")
		)
	var achievements := card("Achievements")
	var earned: Array = ceo_profile.get("achievements", [])
	achievements.add_child(label("%d achievements unlocked" % earned.size(), 13, Style.MUTED))
	var achievement_toggle := action(achievements,
		"Hide Achievements" if bool(profile_sections_expanded.get("achievements", false)) else "View Achievements",
		func():
			profile_sections_expanded.achievements = not bool(profile_sections_expanded.get("achievements", false))
			refresh_view()
	)
	achievement_toggle.name = "ToggleAchievementDetails"
	if bool(profile_sections_expanded.get("achievements", false)):
		if earned.is_empty():
			achievements.add_child(empty_state("No Achievements Yet", "Complete company and sales milestones to unlock achievements."))
		else:
			for item in earned:
				achievements.add_child(label("• %s" % _achievement_summary(item), 14, Style.GOLD))
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

func _achievement_summary(item: Dictionary) -> String:
	var achievement_id := str(item.get("id", ""))
	match achievement_id:
		"company_registered": return "First company registered"
		"company_expansion": return "Founded an additional company"
		"first_sale": return "Completed first sale"
		"market_expansion": return "Expanded into another market"
		"bankruptcy_survivor": return "Navigated a company bankruptcy"
	if achievement_id.begins_with("sales_"):
		return "Lifetime sales milestone · %s threshold" % _grouped_integer(achievement_id.trim_prefix("sales_").to_int())
	if achievement_id.begins_with("profit_"):
		return "Lifetime profit milestone · %s threshold" % _grouped_integer(achievement_id.trim_prefix("profit_").to_int())
	return _title_case(str(item.get("title", achievement_id if not achievement_id.is_empty() else "Achievement")))

func _grouped_integer(value: int) -> String:
	var text_value := str(absi(value))
	var grouped := ""
	for index in text_value.length():
		if index > 0 and (text_value.length() - index) % 3 == 0:
			grouped += ","
		grouped += text_value.substr(index, 1)
	return ("−" if value < 0 else "") + grouped

func empty_state(title: String, description: String) -> VBoxContainer:
	var state := VBoxContainer.new()
	state.name = "EmptyState"
	state.add_theme_constant_override("separation", 4)
	state.add_child(label(title, 15, Style.TEXT))
	state.add_child(label(description, 13, Style.MUTED))
	return state

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
		write_progress(slot, "Saved to manual slot %d." % slot, true)
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
		if OS.has_feature("web") and developer_mode_unlocked:
			JavaScriptBridge.eval("window.OBTDevPreview && window.OBTDevPreview.disable();")
		developer_mode_unlocked = false
		developer_console_visible = false
		developer_changes_active = false
		developer_original_viewport = Vector2i.ZERO
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
	if target == "Company Management":
		discard_form_then(func():
			_reset_edit_modes()
			page = "Business"
			category_last_page["Business"] = "Business"
			set_notice("")
			render()
		)
		return
	if target == "Product Catalogue":
		discard_form_then(func():
			_reset_edit_modes()
			page = "Market"
			category_last_page["Market"] = "Market"
			show_new_store_form = false
			set_notice("")
			render()
		)
		return
	if target == "Growth": target = "Advertising"
	# Retain compatibility with the previous route label without changing saves.
	if target == "Store Management": target = "Management"
	if target == "Inventory Management": target = "My Products"
	if target == "Company Management": target = "Business"
	if target == "Campaign Management": target = "Campaign Manager"
	if target == "Ads Manager": target = "Campaign Manager"
	if target == "Ads Analytics": target = "Advertising Analytics"
	if target == "Expenses": target = "Expense Management"
	if target == "Statements": target = "Finance Statements"
	if target == "Inbound Stock": target = "Inbound Stock"
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
		if target == "Market":
			var market_scroll := body.get_parent() as ScrollContainer
			if market_scroll != null: market_scroll.scroll_vertical = 0
		set_notice("")
		render()
	)

func primary_category(target: String) -> String:
	if target in ["Market", "Inbound Stock", "Supplier Relationships", "Supplier Returns"]: return "Market"
	if target in ["My Products", "Management", "Store Listings", "Business", "Company Sale", "Store Profitability"]: return "Business"
	if target in ["Orders", "Pre-orders"]: return "Order"
	if target in ["Advertising", "Campaign Manager", "Campaign Details", "Advertising Analytics"]: return "Marketing"
	if target == "Marketing": return "Marketing"
	if target in ["Finance", "Finance Statements", "Expense Management"]: return "Finance"
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
	header_mobile_layout = size.x < 600.0
	header_compact_layout = size.x < 760.0
	header_mobile_wrap_layout = size.x < 350.0
	var viewport_width := size.x
	var header := PanelContainer.new()
	header.name = "UltraCompactGlobalHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_theme_stylebox_override("panel", Style.box(Color("#101A29"), Color("#34445B"), 9, 5 if compact_landscape_layout else 7))
	parent.add_child(header)
	var rows := stack(header, 2 if compact_landscape_layout else 3)
	rows.name = "UltraCompactGlobalHeaderRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var heading := row(rows)
	heading.name = "GameHeaderPrimaryRow"
	heading.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	heading.add_theme_constant_override("separation", 5)
	var menu_button := action(heading, "", toggle_navigation_drawer, false)
	menu_button.name = "NavigationMenuButton"
	menu_button.custom_minimum_size = Vector2(36, 34) if compact_landscape_layout else Vector2(40, 40)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_button.tooltip_text = "Open navigation menu"
	_apply_drawer_icon(menu_button, DRAWER_ICON_PATHS.Menu, 20)
	navigation_toggle = menu_button
	var company_info := stack(heading, 0)
	company_info.name = "HeaderCompanyInformation"
	company_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	company_info.custom_minimum_size.x = 180 if viewport_width >= 600.0 else 0
	header_title_label = label("ONLINE BUSINESS TYCOON", 12, Style.GOLD)
	header_title_label.name = "HeaderGameTitle"
	header_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	company_info.add_child(header_title_label)
	header_company_label = label(str(sim.state.get("company", "Company")), 14 if viewport_width < 600.0 else 15, Style.TEXT)
	header_company_label.name = "HeaderCompanyName"
	header_company_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	company_info.add_child(header_company_label)
	var developer_button := action(heading, "</>", request_developer_mode_access, false)
	developer_button.name = "DeveloperModeButton"
	developer_button.custom_minimum_size = Vector2(36, 30) if compact_landscape_layout else Vector2(40, 34)
	developer_button.add_theme_font_size_override("font_size", 12)
	developer_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	developer_button.tooltip_text = "Developer Mode unlocked for this active game" if developer_mode_unlocked else "Open Developer Mode for the active company"
	if developer_mode_unlocked: Style.primary(developer_button)
	else: Style.secondary(developer_button)
	var details := row(rows)
	details.name = "GameHeaderSecondaryRow"
	details.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	details.add_theme_constant_override("separation", 6)
	header_date_label = label(_game_date_text(), 12 if viewport_width < 600.0 else 13, Style.MUTED)
	header_date_label.name = "GameDate"
	header_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_date_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	header_date_label.tooltip_text = _game_date_text()
	details.add_child(header_date_label)
	if viewport_width >= 760.0:
		_add_header_bank_balance(heading)
		advance_day_controls(details, true)
	elif viewport_width >= 600.0:
		_add_header_bank_balance(heading)
		var compact_advance := row(rows)
		compact_advance.alignment = BoxContainer.ALIGNMENT_END
		advance_day_controls(compact_advance, true)
	else:
		var mobile_balance_and_advance := row(rows)
		mobile_balance_and_advance.name = "MobileBalanceAndAdvanceRow"
		mobile_balance_and_advance.add_theme_constant_override("separation", 8)
		_add_header_bank_balance(mobile_balance_and_advance, true)
		var mobile_advance: VBoxContainer
		if header_mobile_wrap_layout:
			mobile_advance = stack(rows, 1)
			mobile_advance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			mobile_advance = stack(mobile_balance_and_advance, 1)
			mobile_advance.size_flags_horizontal = Control.SIZE_SHRINK_END
		mobile_advance.name = "MobileAdvanceDayGroup"
		advance_day_controls(mobile_advance, false)
	_create_navigation_drawer()
	return menu_button

func _add_header_bank_balance(parent: Node, stacked: bool = false) -> void:
	var display: Control = stack(parent, 0) if stacked else row(parent)
	display.name = "CompanyBankBalance"
	display.size_flags_horizontal = Control.SIZE_SHRINK_END if not stacked else Control.SIZE_EXPAND_FILL
	display.custom_minimum_size.x = 130 if stacked else 245
	display.add_theme_constant_override("separation", 4)
	header_bank_balance_label = label("Bank Balance", 11, Style.MUTED)
	header_bank_balance_label.name = "HeaderBankBalanceLabel"
	header_bank_balance_label.custom_minimum_size.x = 78
	header_bank_balance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_bank_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display.add_child(header_bank_balance_label)
	header_bank_balance_value = label(money(int(sim.state.get("cash", 0))), 13, Style.GOLD)
	header_bank_balance_value.name = "HeaderBankBalanceValue"
	header_bank_balance_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not stacked else HORIZONTAL_ALIGNMENT_LEFT
	header_bank_balance_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_bank_balance_value.custom_minimum_size.x = 135 if stacked else 145
	header_bank_balance_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not stacked else Control.SIZE_SHRINK_BEGIN
	header_bank_balance_value.autowrap_mode = TextServer.AUTOWRAP_OFF if not stacked else TextServer.AUTOWRAP_WORD_SMART
	header_bank_balance_value.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	display.add_child(header_bank_balance_value)
	_refresh_bank_balance()

func _game_date_text() -> String:
	var country: String = Catalog.COUNTRIES[int(sim.state.country)]
	return "Day %d · %s · %s" % [sim.state.day, Calendar.format(sim.state.day), country]

func advance_day_controls(parent: Node, horizontal: bool = true) -> void:
	var controls := row(parent)
	controls.name = "GlobalAdvanceDayControls"
	controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	controls.add_theme_constant_override("separation", 4)
	var title := label("Advance Day", 12, Style.GOLD)
	title.name = "AdvanceDayLabel"
	title.visible = horizontal
	title.custom_minimum_size.x = 78
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not horizontal:
		var group_title := label("Advance Day", 11, Style.GOLD)
		group_title.name = "AdvanceDayGroupLabel"
		group_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		group_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		parent.add_child(group_title)
		parent.move_child(group_title, 0)
	controls.add_child(title)
	for days in [1, 2, 7, 30]:
		var button := action(controls, "+%d" % days, request_advance_days.bind(days), days == 1)
		button.name = "AdvanceDays%d" % days
		if compact_landscape_layout:
			button.custom_minimum_size = Vector2(38 if days == 30 else 32, 30)
			button.add_theme_font_size_override("font_size", 11)
		elif size.x < 600.0:
			button.custom_minimum_size = Vector2(40 if days == 30 else 34, 34)
			button.add_theme_font_size_override("font_size", 12)
		else:
			button.custom_minimum_size = Vector2(46, 40)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.disabled = day_advance_pending or day_advance_processing

func _update_header_text() -> void:
	if sim == null: return
	if is_instance_valid(header_title_label): header_title_label.text = "ONLINE BUSINESS TYCOON"
	if is_instance_valid(header_company_label): header_company_label.text = str(sim.state.get("company", "Company"))
	if is_instance_valid(header_date_label):
		header_date_label.text = _game_date_text()
		header_date_label.tooltip_text = _game_date_text()
	if is_instance_valid(header_bank_balance_value): _refresh_bank_balance()

func request_developer_mode_access() -> void:
	if developer_mode_unlocked:
		developer_console_visible = true
		_developer_sync_landscape_scale()
		_show_developer_console_overlay()
		return
	if has_form_edits():
		set_notice("Save or cancel the current form before opening Developer Mode.", true)
		return
	if developer_original_viewport == Vector2i.ZERO:
		developer_original_viewport = get_window().content_scale_size
	_developer_sync_landscape_scale()
	_show_developer_access_dialog()

func _show_developer_access_dialog() -> void:
	if is_instance_valid(confirmation) or is_instance_valid(developer_access_overlay): return
	_developer_sync_landscape_scale()
	var overlay := ColorRect.new()
	overlay.name = "DeveloperAccessDialog"
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.name = "DeveloperAccessScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		scroll.add_theme_constant_override("margin_" + side, 14)
	overlay.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "DeveloperAccessPanel"
	panel.custom_minimum_size.x = minf(400.0, maxf(280.0, size.x - 28.0))
	panel.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.GOLD, 10, 14))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)
	var content := stack(panel, 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = maxf(0.0, panel.custom_minimum_size.x - 28.0)
	content.add_child(label("Developer Mode Access", 18, Style.GOLD))
	content.add_child(label("Tools apply to this browser’s active company. The public access code is a convenience, not owner authentication.", 13, Style.MUTED))
	if sim == null:
		content.add_child(label("Load an existing company before unlocking Developer Mode.", 14, Style.GOLD))
	var code := LineEdit.new()
	code.name = "DeveloperAccessCode"
	code.placeholder_text = "Access code"
	code.secret = true
	code.text = developer_access_code_value
	code.custom_minimum_size.y = 44
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(code)
	var error_label := label(developer_access_error_message, 13, Style.RED)
	error_label.name = "DeveloperAccessError"
	error_label.visible = not developer_access_error_message.is_empty()
	content.add_child(error_label)
	var actions: BoxContainer = VBoxContainer.new() if size.x < 340.0 else row(content)
	if actions.get_parent() == null: content.add_child(actions)
	actions.add_theme_constant_override("separation", 6)
	var cancel := action(actions, "Cancel", func():
		_dismiss_developer_access_input(code)
		developer_access_overlay = null
		developer_access_code_value = ""
		developer_access_error_message = ""
		overlay.queue_free()
		_developer_restore_original_scale()
		developer_original_viewport = Vector2i.ZERO
	)
	cancel.name = "DeveloperAccessCancel"
	var unlock := action(actions, "Unlock Developer Mode", func(): _submit_developer_access(code, error_label), true)
	unlock.name = "DeveloperAccessUnlock"
	unlock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock.custom_minimum_size.y = 48
	Style.primary(unlock)
	developer_access_overlay = overlay
	add_child(overlay)
	code.text_submitted.connect(func(_value: String): _submit_developer_access(code, error_label))
	code.text_changed.connect(func(value: String): developer_access_code_value = value)
	code.grab_focus()
	call_deferred("_ensure_developer_access_focus", code)

func _ensure_developer_access_focus(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	var scroll := developer_access_overlay.find_child("DeveloperAccessScroll", true, false) as ScrollContainer if is_instance_valid(developer_access_overlay) else null
	if scroll != null: scroll.ensure_control_visible(control)

func _dismiss_developer_access_input(code: LineEdit) -> void:
	if is_instance_valid(code):
		code.release_focus()
	# The pressed Cancel/Unlock button may have acquired focus after the LineEdit.
	# Clear the viewport focus owner too, so neither control retains the IME.
	get_viewport().gui_release_focus()
	DisplayServer.virtual_keyboard_hide()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (document.activeElement && document.activeElement.blur) document.activeElement.blur();")

func _submit_developer_access(code: LineEdit, error_label: Label) -> void:
	if not is_instance_valid(developer_access_overlay): return
	if code.text.strip_edges().to_upper() == "URTN" and sim != null and not active_game_id.is_empty():
		var overlay := developer_access_overlay
		_dismiss_developer_access_input(code)
		developer_access_overlay = null
		developer_access_code_value = ""
		developer_access_error_message = ""
		overlay.queue_free()
		_open_developer_mode_after_keyboard()
	else:
		error_label.text = "Load an existing company first." if code.text.strip_edges().to_upper() == "URTN" else "Access code not recognized."
		error_label.visible = true
		developer_access_error_message = error_label.text
		if code.text.strip_edges().to_upper() != "URTN": code.clear()
		if code.is_inside_tree() and code.is_visible_in_tree():
			var scroll := developer_access_overlay.find_child("DeveloperAccessScroll", true, false) as ScrollContainer
			if scroll != null: scroll.ensure_control_visible(error_label)
			code.grab_focus()

func _open_developer_mode_after_keyboard() -> void:
	# iOS Safari animates visualViewport back to its full height after blur.
	# Let the Web shell and Godot resize before measuring the active game view.
	if OS.has_feature("web"):
		await get_tree().create_timer(0.35).timeout
	if sim != null and not active_game_id.is_empty():
		_open_developer_mode_now()

func request_advance_days(days: int) -> void:
	if sim == null or day_advance_pending or day_advance_processing or days not in [1, 2, 7, 30]:
		return
	day_advance_pending = true
	var current_day := int(sim.state.day)
	var destination_day := current_day + days
	var duration := "%d %s" % [days, "day" if days == 1 else "days"]
	confirm_action("Advance %s?" % duration,
		"Current day: Day %d\nDestination: Day %d\n\nAdvancing runs simulation events, including sales, orders, inventory, advertising, deliveries, and operating costs." % [current_day, destination_day],
		"Advance Day", Callable(self, "_confirm_advance_days").bind(days),
		Callable(self, "_cancel_advance_confirmation"))

func _confirm_advance_days(days: int) -> void:
	if day_advance_processing:
		return
	day_advance_pending = false
	day_advance_processing = true
	advance(days)

func _cancel_advance_confirmation() -> void:
	day_advance_pending = false

func toggle_navigation_drawer() -> void:
	if not is_instance_valid(navigation_panel):
		return
	navigation_open = not navigation_open
	navigation_panel.visible = navigation_open
	_sync_navigation_slot_size()
	if navigation_open:
		var page_scroller := find_child("GameContentScroll", true, false) as ScrollContainer
		if page_scroller != null:
			page_scroller.scroll_vertical = 0
		var active := navigation_panel.find_child("Primary_" + primary_category(page), true, false) as Button
		if active != null and active.is_inside_tree():
			active.grab_focus()
	else:
		_restore_navigation_focus()

func close_navigation_drawer(restore_focus: bool = true) -> void:
	if not is_instance_valid(navigation_panel):
		return
	navigation_open = false
	navigation_panel.visible = false
	_sync_navigation_slot_size()
	if restore_focus:
		_restore_navigation_focus()

func _restore_navigation_focus() -> void:
	if is_instance_valid(navigation_toggle) and navigation_toggle.is_inside_tree():
		navigation_toggle.grab_focus()

func _sync_navigation_slot_size() -> void:
	if not is_instance_valid(navigation_panel):
		return
	navigation_panel.position = Vector2.ZERO
	navigation_panel.size = navigation_panel.get_combined_minimum_size()
	if is_instance_valid(navigation_slot):
		navigation_slot.custom_minimum_size.y = navigation_panel.get_combined_minimum_size().y if navigation_open else 0.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(developer_access_overlay):
			var code := developer_access_overlay.find_child("DeveloperAccessCode", true, false) as LineEdit
			_dismiss_developer_access_input(code)
			developer_access_overlay.queue_free()
			developer_access_overlay = null
			developer_access_code_value = ""
			developer_access_error_message = ""
			_developer_restore_original_scale()
			developer_original_viewport = Vector2i.ZERO
		elif developer_console_visible:
			close_developer_console()
		elif navigation_open:
			close_navigation_drawer()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not navigation_open:
		return
	if event.keycode != KEY_TAB or not is_instance_valid(navigation_panel):
		return
	var focusable: Array[Control] = []
	for button in navigation_panel.find_children("*", "Button", true, false):
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
	var drawer := PanelContainer.new()
	drawer.name = "PrimaryNavigation"
	drawer.visible = false
	drawer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	drawer.custom_minimum_size.x = clampf(size.x * 0.78, 260.0, 320.0)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.GOLD, 9, 12))
	navigation_panel = drawer
	var content := stack(drawer, 10)
	var heading := row(content)
	var title := label("Navigation", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := action(heading, "Close", close_navigation_drawer)
	close_button.name = "PrimaryNavigationClose"
	close_button.custom_minimum_size = Vector2(72, 44)
	_apply_drawer_icon(close_button, DRAWER_ICON_PATHS.Close, 18)
	var nav_list := stack(content, 8)
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
	if developer_mode_unlocked:
		var lock_action := action(content, "Lock Developer Mode", leave_developer_mode)
		lock_action.name = "DrawerActionLockDeveloperMode"
		lock_action.custom_minimum_size.y = 46
		Style.secondary(lock_action)

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
		"Market": routes = [["Product Catalogue", "Market"], ["Inbound Stock", "Inbound Stock"], ["Supplier Relationships", "Supplier Relationships"], ["Supplier Returns", "Supplier Returns"]]
		"Order": routes = [["Customer Orders", "Orders"], ["Pre-orders", "Pre-orders"], ["Returns and Service", "Returns & Service"]]
		"Business": routes = [["Company Management", "Company Management"], ["Store Management", "Management"], ["Inventory Management", "My Products"], ["Store Profitability", "Store Profitability"]]
		"Marketing": routes = [["Overview", "Advertising"], ["Ads Manager", "Campaign Manager"], ["Ads Analytics", "Advertising Analytics"]]
		"Finance": routes = [["Dashboard", "Finance"], ["Statements", "Finance Statements"], ["Expenses", "Expense Management"]]
		_: return
	var scroller := ScrollContainer.new()
	scroller.name = "SecondaryNavigationScroll"
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var compact_landscape := size.y <= 450.0 and size.x > size.y
	scroller.custom_minimum_size.y = 34 if compact_landscape else 46
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
		elif target == "Finance Statements": selected = page == "Finance Statements"
		elif target == "Company Management": selected = page == "Business"
		else: selected = page == target
		var tab := secondary_tab(strip, title, route_secondary.bind(target), selected)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_style_secondary_navigation_tab(tab, selected)
		if compact_landscape:
			tab.custom_minimum_size.y = 32
			tab.add_theme_font_size_override("font_size", 11)

func render() -> void:
	if sim != null: _sync_gameplay_landscape_scale()
	var restore_access_dialog := is_instance_valid(developer_access_overlay)
	if restore_access_dialog:
		var open_code := developer_access_overlay.find_child("DeveloperAccessCode", true, false) as LineEdit
		var open_error := developer_access_overlay.find_child("DeveloperAccessError", true, false) as Label
		if open_code != null: developer_access_code_value = open_code.text
		if open_error != null and open_error.visible: developer_access_error_message = open_error.text
		developer_access_overlay = null
	edit_checks.clear()
	navigation_panel = null
	navigation_toggle = null
	navigation_slot = null
	bank_balance_label = null
	header_bank_balance_label = null
	header_bank_balance_value = null
	header_date_label = null
	header_title_label = null
	header_company_label = null
	navigation_open = false
	page_shell = null
	page_wide = null
	page_grid = null
	page_left_column = null
	page_right_column = null
	page_cards.clear()
	developer_overlay = null
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
	var compact_landscape := size.y <= 450.0 and size.x > size.y
	compact_landscape_layout = compact_landscape
	var horizontal_margin := 20 if viewport_width >= 900.0 else 12
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, horizontal_margin if side in ["left", "right"] else (7 if compact_landscape else 16))
	var centering := HBoxContainer.new()
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centering.add_theme_constant_override("separation", 0)
	margin.add_child(centering)
	var left_space := Control.new()
	left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(left_space)
	page_shell = stack(centering, 6 if compact_landscape else 12)
	page_shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_shell.custom_minimum_size.x = minf(1100.0, maxf(280.0, viewport_width - horizontal_margin * 2.0))
	var shell := page_shell
	var masthead := stack(shell, 3)
	var global_game_header := sim != null and screen not in ["Title", "Setup", "New Game", "Company Selection", "Load", "Entrepreneur name", "CEO identity conflict"]
	if global_game_header:
		primary_navigation(masthead)
	elif screen != "Title":
		masthead.add_child(label("ONLINE BUSINESS TYCOON", 13, Style.GOLD))
	if screen == "Game":
		var heading := row(masthead)
		heading.name = "PageHeading"
		var page_title := page
		match page:
			"Market": page_title = "Market"
			"Business": page_title = "Company Management"
			"Management": page_title = "Store Management"
			"My Products": page_title = "Inventory Management"
			"Advertising": page_title = "Marketing"
			"Campaign Manager": page_title = "Ads Manager"
			"Advertising Analytics": page_title = "Ads Analytics"
			"Finance Statements": page_title = "Statements"
			"Expense Management": page_title = "Expenses"
			"Inbound Stock": page_title = "Inbound Stock"
			"Supplier Relationships": page_title = "Supplier Relationships"
			"Supplier Returns": page_title = "Supplier Returns"
		var title := label(page_title, 21 if compact_landscape else (26 if viewport_width < 600.0 else 30))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
	elif screen == "Title":
		var brand_header := Menu.brand(self, masthead)
		_developer_button(brand_header)
	else:
		var titles := {"Setup": "Start your business", "Load": "Load Game", "Save": "Save Game", "Settings": "Settings",
			"Campaign Manager": "Ads Manager", "Campaign Details": "Campaign Details", "Company Selection": "Choose a Company",
			"Advertising Analytics": "Ads Analytics", "Management": "Store Management", "Store Listings": "Store Listings", "Avatar Crop": "Crop Profile Photo",
		"CEO identity conflict": "Identity choice", "New Game": "Create a Game"}
		var screen_heading := row(masthead)
		var screen_title := label(titles.get(screen, screen), 30)
		screen_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		screen_heading.add_child(screen_title)
		if not global_game_header:
			_developer_button(screen_heading)
	var scroll := ScrollContainer.new()
	scroll.name = "GameContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Market's multi-step purchase flow controls its own scroll resets. Focus-follow
	# can otherwise reopen a rebuilt step at the old action's vertical position.
	scroll.follow_focus = page != "Market"
	shell.add_child(scroll)
	body = stack(scroll, 4 if compact_landscape else 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if screen == "Game" and page == "Market":
		# The Buy Inventory workflow owns its content scroll area and footer.
		# Let the Market page fill the remaining viewport so only the workflow's
		# middle content scrolls while its Back/Continue controls stay visible.
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(navigation_panel):
		navigation_slot = Control.new()
		navigation_slot.name = "PrimaryNavigationSlot"
		navigation_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		navigation_slot.clip_contents = true
		body.add_child(navigation_slot)
		body.move_child(navigation_slot, 0)
		navigation_slot.add_child(navigation_panel)
		navigation_panel.position = Vector2.ZERO
		navigation_panel.size = navigation_panel.get_combined_minimum_size()
		navigation_panel.visible = false
	var right_space := Control.new()
	right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(right_space)
	if screen == "Game":
		secondary_navigation(body)
	divider(body)
	page_wide = stack(body, 6 if compact_landscape else 12)
	page_wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if screen == "Game" and page == "Market":
		page_wide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_grid = GridContainer.new()
	page_grid.columns = 2 if size.x >= 768.0 else 1
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
			"Developer Mode", "Developer Cheats": developer_console_visible = true
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
	if developer_mode_unlocked and developer_console_visible:
		_show_developer_console_overlay()
	if screen != "Game":
		if restore_access_dialog: _show_developer_access_dialog()
		return
	match page:
		"Dashboard": dashboard()
		"Market": Market.show(self)
		"My Products": Products.show(self)
		"Orders": Operations.show(self)
		"Pre-orders": Operations.preorders(self)
		"Business": business()
		"Finance": finance()
		"Finance Statements": finance_statements()
		"Expense Management": expense_management()
		"Profile": profile_page()
		"Advertising": AdsView.overview(self)
		"Campaign Manager": AdsView.manager(self)
		"Campaign Details": AdsView.details(self)
		"Advertising Analytics": AdsView.analytics(self)
		"Management": StoresView.management(self)
		"Store Profitability": StoresView.profitability(self)
		"Store Listings": StoresView.listings(self)
		"Inbound Stock": Market.inbound_stock(self)
		"Supplier Relationships": Market.supplier_relationships(self)
		"Supplier Returns": Market.supplier_returns_page(self)
	_finish_responsive_content()
	if developer_mode_unlocked and developer_console_visible:
		_show_developer_console_overlay()
	if restore_access_dialog: _show_developer_access_dialog()

func _developer_button(parent: Node) -> Button:
	var button := action(parent, "</>", request_developer_mode_access, false)
	button.name = "DeveloperModeButton"
	button.custom_minimum_size = Vector2(42, 38)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", 12)
	if developer_mode_unlocked: Style.primary(button)
	else: Style.secondary(button)
	button.tooltip_text = "Developer Mode unlocked for this active game" if developer_mode_unlocked else "Developer tools for the active game"
	return button

func _show_developer_console_overlay() -> void:
	if not developer_mode_unlocked or not developer_console_visible or sim == null: return
	_developer_sync_landscape_scale()
	if is_instance_valid(developer_overlay): developer_overlay.queue_free()
	var overlay := ColorRect.new()
	overlay.name = "DeveloperConsoleOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_margin := MarginContainer.new()
	viewport_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		viewport_margin.add_theme_constant_override("margin_" + side, 12)
	overlay.add_child(viewport_margin)
	var scroll := ScrollContainer.new()
	scroll.name = "DeveloperConsoleScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.mouse_force_pass_scroll_events = true
	scroll.scroll_deadzone = 12
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "DeveloperConsolePanel"
	panel.custom_minimum_size.x = minf(920.0, maxf(300.0, size.x - 24.0))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.GOLD, 12, 12))
	center.add_child(panel)
	var mobile_console := size.x < 600.0 or (size.x > size.y and size.y < 600.0)
	var content := stack(panel, 6 if mobile_console else 8)
	content.name = "DeveloperConsoleContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var heading: BoxContainer
	var title := label("Developer Mode", 18 if mobile_console else 22, Style.GOLD)
	title.name = "DeveloperConsoleTitle"
	if mobile_console: title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mobile_console:
		content.add_child(title)
		heading = row(content)
	else:
		heading = row(content)
		heading.add_child(title)
	var close_button := action(heading, "Close", close_developer_console)
	close_button.name = "DeveloperConsoleClose"
	close_button.custom_minimum_size.x = 74
	var lock_button := action(heading, "Lock", leave_developer_mode)
	lock_button.name = "DeveloperConsoleLock"
	lock_button.custom_minimum_size.x = 74
	if mobile_console:
		heading.alignment = BoxContainer.ALIGNMENT_END
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		lock_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	content.add_child(label("Active player session · %s · %s · Day %d · %s" % [
		str(sim.state.get("owner", "Entrepreneur")), str(sim.state.get("company", "Company")),
		int(sim.state.get("day", 1)), money(int(sim.state.get("cash", 0)))], 13, Style.MUTED))
	var latest_save := Slots.latest_for_game(active_game_id)
	var slot_label := Slots.name_for(int(latest_save.get("slot", Slots.AUTOSAVE))) if not latest_save.is_empty() else "No saved slot yet"
	content.add_child(label("Game save: %s" % slot_label, 12, Style.MUTED))
	content.add_child(label("URTN is a public convenience code, not owner authentication. Changes affect only this browser’s active local game. Save explicitly to keep developer changes.", 13, Style.MUTED))
	if developer_changes_active:
		content.add_child(label("Developer changes are in memory and not saved yet.", 14, Style.GOLD))
	var primary_tabs := HFlowContainer.new()
	primary_tabs.name = "DeveloperPrimaryTabs"
	primary_tabs.add_theme_constant_override("h_separation", 5)
	primary_tabs.add_theme_constant_override("v_separation", 5)
	content.add_child(primary_tabs)
	for tab in ["Preview Device", "Cheats"]:
		var tab_button := action(primary_tabs, tab, func():
			developer_console_tab = tab
			_refresh_developer_console_overlay()
		, (developer_console_tab == tab or (tab == "Cheats" and developer_console_tab not in ["Preview Device"])))
		tab_button.custom_minimum_size = Vector2(140, 42)
	if developer_console_tab == "Preview Device":
		var preview := _create_card(content, "Preview Device")
		preview.name = "DeveloperPreviewDevicePanel"
		preview.add_child(label("Resize the game view without changing the active company or its simulation.", 13, Style.MUTED))
		var presets := HFlowContainer.new()
		presets.add_theme_constant_override("h_separation", 6)
		presets.add_theme_constant_override("v_separation", 6)
		preview.add_child(presets)
		for device in ["desktop", "tablet", "mobile"]:
			var caption: String = {"desktop": "Desktop · 900 × 1200", "tablet": "Tablet · 768 × 1024", "mobile": "Mobile · 390 × 844"}[device]
			var preset_button := action(presets, caption, func():
				var result := set_developer_preview(device)
				set_notice(str(result.get("message", "")), not result.get("ok", false))
				developer_console_visible = false
				render()
			, true)
			preset_button.custom_minimum_size = Vector2(200, 44)
		action(preview, "Restore Original Viewport", func():
			var result := set_developer_preview("exit")
			set_notice(str(result.get("message", "")), not result.get("ok", false))
			_refresh_developer_console_overlay()
		)
	else:
		var backup := _create_card(content, "Save Protection")
		backup.add_child(label("Create a timestamped local backup of the active company, CEO profile, and existing save slots before applying test changes.", 13, Style.MUTED))
		action(backup, "Create Backup of Current Save", func():
			confirm_action("Back up current game?", "A new local backup will be created without overwriting any existing save or backup.", "Create Backup", func():
				var result := create_developer_backup()
				set_notice(str(result.get("message", "")) + (" " + str(result.get("path", "")) if result.get("ok", false) else ""), not result.get("ok", false))
				render()
			)
		, true)
		action(backup, "Open Save Game", func():
			developer_console_visible = false
			show_screen("Save")
		)
		var categories := HFlowContainer.new()
		categories.name = "DeveloperCheatTabs"
		categories.add_theme_constant_override("h_separation", 4)
		categories.add_theme_constant_override("v_separation", 4)
		content.add_child(categories)
		for tab in ["Finance", "Inventory", "Sales & Orders", "Marketing", "Company", "Time", "Scenarios"]:
			var selected_tab: String = str(tab)
			var category_button := action(categories, tab, func():
				developer_cheat_category = selected_tab
				_refresh_developer_console_overlay()
			, developer_cheat_category == tab)
			category_button.custom_minimum_size = Vector2(108 if tab != "Sales & Orders" else 142, 42)
		var tools := VBoxContainer.new()
		tools.name = "DeveloperActiveToolCategory"
		tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(tools)
		match developer_cheat_category:
			"Finance": _dev_finance_controls(tools)
			"Inventory": _dev_inventory_controls(tools)
			"Sales & Orders": _dev_order_controls(tools)
			"Marketing": _dev_marketing_controls(tools)
			"Company": _dev_company_controls(tools)
			"Time": _dev_time_controls(tools)
			"Scenarios": _dev_scenario_controls(tools)
	var bottom_padding := Control.new()
	bottom_padding.name = "DeveloperConsoleBottomPadding"
	bottom_padding.custom_minimum_size.y = 12 if mobile_console else 16
	bottom_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_padding)
	_set_developer_scroll_passthrough(center)
	for tool_button in overlay.find_children("*", "Button", true, false):
		(tool_button as Button).custom_minimum_size.y = 42 if mobile_console else 44
	developer_overlay = overlay
	add_child(overlay)

func _refresh_developer_console_overlay() -> void:
	if is_instance_valid(developer_overlay):
		developer_overlay.queue_free()
		developer_overlay = null
	_show_developer_console_overlay()

func _confirm_developer_command(title: String, description: String, command: String, args: Dictionary = {}) -> void:
	confirm_action(title, description, "Apply to Active Game", func(): _run_dev_command(command, args))

func _run_dev_command(command: String, args: Dictionary = {}) -> Dictionary:
	if has_form_edits():
		var blocked := {"ok": false, "code": "unsaved_form", "message": "Save or cancel the open form before applying a developer change."}
		set_notice(str(blocked.message), true)
		return blocked
	var result := dev_api.execute(command, args, self)
	if not result.get("ok", false): set_notice(str(result.get("message", "Developer action failed.")), true)
	else: set_notice(str(result.get("message", "")))
	render()
	return result

func _dev_product_selector(parent: Node, selected: int = 0) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = "DevProductSelector"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in Catalog.PRODUCTS.size(): picker.add_item(str(Catalog.PRODUCTS[index].name), index)
	picker.select(clampi(selected, 0, Catalog.PRODUCTS.size() - 1))
	parent.add_child(picker)
	return picker

func _dev_number(parent: Node, node_name: String, minimum: float, maximum: float, value: float, step_value: float) -> SpinBox:
	var input := SpinBox.new()
	input.name = node_name
	input.min_value = minimum; input.max_value = maximum; input.value = value; input.step = step_value
	input.custom_minimum_size.y = TOUCH_HEIGHT
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(input)
	return input

func _dev_panel(parent: Node, title: String) -> VBoxContainer:
	return _create_card(parent, title)

func _dev_finance_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Finance Cheats")
	panel.add_child(label("Balance changes are recorded as developer adjustments, not sales or profit.", 13, Style.MUTED))
	var cash := _dev_number(panel, "DevCashAmount", -1000000000.0, 1000000000.0, float(sim.state.cash) / 100.0, 0.01)
	action(panel, "Set Bank Balance", func(): _confirm_developer_command("Set bank balance?", "This changes the active company cash balance. The change remains unsaved until you save the game.", "set_cash", {"amount": roundi(cash.value * 100.0)}), true)
	var add := _dev_number(panel, "DevAddMoneyAmount", 0.01, 1000000000.0, 1000.0, 0.01)
	action(panel, "Add Money", func(): _confirm_developer_command("Add money?", "This changes the active company cash balance. The change remains unsaved until you save the game.", "add_money", {"amount": roundi(add.value * 100.0)}), true)

func _dev_inventory_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Inventory Cheats")
	var product := _dev_product_selector(panel)
	var quantity := _dev_number(panel, "DevInventoryQuantity", 1, 100000, 10, 1)
	var selected := func(): return product.get_selected_id()
	action(panel, "Add Stock", func(): _confirm_developer_command("Add inventory?", "This adds stock to the active company. Save explicitly to keep the change.", "add_inventory", {"product": selected.call(), "quantity": int(quantity.value)}), true)
	action(panel, "Empty Stock", func(): _confirm_developer_command("Empty stock?", "All warehouse lots of the selected product will be removed from the active company.", "empty_stock", {"product": selected.call()}))

func _dev_order_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Sales & Orders Cheats")
	var product := _dev_product_selector(panel)
	var selected := func(): return product.get_selected_id()
	action(panel, "Generate 10 Test Orders", func(): _confirm_developer_command("Generate test orders?", "Ten test orders will be created through the normal fulfillment path in this active company.", "generate_orders", {"count": 10, "product": selected.call()}), true)
	action(panel, "Generate 100 Test Orders", func(): _confirm_developer_command("Generate test orders?", "One hundred test orders will be created through the normal fulfillment path in this active company.", "generate_orders", {"count": 100, "product": selected.call()}), true)

func _dev_marketing_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Marketing Cheats")
	var scenarios := ["High ROAS", "Low ROAS", "Budget Exhausted", "Zero Conversions"]
	var picker := dropdown(panel, scenarios, 0)
	var product := _dev_product_selector(panel)
	action(panel, "Create Marketing Scenario", func(): _confirm_developer_command("Create campaign scenario?", "A campaign will be added to the active company using its existing store and product listing.", "apply_marketing_scenario", {"scenario": scenarios[picker.selected], "product": product.get_selected_id()}), true)
	panel.add_child(label("Campaign delivery, spending, conversions, and attribution are generated by the normal advertising simulation when days advance.", 13, Style.MUTED))
	action(panel, "Simulate 7 Days", func():
		confirm_action("Simulate campaign performance?", "Advance the active company from Day %d to Day %d and process its active campaigns and business events?" % [sim.state.day, int(sim.state.day) + 7], "Advance 7 Days", func(): _run_dev_command("advance_days", {"days": 7}))
	, true)

func _dev_company_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Company Cheats")
	var reputation := _dev_number(panel, "DevReputation", 0, 100, sim.state.reputation, 1)
	action(panel, "Max Reputation", func(): _confirm_developer_command("Change company reputation?", "The active company reputation will be set to 100.", "set_reputation", {"value": 100}), true)
	action(panel, "Set Reputation", func(): _confirm_developer_command("Change company reputation?", "The active company reputation will be changed.", "set_reputation", {"value": int(reputation.value)}))
	action(panel, "Unlock Expansion", func(): _confirm_developer_command("Unlock expansion?", "This applies the existing developer expansion flag to the active company.", "unlock_expansion", {}), true)
	panel.add_child(label("This applies the existing expansion unlock flag to the active company.", 13, Style.MUTED))

func _dev_time_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Time Cheats")
	panel.add_child(label("Large advances process the real simulation engine, including supplier deliveries, settlements, campaigns, operating costs, and orders.", 13, Style.MUTED))
	for days in [7, 30, 365]:
		action(panel, "Advance %d Days" % days, func():
			confirm_action("Advance active simulation?", "Advance from Day %d to Day %d? Simulation events will be processed in the current company." % [sim.state.day, int(sim.state.day) + days], "Advance %d Days" % days, func(): _run_dev_command("advance_days", {"days": days}))
		, days == 7)

func _dev_scenario_controls(parent: Node = null) -> void:
	var target: Node = parent if parent != null else body
	var panel := _dev_panel(target, "Scenarios")
	var scenarios := ["Normal Business", "Financial Crisis", "Rapid Growth", "Stock Shortage"]
	var picker := dropdown(panel, scenarios, 0)
	action(panel, "Apply Scenario", func(): _confirm_developer_command("Apply scenario?", "The selected scenario will modify only the active company. The simulation is not reset.", "reset_scenario", {"scenario": scenarios[picker.selected]}), true)

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
	var totals := sim.report_completed(maxi(1, sim.state.day - 1))
	var overview := wide_card(sim.state.company)
	overview.add_child(label(sim.state.owner + ", CEO", 16, Style.MUTED))
	var balance_card := PanelContainer.new()
	balance_card.name = "DashboardBankBalanceCard"
	balance_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_card.custom_minimum_size.y = 78
	balance_card.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.GOLD, 10, 10))
	var balance_stack := VBoxContainer.new()
	balance_stack.add_theme_constant_override("separation", 2)
	balance_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_card.add_child(balance_stack)
	var balance_title := label("Bank Balance", 13, Style.GOLD)
	balance_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_stack.add_child(balance_title)
	bank_balance_label = label(money(int(sim.state.get("cash", 0))), 22, Style.GOLD)
	bank_balance_label.name = "DashboardBankBalanceValue"
	bank_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bank_balance_label.clip_text = false
	bank_balance_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	balance_stack.add_child(bank_balance_label)
	overview.add_child(balance_card)
	_refresh_bank_balance()
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
	_add_kpi(kpis, "Lifetime Net Sales", money(totals.sales - totals.refunds))
	_add_kpi(kpis, "Lifetime Net Profit", money(Sim.net(totals)), profit_color(Sim.net(totals)))
	_add_kpi(kpis, "Orders Fulfilled", str(totals.channels[0].orders + totals.channels[1].orders + totals.channels[2].orders))
	_add_kpi(kpis, "Open Orders", str(sim.state.active_orders.size()))
	_add_kpi(kpis, "Store Reputation", "%d / 100" % sim.state.reputation)
	_add_kpi(kpis, "Marketplace / Website", "%d / %d" % [active_marketplaces, active_websites])
	_add_kpi(kpis, "Active Campaigns", str(active_campaigns))
	var ad_spend := _add_kpi(kpis, "Ad Spend", money(int(totals.advertising)))
	ad_spend.tooltip_text = "Lifetime advertising spend from completed simulation days."
	page_wide.add_child(InventoryOverview.build(sim, size.x < 600.0, self))
	var channel_grid := GridContainer.new()
	channel_grid.name = "DashboardShortcuts"
	channel_grid.columns = 3 if size.x >= 900.0 else (2 if size.x >= 600.0 else 1)
	channel_grid.add_theme_constant_override("h_separation", 12)
	channel_grid.add_theme_constant_override("v_separation", 12)
	page_wide.add_child(channel_grid)
	var store_card := _create_card(channel_grid, "Store Management")
	store_card.name = "DashboardStoreManagement"
	(store_card.get_parent() as Control).name = "DashboardStoreManagement"
	store_card.add_child(label("Create and manage your stores.", 14, Style.MUTED))
	var store_button := action(store_card, "Manage Stores", navigate.bind("Management"), true)
	store_button.icon = load(NAV_ICON_PATHS.Business) as Texture2D
	store_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var listing_card := _create_card(channel_grid, "Listing Products")
	listing_card.name = "DashboardListingProducts"
	(listing_card.get_parent() as Control).name = "DashboardListingProducts"
	listing_card.add_child(label("Manage your published and unpublished product listings.", 14, Style.MUTED))
	var listing_button := action(listing_card, "My Products", navigate.bind("My Products"))
	listing_button.icon = load(NAV_ICON_PATHS.Market) as Texture2D
	listing_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sourcing_card := _create_card(channel_grid, "Product Sourcing")
	sourcing_card.name = "DashboardProductSourcing"
	(sourcing_card.get_parent() as Control).name = "DashboardProductSourcing"
	sourcing_card.add_child(label("Discover products, compare suppliers and purchase inventory.", 14, Style.MUTED))
	var sourcing_button := action(sourcing_card, "Browse Product Catalogue", navigate.bind("Product Catalogue"))
	sourcing_button.icon = load(NAV_ICON_PATHS.Market) as Texture2D
	sourcing_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	channel_cards(totals, "Completed days · lifetime")

func _add_kpi(parent: GridContainer, caption: String, value: String, color: Color = Style.TEXT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 9, 10))
	panel.custom_minimum_size.x = 105
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := stack(panel, 3)
	content.add_child(label(caption, 12, Style.MUTED))
	content.add_child(label(value, 16, color))
	return panel

func advance(days: int) -> void:
	if sim == null or days not in [1, 2, 7, 30]:
		day_advance_processing = false
		return
	sim.advance(days)
	report_end = 0
	var result := sim.report(days, sim.state.day - 1)
	var orders: int = result.channels[0].orders + result.channels[1].orders
	var placed: int = result.channels[0].placed + result.channels[1].placed
	persist("Advanced %d %s · %d placed · %d delivered" % [days, "day" if days == 1 else "days", placed, orders])
	day_advance_processing = false
	render()

func channel_cards(report: Dictionary, scope: String) -> void:
	var channels := card("Sales by Channel")
	channels.add_child(label(scope, 12, Style.MUTED))
	var summaries := GridContainer.new()
	summaries.name = "SalesChannelSummaryGrid"
	summaries.columns = 2 if size.x >= 600.0 else 1
	summaries.add_theme_constant_override("h_separation", 12)
	summaries.add_theme_constant_override("v_separation", 8)
	channels.add_child(summaries)
	for channel in 2:
		var totals: Dictionary = report.channels[channel]
		var title := "Marketplace" if channel == 0 else "Website"
		var summary: PanelContainer = PanelContainer.new()
		summary.name = "SalesChannel%d" % channel
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 9, 10))
		summaries.add_child(summary)
		var content := stack(summary, 5)
		var heading := row(content)
		var icon_path: String = NAV_ICON_PATHS.Market if channel == 0 else NAV_ICON_PATHS.Business
		var channel_icon := TextureRect.new()
		channel_icon.texture = load(icon_path) as Texture2D
		channel_icon.custom_minimum_size = Vector2(18, 18)
		channel_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		channel_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading.add_child(channel_icon)
		var channel_name := label(title, 16, Style.GOLD)
		channel_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(channel_name)
		metric(content, "Orders", str(int(totals.orders)))
		metric(content, "Net Sales", money(int(totals.sales) - int(totals.refunds)))
		var contribution: int = int(totals.sales) - int(totals.refunds) - int(totals.cogs) - int(totals.fees) - int(totals.hosting) - int(totals.shipping)
		metric(content, "After Channel Costs", money(contribution), profit_color(contribution))
	if report.channels.size() > 2 and (report.channels[2].orders > 0 or report.channels[2].sales != 0):
		metric(channels, "Historical Combined-Channel Sales", money(int(report.channels[2].sales)))
	if int(report.get("legacy", 0)) != 0:
		channels.add_child(label("Historical prototype costs remain in the Income Statement without a channel breakdown.", 12, Style.MUTED))

func open_product(product: int) -> void:
	discard_form_then(func():
		selected_product = product
		show_product_editor()
	)

func show_product_editor() -> void:
	page = "Market"
	set_notice("")
	render()

func refresh_view(reset_scroll: bool = false) -> void:
	var previous: int = 0 if reset_scroll else body.get_parent().scroll_vertical
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
	var profile := card("Company Details")
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
	var anchor: int = report_end if report_end > 0 else maxi(1, sim.state.day - 1)
	var boundaries := Calendar.bounds(period, anchor)
	var report := FinanceManagement.completed_period_report(sim, period, anchor)
	financial_dashboard(report)
	var controls := card("Reporting Period")
	var selection := dropdown(controls, Calendar.PERIODS, period)
	selection.item_selected.connect(func(index: int): period = index; render())
	controls.add_child(label("Completed days · %s" % report_range_label(report), 13, Style.MUTED))
	var dates := row(controls)
	var older := action(dates, "Previous", change_report_end.bind(boundaries.x - 1))
	older.disabled = report.end <= 1
	var newer := action(dates, "Next", change_report_end.bind(boundaries.y + 1))
	newer.disabled = report.end >= sim.state.day - 1
	action(controls, "View Statements", func(): navigate("Finance Statements"))
	channel_cards(report, Calendar.format_range(report.start, report.end))

func finance_statements() -> void:
	var controls := card("Statements")
	var selector := dropdown(controls, STATEMENTS, statement)
	selector.item_selected.connect(func(index: int): statement = index; render())
	var anchor: int = report_end if report_end > 0 else maxi(1, sim.state.day - 1)
	var boundaries := Calendar.bounds(period, anchor)
	var report := FinanceManagement.completed_period_report(sim, period, anchor)
	var selection := dropdown(controls, Calendar.PERIODS, period)
	selection.item_selected.connect(func(index: int): period = index; render())
	controls.add_child(label("Completed days · %s" % report_range_label(report), 13, Style.MUTED))
	var dates := row(controls)
	var previous := action(dates, "Previous", change_report_end.bind(boundaries.x - 1))
	previous.disabled = report.end <= 1
	var next := action(dates, "Next", change_report_end.bind(boundaries.y + 1))
	next.disabled = report.end >= sim.state.day - 1
	match statement:
		0: income_statement(report)
		1: balance_sheet(report)
		2: cash_flow(report)

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
		["Overhead", money(summary.overhead)], ["Supplier Payables", money(summary.payables)],
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
	var forecast := card("Cash Forecast")
	metric(forecast, "Known next-day fixed costs", money(-int(summary.overhead)))
	metric(forecast, "Cash after known fixed costs", money(int(summary.cash_after_known_fixed_costs)), profit_color(int(summary.cash_after_known_fixed_costs)))
	forecast.add_child(label("Informational estimate only; it excludes future sales, variable expenses, advertising, new supplier orders, and unsettled receipts. Forecast cash is not available cash.", 13, Style.MUTED))
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
	var anchor: int = report_end if report_end > 0 else maxi(1, sim.state.day - 1)
	var boundaries := Calendar.bounds(period, anchor)
	var report := FinanceManagement.completed_period_report(sim, period, anchor)
	var scope := report_range_label(report)
	controls.add_child(label(scope, 15, Style.GOLD))
	var dates := row(controls)
	var older := action(dates, "Previous", change_report_end.bind(boundaries.x - 1))
	older.disabled = boundaries.x <= 1
	var newer := action(dates, "Next", change_report_end.bind(boundaries.y + 1))
	newer.disabled = report.end >= sim.state.day - 1
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
	var history := card("Transactions")
	var transactions := FinanceManagement.transaction_rows(sim.state, report.start, report.end)
	if transactions.is_empty():
		history.add_child(empty_state("No Transactions", "No completed-day activity is available for this period."))
	for entry in transactions:
		var day := int(entry.day)
		var day_card := PanelContainer.new()
		day_card.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 8, 10))
		var day_content := VBoxContainer.new()
		var summary := row(day_content)
		var day_label := label(Calendar.format(day), 14, Style.GOLD)
		day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_child(day_label)
		var expanded := bool(transaction_details_expanded.get(day, false))
		var detail_button := action(summary, "Hide Details" if expanded else "Details", func():
			transaction_details_expanded[day] = not bool(transaction_details_expanded.get(day, false))
			render()
		)
		detail_button.custom_minimum_size = Vector2(78, 40)
		for group in ["incoming", "outgoing", "other"]:
			var records: Array = entry.get(group, [])
			var amount := _transaction_group_total(records)
			var caption := "Money In" if group == "incoming" else "Money Out" if group == "outgoing" else "Other"
			metric(day_content, caption, money(amount), Style.GREEN if group == "incoming" and amount > 0 else Style.RED if amount < 0 else Style.TEXT)
		if expanded:
			for group in ["incoming", "outgoing", "other"]:
				var heading := "Money In" if group == "incoming" else "Money Out" if group == "outgoing" else "Other"
				for transaction in entry.get(group, []):
					metric(day_content, "%s · %s" % [heading, str(transaction.label)], money(int(transaction.amount)), profit_color(int(transaction.amount)))
		day_card.add_child(day_content)
		history.add_child(day_card)

func _transaction_group_total(records: Array) -> int:
	var total := 0
	for record in records:
		if record is Dictionary:
			total += int(record.get("amount", 0))
	return total

func change_report_end(day: int) -> void:
	report_end = day
	render()

func report_range_label(report: Dictionary) -> String:
	if int(report.get("end", 0)) < 1:
		return "No completed days"
	return Calendar.format_range(int(report.get("start", 0)), int(report.get("end", 0)))

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
	view.add_child(label("As of %s" % Calendar.format(report.end) if int(report.end) > 0 else "No completed-day balance yet", 14, Style.MUTED))
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
