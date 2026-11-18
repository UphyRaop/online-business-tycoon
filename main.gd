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
const NAV := ["Dashboard", "Market", "Orders", "Business", "Finance", "Growth"]
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
var period := 0
var statement := 0
var report_end := 0
var orders_tab := 0
var order_filter := 0
var order_page := 0
var analytics_window := 1
var campaign_id := 0
var selected_store_id := 0
var ad_period := 0
var ad_period_end := 0
var ad_platform_filter := -1
var ad_store_filter := -1
var ad_product_filter := -1
var ad_status_filter := -1
var ads_tab := "Overview"
var stores_tab := "Stores"

func _ready() -> void:
	theme = Style.build()
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
	node.text = title
	node.custom_minimum_size.y = TOUCH_HEIGHT
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(callback)
	if accent:
		Style.primary(node)
	parent.add_child(node)
	return node

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
	var surface := PanelContainer.new()
	if OS.has_feature("web"):
		surface.mouse_filter = Control.MOUSE_FILTER_PASS
	surface.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.LINE, 15, 16))
	body.add_child(surface)
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

func set_notice(message: String, error: bool = false) -> void:
	notice = message
	error_notice = error
	if is_instance_valid(status):
		status.text = notice
		status.visible = not notice.is_empty()
		status.add_theme_color_override("font_color", Style.RED if error else Style.GREEN)

func persist(message: String) -> void:
	write_progress(Slots.AUTOSAVE, message)

func write_progress(slot: int, message: String) -> void:
	var result := Slots.write(slot, sim.state)
	if result != OK:
		dirty = dirty or slot == Slots.AUTOSAVE
		var reason := "Game data failed validation." if result == ERR_INVALID_DATA else error_string(result)
		set_notice("%s save failed. Progress is still in memory. %s" % [Slots.name_for(slot), reason], true)
		return
	dirty = OS.has_feature("web") and not OS.is_userfs_persistent()
	set_notice(message + " Browser storage is unavailable. Progress may be lost on reload." if dirty else message, dirty)

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
	if Slots.occupied(Slots.AUTOSAVE):
		confirm_action("Start a new game?", "Registration will replace the current autosave. Manual slots retain their saved games.", "New Game", func(): show_screen("Setup"))
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

func enter_game(data: Dictionary) -> void:
	sim = Sim.new(data)
	dirty = false
	screen = "Game"
	page = "Dashboard"
	selected_product = 0
	report_end = 0
	order_page = 0
	set_notice("")
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

func navigate(target: String) -> void:
	discard_form_then(func():
		page = target
		set_notice("")
		render()
	)

func render() -> void:
	edit_checks.clear()
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
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var shell := stack(margin, 12)
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
		masthead.add_child(label("%s  /  %s" % [Calendar.format(sim.state.day), Catalog.COUNTRIES[sim.state.country]], 14, Style.MUTED))
	elif screen == "Title":
		Menu.brand(self, masthead)
	else:
		var titles := {"Setup": "Start your business", "Load": "Load Game", "Save": "Save Game", "Settings": "Settings",
			"Campaign Manager": "Campaign Manager", "Campaign Details": "Campaign Details",
			"Advertising Analytics": "Advertising Analytics", "Store Management": "Store Management", "Store Listings": "Store Listings"}
		masthead.add_child(label(titles.get(screen, screen), 30))
	divider(shell)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	shell.add_child(scroll)
	body = stack(scroll, 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = label(notice, 14, Style.RED if error_notice else Style.GREEN)
	status.visible = not notice.is_empty()
	shell.add_child(status)
	if screen != "Game":
		match screen:
			"Title": Menu.title(self)
			"Setup": setup()
			"Entrepreneur name": complete_identity()
			"Load": Menu.slots(self, false)
			"Save": Menu.slots(self, true)
			"Settings": Menu.settings(self)
			"Campaign Manager": AdsView.manager(self)
			"Campaign Details": AdsView.details(self)
			"Advertising Analytics": AdsView.analytics(self)
			"Store Management": StoresView.management(self)
			"Store Listings": StoresView.listings(self)
		return
	divider(shell)
	var nav := row(shell)
	for target in NAV:
		var tab := action(nav, target, navigate.bind(target), target == page)
		tab.add_theme_font_size_override("font_size", 13)
		tab.clip_text = true
		tab.size_flags_stretch_ratio = 1.3 if target == "Dashboard" else 1.0
		for button_state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style: StyleBox = tab.get_theme_stylebox(button_state).duplicate()
			style.content_margin_left = 4
			style.content_margin_right = 4
			tab.add_theme_stylebox_override(button_state, style)
	match page:
		"Dashboard": dashboard()
		"Market": Market.show(self)
		"My Products": Products.show(self)
		"Orders": Operations.show(self)
		"Business": business()
		"Finance": finance()
		"Growth": AdsView.overview(self)
		"Campaign Manager": AdsView.manager(self)
		"Campaign Details": AdsView.details(self)
		"Advertising Analytics": AdsView.analytics(self)
		"Store Management": StoresView.management(self)
		"Store Listings": StoresView.listings(self)

func setup() -> void:
	var details := card("Company registration")
	details.add_child(label("Register your company and entrepreneur profile. Create stores later in Business → Stores.", 15, Style.MUTED))
	var owner := field(details, "Entrepreneur name", "")
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
		var new_state := Sim.register(owner_name, company_name, "",
			country.selected, difficulty.selected, 0, randi())
		enter_game(new_state)
		persist("Company registered.")
	, true)
	action(details, "Back", open_screen.bind("Title"))

func dashboard() -> void:
	var totals := sim.report(sim.state.day)
	var overview := card(sim.state.company)
	overview.add_child(label(sim.state.owner + ", CEO", 16, Style.MUTED))
	overview.add_child(label("CASH BALANCE", 13, Style.MUTED))
	overview.add_child(label(money(sim.state.cash), 32, Style.GOLD))
	divider(overview)
	metric(overview, "Lifetime net sales", money(totals.sales - totals.refunds))
	metric(overview, "Lifetime net profit", money(Sim.net(totals)), profit_color(Sim.net(totals)))
	metric(overview, "Orders fulfilled", str(totals.channels[0].orders + totals.channels[1].orders + totals.channels[2].orders))
	metric(overview, "Open orders", str(sim.state.active_orders.size()))
	metric(overview, "Store reputation", "%d / 100" % sim.state.reputation)
	action(overview, "My Products", navigate.bind("My Products"))
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
	var owner := field(profile, "Entrepreneur / CEO", sim.state.owner)
	var company := field(profile, "Company name", sim.state.company)
	var names_saved := watch_edits([owner, company])
	action(profile, "Save company profile", func():
		var owner_name := owner.text.strip_edges()
		var company_name := company.text.strip_edges()
		if owner_name.is_empty() or company_name.is_empty():
			set_notice("Enter an entrepreneur name and company name.", true)
			return
		sim.state.owner = owner_name
		sim.state.company = company_name
		names_saved.call()
		persist("Company profile saved.")
	)
	action(card("Stores and listings"), "Store Management", navigate.bind("Store Management"), true)
	action(card("Inventory and listings"), "My Products", navigate.bind("My Products"))
	action(card("Growth and expansion"), "Advertising", navigate.bind("Growth"))
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
	metric(view, "Cash", money(maxi(0, report.closing_cash)))
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
