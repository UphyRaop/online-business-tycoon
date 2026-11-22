extends "res://phase1_ui_test.gd"

const CEO = preload("res://ceo_profile.gd")
const Games = preload("res://game_store.gd")
const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Style = preload("res://corporate_theme.gd")

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty():
		push_error("Run Phase 4 navigation checks with a fresh isolated profile.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	app = Main.instantiate()
	root.add_child(app)
	create_new_game_for_test("Kai Founder", "Harbor Works")
	await process_frame
	var dashboard_inventory := app.find_child("DashboardInventoryOverview", true, false) as PanelContainer
	expect(dashboard_inventory != null and dashboard_inventory.is_visible_in_tree()
		and dashboard_inventory.find_child("InventorySummaryMetrics", true, false) != null
		and dashboard_inventory.find_child("PreorderDemandSummary", true, false) != null,
		"Dashboard includes responsive stock, reservation, low/out-of-stock, and pre-order inventory summaries")
	expect(dashboard_inventory.find_child("EmptyProductState", true, false) != null
		and dashboard_inventory.find_child("InventoryBrowseProductCatalogue", true, false) != null
		and dashboard_inventory.find_child("InventoryViewAllProducts", true, false) != null,
		"A company with no products gets the compact empty state plus Browse Product Catalogue and View All Products actions")
	var dashboard_kpis: GridContainer = app.find_child("DashboardKpis", true, false)
	var kpi_names: Array[String] = []
	if dashboard_kpis != null:
		for kpi in dashboard_kpis.get_children():
			var labels := controls(kpi, "Label")
			kpi_names.append(str(labels.front().text) if not labels.is_empty() else "")
	expect(kpi_names == ["Lifetime Net Sales", "Lifetime Net Profit", "Orders Fulfilled", "Open Orders",
		"Store Reputation", "Marketplace / Website", "Active Campaigns", "Ad Spend"]
		and not has_label("Operating Cost") and not has_label("Active campaigns · Lifetime spend"),
		"Dashboard presents exactly the eight approved KPIs, with Active Campaigns and Ad Spend separate")
	var dashboard_shortcuts: GridContainer = app.find_child("DashboardShortcuts", true, false)
	expect(dashboard_shortcuts != null and dashboard_shortcuts.get_children().map(func(item): return str(item.name))
		== ["DashboardStoreManagement", "DashboardListingProducts", "DashboardProductSourcing"],
		"Dashboard shortcuts appear in Store Management, Listing Products, Product Sourcing order")
	expect(app.find_child("CompanyBankBalance", true, false) != null
		and app.find_child("HeaderBankBalanceValue", true, false) != null
		and app.find_child("DashboardBankBalanceCard", true, false) != null,
		"Bank Balance is visible in the global game header and remains on Dashboard")
	press("Manage Stores")
	expect(app.page == "Management", "Manage Stores dashboard shortcut opens Business Store Management")
	app.navigate("Dashboard")
	press("My Products")
	expect(app.page == "My Products", "Listing Products dashboard shortcut opens the existing My Products page")
	app.navigate("Dashboard")
	press("Browse Product Catalogue")
	expect(app.page == "Market", "Product Sourcing dashboard shortcut opens Market Product Catalogue")
	app.navigate("Dashboard")
	var nav: PanelContainer = app.find_child("PrimaryNavigation", true, false)
	var game_date: Label = app.find_child("GameDate", true, false)
	var menu_button: Button = app.find_child("NavigationMenuButton", true, false)
	var bank_balance: Label = app.find_child("DashboardBankBalanceValue", true, false)
	var header_balance: Label = app.find_child("HeaderBankBalanceValue", true, false)
	var advance_controls: HBoxContainer = app.find_child("GlobalAdvanceDayControls", true, false)
	var header_primary: HBoxContainer = app.find_child("GameHeaderPrimaryRow", true, false)
	var header_title: Label = app.find_child("HeaderGameTitle", true, false)
	var header_company: Label = app.find_child("HeaderCompanyName", true, false)
	expect(nav != null and game_date != null and menu_button != null and bank_balance != null and header_balance != null
		and header_primary != null and header_primary.get_child(0) == menu_button
		and game_date.get_parent().name == "GameHeaderSecondaryRow"
		and header_title != null and header_title.text == "ONLINE BUSINESS TYCOON"
		and header_company != null and header_company.text == str(app.sim.state.company)
		and app.find_child("CompanyBankBalance", true, false) != null
		and app.find_child("DeveloperModeButton", true, false) != null
		and menu_button.icon != null and game_date.text.contains(" · ")
		and game_date.text.begins_with("Day 1 · ") and bank_balance.text.contains(app.money(app.sim.state.cash))
		and bank_balance.get_parent().get_parent().name == "DashboardBankBalanceCard",
		"Header keeps company/date, Developer Mode, and live Bank Balance, alongside the Dashboard balance card")
	expect(advance_controls != null
		and controls(advance_controls, "Button").map(func(button): return button.text) == ["+1", "+2", "+7", "+30"],
		"Day 1 date and all four global Advance Day controls appear below the header")
	var advance_one: Button = advance_controls.find_child("AdvanceDays1", true, false)
	advance_one.pressed.emit()
	expect(app.confirmation != null and app.day_advance_pending
		and app.confirmation.dialog_text.contains("Current day: Day 1")
		and app.confirmation.dialog_text.contains("Destination: Day 2")
		and app.confirmation.dialog_text.contains("simulation events"),
		"Advance Day requires a duplicate-safe confirmation showing the destination and simulation warning")
	if app.confirmation != null: app.confirmation.get_cancel_button().pressed.emit()
	expect(not app.day_advance_pending and app.sim.state.day == 1,
		"Cancelling Advance Day leaves the simulation date and state unchanged")
	var page_heading: Control = app.find_child("PageHeading", true, false)
	var page_heading_label := controls(page_heading, "Label").front() as Label if page_heading != null and not controls(page_heading, "Label").is_empty() else null
	expect(page_heading != null and controls(page_heading, "Button").is_empty()
		and page_heading_label != null and page_heading_label.get_theme_font_size("font_size") == Style.FONT_HEADING,
		"Page heading uses the 14 px V4 heading token without duplicating Save Game or Main Menu")
	var primary_dashboard_button := app.find_child("Primary_Dashboard", true, false) as Button
	var compact_action := app.find_child("InventoryBrowseProductCatalogue", true, false) as Button
	expect(primary_dashboard_button != null and primary_dashboard_button.get_theme_font_size("font_size") == Style.FONT_NAVIGATION
		and compact_action != null and compact_action.get_theme_font_size("font_size") == Style.FONT_BUTTON,
		"Primary navigation uses 13 px while game actions use the compact 12 px button token")
	app.apply_text_setting(true)
	await process_frame
	page_heading = app.find_child("PageHeading", true, false)
	page_heading_label = controls(page_heading, "Label").front() as Label if page_heading != null and not controls(page_heading, "Label").is_empty() else null
	primary_dashboard_button = app.find_child("Primary_Dashboard", true, false) as Button
	compact_action = app.find_child("InventoryBrowseProductCatalogue", true, false) as Button
	expect(page_heading_label != null and page_heading_label.get_theme_font_size("font_size") == Style.FONT_HEADING
			and primary_dashboard_button != null and primary_dashboard_button.get_theme_font_size("font_size") == Style.FONT_HEADING
			and compact_action != null and compact_action.get_theme_font_size("font_size") == Style.FONT_HEADING,
			"Large Text increases smaller text but caps headings, navigation and actions at 14 px")
	app.apply_text_setting(false)
	await process_frame
	nav = app.find_child("PrimaryNavigation", true, false)
	game_date = app.find_child("GameDate", true, false)
	menu_button = app.find_child("NavigationMenuButton", true, false)
	bank_balance = app.find_child("DashboardBankBalanceValue", true, false)
	header_balance = app.find_child("HeaderBankBalanceValue", true, false)
	advance_controls = app.find_child("GlobalAdvanceDayControls", true, false)
	header_primary = app.find_child("GameHeaderPrimaryRow", true, false)
	header_title = app.find_child("HeaderGameTitle", true, false)
	header_company = app.find_child("HeaderCompanyName", true, false)
	var content_scroll: ScrollContainer = app.find_child("GameContentScroll", true, false)
	expect(content_scroll != null and not content_scroll.is_ancestor_of(game_date)
		and not content_scroll.is_ancestor_of(header_balance) and content_scroll.is_ancestor_of(bank_balance),
		"Date and header balance stay global while the existing Dashboard balance remains in page content")
	var current_cash: int = app.sim.state.cash
	app.sim.state.cash = current_cash - 12345
	app.set_notice("Balance refresh check")
	bank_balance = app.find_child("DashboardBankBalanceValue", true, false)
	expect(bank_balance.text.contains(app.money(app.sim.state.cash)), "Dashboard balance refreshes immediately after company cash changes")
	app.sim.state.cash = -12345
	app.set_notice("Negative balance check")
	bank_balance = app.find_child("DashboardBankBalanceValue", true, false)
	expect(bank_balance.text.contains(app.money(-12345)) and bank_balance.get_theme_color("font_color") == Style.RED,
		"Dashboard displays negative bank balances with loss coloring")
	app.sim.state.cash = current_cash
	app.set_notice("")
	expect(nav != null and not nav.is_visible_in_tree(), "Primary navigation drawer is hidden by default")
	var nav_slot := app.find_child("PrimaryNavigationSlot", true, false) as Control
	expect(nav_slot != null and nav.get_parent() == nav_slot and is_zero_approx(nav_slot.custom_minimum_size.y),
		"Closed drawer content stays out of the page's measured height")
	var navigation_state_before: Dictionary = app.sim.state.duplicate(true)
	(app.find_child("NavigationMenuButton", true, false) as Button).pressed.emit()
	expect(nav != null and nav.is_visible_in_tree() and nav_slot.custom_minimum_size.y > 0.0,
		"Hamburger opens Main Navigation and expands its in-flow slot")
	await _check_primary_tabs_within_viewport(Vector2i(1280, 720))
	for tab in ["Dashboard", "Market", "Order", "Business", "Marketing", "Finance", "Profile"]:
		var route_name: String = "Order" if tab in ["Order", "Orders"] else tab
		var item: Button = nav.find_child("Primary_" + route_name, true, false) if nav != null else null
		expect(item != null and item.text == ("Orders" if tab == "Order" else tab) and item.icon != null,
			"%s is present with a bundled graphic icon in the navigation drawer" % tab)
	expect(controls(nav, "Button").filter(func(button): return str(button.name).begins_with("Primary_")).size() == 7,
		"Drawer includes all seven primary categories without horizontal primary tabs")
	expect(nav.find_child("DrawerActionSave", true, false) != null and nav.find_child("DrawerActionMainMenu", true, false) != null
		and nav.find_child("DrawerActionSave", true, false).icon != null and nav.find_child("DrawerActionMainMenu", true, false).icon != null,
		"Save Game and Main Menu are distinct icon actions in the drawer")
	var action_label: Label = controls(nav, "Label").filter(func(node): return node.text == "Actions").front()
	expect(action_label != null, "Drawer separates navigation from its action section")
	var close_navigation: Button = nav.find_child("PrimaryNavigationClose", true, false)
	if close_navigation != null: close_navigation.pressed.emit()
	expect(not app.navigation_open and not nav.is_visible_in_tree() and is_zero_approx(nav_slot.custom_minimum_size.y),
		"The in-flow navigation Close button collapses Main Navigation and releases its page height")
	expect(content_scroll != null and content_scroll.is_ancestor_of(nav) and not nav.top_level,
		"Main Navigation participates in the normal scroll layout rather than a viewport overlay")
	(app.find_child("NavigationMenuButton", true, false) as Button).pressed.emit()
	var initial_nav_y := nav.get_global_rect().position.y
	if content_scroll != null:
		content_scroll.scroll_vertical = mini(content_scroll.get_v_scroll_bar().max_value, 120.0)
		await process_frame
	expect(content_scroll != null and nav.get_global_rect().position.y < initial_nav_y,
		"Open Main Navigation scrolls naturally with page content")
	if content_scroll != null: content_scroll.scroll_vertical = 0
	await process_frame
	expect(content_scroll != null and content_scroll.get_script().resource_path == "res://touch_scroll_container.gd",
		"The main page scrolling area uses the reusable touch-scroll container")
	expect(app.sim.state == navigation_state_before,
		"Opening and closing Main Navigation does not modify game state")
	var tab_key := InputEventKey.new()
	tab_key.keycode = KEY_TAB
	tab_key.pressed = true
	app._unhandled_key_input(tab_key)
	var keyboard_focus := app.get_viewport().gui_get_focus_owner()
	expect(keyboard_focus != null and nav.is_ancestor_of(keyboard_focus), "Keyboard focus remains inside the open navigation drawer")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_key_input(escape)
	expect(not app.navigation_open, "Escape closes the drawer on desktop")
	var main_menu_button: Button = nav.find_child("DrawerActionMainMenu", true, false)
	app.dirty = true
	main_menu_button.pressed.emit()
	expect(app.screen == "Game" and app.confirmation != null and app.confirmation.dialog_text.contains("discard"),
		"Main Menu preserves the existing unsaved-progress confirmation")
	if app.confirmation != null: app.confirmation.get_cancel_button().pressed.emit()
	app.dirty = false
	var menu_for_route: Button = app.find_child("NavigationMenuButton", true, false)
	if menu_for_route != null: menu_for_route.pressed.emit()
	var market_route: Button = nav.find_child("Primary_Market", true, false)
	if market_route != null: market_route.pressed.emit()
	await process_frame
	var closed_nav: Control = app.find_child("PrimaryNavigation", true, false)
	expect(app.page == "Market" and not app.navigation_open and closed_nav != null and not closed_nav.is_visible_in_tree()
		and app.sim.state == navigation_state_before,
		"Selecting an existing Main Navigation destination closes the panel without changing simulation state")
	app.navigate("Dashboard")
	await process_frame
	nav = app.find_child("PrimaryNavigation", true, false) as PanelContainer
	var save_button: Button = app.find_child("DrawerActionSave", true, false)
	var save_button_style := save_button.get_theme_stylebox("normal") as StyleBoxFlat if save_button != null else null
	expect(save_button_style != null and save_button_style.bg_color == Style.GOLD,
		"Drawer Save Game action uses the V4 gold primary style")
	save_button.pressed.emit()
	expect(app.screen == "Save", "Drawer Save Game opens the existing save screen")
	press("Back")
	expect(app.screen == "Game", "Returning from the Save Game screen keeps the current company active")

	press("Dashboard")
	expect(app.page == "Dashboard" and has_label("Business Alerts"), "Dashboard category works")
	press("Market")
	var market_scroll := app.body.get_parent() as ScrollContainer
	expect(app.page == "Market" and has_label("Quick Purchase") and market_scroll != null and market_scroll.scroll_vertical == 0,
		"Market category opens Buy Inventory at the top of its Quick Purchase workflow")
	press("My Products")
	expect(app.page == "My Products" and has_label("Product portfolio"), "Market secondary route opens My Products")
	press("Management")
	expect(app.page == "Management" and has_label("Owned stores · 0"), "Store Management is available under Business")
	app.show_new_store_form = true
	app.refresh_view()
	var website_platform_note: Label = controls(app, "Label").filter(func(item):
		return item.text.begins_with("Website platform values are simulated")
	).front()
	var domain_label: Label = controls(app, "Label").filter(func(item):
		return item.text == "Website Domain (Required for Website)"
	).front()
	var domain_field: LineEdit = controls(app, "LineEdit").filter(func(item): return item.max_length == 64).front()
	var store_kinds: Array = controls(app, "OptionButton")
	if not store_kinds.is_empty(): select(store_kinds[0], 0)
	expect(website_platform_note != null and not website_platform_note.visible
		and domain_label != null and not domain_label.visible and domain_field != null and not domain_field.visible,
		"Marketplace registration hides website-only pricing and domain controls")
	if not store_kinds.is_empty(): select(store_kinds[0], 1)
	expect(website_platform_note != null and website_platform_note.visible
		and domain_label.visible and domain_field.visible,
		"Website registration shows its platform-pricing explanation and domain controls")
	app.show_new_store_form = false
	app.refresh_view()

	var marketplace_error := Stores.create(app.sim.state, "Harbor Marketplace", 0, "Harbor", "", 0)
	var marketplace_id := int(app.sim.state.stores.back().id)
	var website_error := Stores.create(app.sim.state, "Harbor Website", 1, "Harbor", "harbor.example.test", 0, 1)
	var website_id := int(app.sim.state.stores.back().id)
	expect(marketplace_error.is_empty() and website_error.is_empty(), "Management retains marketplace and paid website creation")
	app.refresh_view()
	expect(has_label("Harbor Marketplace") and has_label("Harbor Website") and has_label("WooCommerce · harbor.example.test"),
		"Management lists existing marketplace and website details")
	expect(Stores.get_store(app.sim.state, marketplace_id).type == 0 and Stores.get_store(app.sim.state, website_id).type == 1,
		"Management preserves destination types and IDs")
	app.navigate("Store Management")
	expect(app.page == "Management", "Legacy Store Management navigation safely redirects to Management")
	app.selected_store_id = marketplace_id
	app.navigate("Store Listings")
	expect(app.page == "Store Listings" and has_label("Harbor Marketplace · Product listings"),
		"Legacy product-listing route remains callable for compatibility without a secondary navigation tab")
	app.navigate("Management")
	var listing_actions := controls(app, "Button").filter(func(button): return button.text == "Inventory Management")
	expect(listing_actions.size() >= 2 and controls(app, "Button").filter(func(button): return button.text == "Manage Listings").is_empty(),
		"Marketplace and website cards link to Inventory Management without duplicate listing editors (found %d)" % listing_actions.size())
	if listing_actions.size() == 2:
		listing_actions.back().pressed.emit()
		expect(app.page == "My Products" and has_label("Product portfolio"), "Store Management directs product work to My Products")
	app.navigate("Management")
	var deactivate_actions := controls(app, "Button").filter(func(button): return button.text == "Deactivate")
	expect(deactivate_actions.size() == 2, "Management exposes activation controls for both destinations")
	for store_id in [marketplace_id, website_id]:
		app.navigate("Management")
		var store_index := Stores.index_of(app.sim.state, store_id)
		var status_buttons := controls(app, "Button").filter(func(button): return button.text in ["Deactivate", "Activate"])
		if store_index >= 0 and store_index < status_buttons.size() and status_buttons[store_index].text == "Deactivate":
			status_buttons[store_index].pressed.emit()
		expect(not Stores.get_store(app.sim.state, store_id).active, "Management deactivates destination %d" % store_id)
		app.navigate("Management")
		status_buttons = controls(app, "Button").filter(func(button): return button.text in ["Deactivate", "Activate"])
		if store_index >= 0 and store_index < status_buttons.size() and status_buttons[store_index].text == "Activate":
			status_buttons[store_index].pressed.emit()
		expect(Stores.get_store(app.sim.state, store_id).active, "Management reactivates destination %d" % store_id)

	press("Order")
	expect(app.page == "Orders" and has_label("Store Operations"), "Order category opens customer orders")
	press("Pre-orders")
	expect(app.page == "Pre-orders" and has_label("Pre-orders"), "Order secondary route opens pre-order management")
	press("Returns and Service")
	expect(app.page == "Orders" and app.orders_tab == 1, "Returns and Service retains the existing customer-service screen")
	app.orders_tab = 0
	app.navigate("Orders")
	expect(app.page_grid.get_child_count() == 2 and app.page_left_column.get_child_count() + app.page_right_column.get_child_count() == 3
		and app.page_left_column.get_child_count() > 0 and app.page_right_column.get_child_count() > 0,
		"Desktop content uses two populated natural-height columns without an empty grid cell")
	press("Pre-orders")
	expect(app.page_grid.get_child_count() == 0 and app.page_wide.get_child_count() == 1,
		"A single desktop content card expands to the full content width")

	press("Business")
	expect(app.primary_category(app.page) == "Business" and app.page in ["Business", "Management"],
		"Business category opens Company Management or its last visited management screen")
	var company_subtab: Button = controls(app, "Button").filter(func(button): return button.text == "Company Management")[0]
	var dashboard_primary: Button = nav.find_child("Primary_Dashboard", true, false)
	expect(company_subtab.custom_minimum_size.y == 44 and dashboard_primary.custom_minimum_size.y >= 44
		and company_subtab.get_theme_font_size("font_size") < dashboard_primary.get_theme_font_size("font_size"),
		"Secondary navigation is visually smaller than drawer navigation while keeping a 44 px touch target")
	press("Marketing")
	var marketing_overview: Button = controls(app, "Button").filter(func(button): return button.text == "Overview")[0]
	var unselected_subtab: Button = controls(app, "Button").filter(func(button): return button.text == "Ads Manager")[0]
	var selected_tab_style := company_subtab.get_theme_stylebox("normal") as StyleBoxFlat
	var selected_marketing_style := marketing_overview.get_theme_stylebox("normal") as StyleBoxFlat
	var unselected_tab_style := unselected_subtab.get_theme_stylebox("normal") as StyleBoxFlat
	var focus_tab_style := unselected_subtab.get_theme_stylebox("focus") as StyleBoxFlat
	expect(marketing_overview.custom_minimum_size.y == 44 and marketing_overview.flat and selected_marketing_style != null
		and selected_marketing_style.bg_color.a == 0.0 and selected_marketing_style.border_width_bottom == 2
		and selected_marketing_style.border_color == Style.GOLD
		and unselected_subtab.flat and unselected_tab_style != null and unselected_tab_style.bg_color.a == 0.0
		and unselected_tab_style.border_width_bottom == 0 and focus_tab_style != null
		and focus_tab_style.border_color == Style.GOLD and focus_tab_style.border_width_left == 1,
		"Marketing secondary tabs use a gold selected underline, transparent inactive tabs, 44 px touch area, and visible keyboard focus")
	press("Advertising")
	expect(app.page == "Advertising" and has_label("Advertising Overview"), "Marketing Overview opens the advertising overview")
	var ctr_value := app.find_child("CTRValue", true, false) as Label
	var cpm_value := app.find_child("CPMValue", true, false) as Label
	expect(app.find_child("MarketingKPI_CTR_CPM", true, false) != null and ctr_value != null and cpm_value != null
		and ctr_value.text.ends_with("%") and cpm_value.text == app.money(0)
		and ctr_value.autowrap_mode == TextServer.AUTOWRAP_OFF and cpm_value.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"CTR and CPM render as separate single-line values so currency codes cannot split across lines")
	press("Ads Manager")
	expect(app.screen == "Campaign Manager" or app.page == "Campaign Manager", "Ads Manager remains reachable")
	press("Ads Analytics")
	expect(app.screen == "Advertising Analytics" or app.page == "Advertising Analytics", "Ads Analytics remains reachable")

	press("Finance")
	expect(app.page == "Finance" and has_label("Financial Dashboard") and not has_label("Income Statement")
		and has_label("Company Cash") and has_label("Gross Profit") and not has_label("Operating Cash Flow")
		and has_label("Overhead") and not has_label("Receivables") and has_label("Supplier Payables") and has_label("Financial Trends · Last 7 Recorded Days"),
		"Finance opens a compact cash, performance, overhead, and completed-day trend dashboard without stacking statements")
	expect(has_label("Cash Forecast") and has_label("Informational estimate only;"),
		"Finance distinguishes forecast cash from available cash")
	press("Expenses")
	expect(app.page == "Expense Management" and has_label("Expense Breakdown") and has_label("Transactions"),
		"Expenses shows period-based categories and a banking-style transaction history")
	press("Statements")
	var statement_controls := controls(app, "OptionButton")
	if statement_controls.size() >= 1:
		statement_controls[0].select(2)
		statement_controls[0].item_selected.emit(2)
	expect(has_label("Cash Flow Statement") and not has_label("Income Statement") and not has_label("Balance Sheet")
		and not has_label("Operating Cash Flow"),
		"Statements displays only the selected Cash Flow Statement")
	press("Business")
	press("Store Profitability")
	expect(app.page == "Store Profitability" and has_label("Harbor Marketplace") and has_label("Harbor Website"),
		"Business Store Profitability reports marketplace and website results")

	var stored := Slots.write_for_game(app.active_game_id, 1, app.sim.state, app.ceo_profile)
	var loaded := Slots.read_for_game(app.active_game_id, 1)
	expect(stored == OK and Saves.valid(loaded.get("state", {})), "Save/load remains valid with both destination types")
	var loaded_stores: Array = loaded.get("state", {}).get("stores", [])
	expect(loaded_stores.size() == 2 and int(loaded_stores[0].id) == marketplace_id
		and int(loaded_stores[1].id) == website_id and str(loaded_stores[1].domain) == "harbor.example.test",
		"Save/load preserves marketplace and website IDs and website details")
	Slots.delete_for_game(app.active_game_id, 1)
	press("Profile")
	expect(app.page == "Profile" and has_label("CEO Profile") and has_label("Career Progression")
		and has_label("Owned Companies") and has_label("Career Statistics") and not has_label("CEO ID")
		and has_label("Career Start Date") and has_label("Companies Founded") and has_label("Active Companies"),
		"Profile shows compact career information and keeps technical identifiers collapsed by default")
	expect(has_label("Career Title") and has_label("Entrepreneur"),
		"New CEO profile displays a progression title derived from its current level")
	expect(has_label("Current XP") and has_label("XP to Next Level") and has_label("Next Career Title")
		and has_label("Unlocks at Level") and app.find_child("CareerXPProgress", true, false) != null,
		"Profile shows XP progress and the next title threshold")
	expect(not has_label("Stored in this browser only; never uploaded."),
		"Profile no longer shows the browser storage developer message")
	expect(not has_label("Personal Finance") and not has_label("Personal cash and net worth remain untracked."),
		"Profile omits the deferred Personal Finance placeholder while preserving ownership records")
	press("Show CEO Details")
	expect(has_label("CEO ID") and has_label("Game ID") and has_button("Copy CEO ID"),
		"Technical CEO and game identifiers are available only in optional details with a Copy action")
	press("Hide CEO Details")
	expect(not has_label("CEO ID"), "Optional technical profile details can be collapsed again")
	expect(controls(app, "LineEdit").is_empty() and has_button("Edit Profile"),
		"Profile details are read-only until editing is explicitly activated")
	var portrait: TextureRect = app.find_child("CEOAvatar", true, false)
	var portrait_frame := app.find_child("CEOAvatarFrame", true, false) as PanelContainer
	expect(portrait_frame != null and portrait != null and absf(portrait.custom_minimum_size.y / portrait.custom_minimum_size.x - 4.0 / 3.0) < 0.01,
		"CEO portrait preserves the 3:4 frame on desktop")
	var existing_photo := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	existing_photo.fill(Color("#dfb777"))
	CEO.add_avatar(app.ceo_profile, "image/png", existing_photo.save_png_to_buffer())
	Games.update_game_profile(app.active_game_id, app.ceo_profile)
	app.refresh_view()
	expect(not has_button("Change Photo") and not has_button("Remove Photo"),
		"Saved Profile hides photo actions until Edit Profile is selected")
	press("Edit Profile")
	expect(has_button("Change Photo") and has_button("Remove Photo"),
		"Photo replacement and removal actions appear inside Profile edit mode")
	var profile_fields := controls(app, "LineEdit")
	profile_fields[0].text = "Discarded CEO Name"
	profile_fields[0].text_changed.emit(profile_fields[0].text)
	var replacement_photo := Image.create(600, 400, false, Image.FORMAT_RGBA8)
	replacement_photo.fill(Color("#4f87bc"))
	app.open_avatar_crop(replacement_photo)
	await process_frame
	await process_frame
	var desktop_crop_dialog: Control = app.find_child("AvatarCropDialog", true, false)
	var desktop_preview_section: Control = app.find_child("AvatarCropPreviewSection", true, false)
	var crop_centered := desktop_crop_dialog != null and desktop_preview_section != null and absf(
		(desktop_preview_section.get_global_rect().get_center().x - desktop_crop_dialog.get_global_rect().get_center().x)) <= 3.0
	expect(app.find_child("AvatarCropModal", true, false) != null and has_button("Apply Crop")
		and has_button("Reset"),
		"Photo replacement opens a centered crop dialog over the Profile edit screen")
	expect(crop_centered and not app.find_child("AvatarCropPreview", true, false),
		"Desktop crop presents one large live preview centered in the cropping dialog")
	press("Apply Crop")
	await process_frame
	var staged_photo := str(app.ceo_profile.avatar_data)
	expect(staged_photo != "" and staged_photo != CEO.load_game_profile(app.active_game_id).avatar_data,
		"Apply Crop updates the edit preview without persisting before Save Profile")
	press("Cancel")
	expect(app.ceo_profile.full_name == "Kai Founder" and app.ceo_profile.avatar_data == CEO.load_game_profile(app.active_game_id).avatar_data
		and not has_button("Save Changes"), "Cancel restores saved identity and photo after a staged replacement")
	press("Edit Profile")
	profile_fields = controls(app, "LineEdit")
	profile_fields[0].text = "Kai Global CEO"
	profile_fields[0].text_changed.emit(profile_fields[0].text)
	app.open_avatar_crop(replacement_photo)
	await process_frame
	await process_frame
	press("Apply Crop")
	await process_frame
	press("Save Changes")
	expect(app.ceo_profile.full_name == "Kai Global CEO" and app.sim.state.owner == "Kai Global CEO"
		and CEO.load_game_profile(app.active_game_id).full_name == "Kai Global CEO" and CEO.load_game_profile(app.active_game_id).avatar_data == app.ceo_profile.avatar_data,
		"Saving Profile persists edited identity and a replacement photo")
	var retained_photo := str(app.ceo_profile.avatar_data)
	press("Edit Profile")
	press("Remove Photo")
	expect(str(app.ceo_profile.avatar_data).is_empty(), "Remove Photo stages a reversible change while editing")
	press("Cancel")
	expect(str(app.ceo_profile.avatar_data) == retained_photo and CEO.load_game_profile(app.active_game_id).avatar_data == retained_photo,
		"Cancel restores the previously saved CEO photo")
	press("Edit Profile")
	press("Remove Photo")
	press("Save Changes")
	expect(str(app.ceo_profile.avatar_data).is_empty() and CEO.load_game_profile(app.active_game_id).avatar_data.is_empty(),
		"Saving Profile commits photo removal")
	CEO.add_avatar(app.ceo_profile, "image/png", existing_photo.save_png_to_buffer())
	Games.update_game_profile(app.active_game_id, app.ceo_profile)
	var first_company_id := str(app.sim.state.company_id)
	var second_company := Sim.register("Kai Global CEO", "Harbor Digital", "", 1, 1, 0, 9123)
	app.ceo_profile = CEO.register_company(app.ceo_profile, second_company)
	expect(Saves.save(second_company, CEO.company_path_for_game(app.active_game_id, second_company.company_id), 2.0) == OK
		and Games.update_game_profile(app.active_game_id, app.ceo_profile) == OK, "Second company save is linked without changing the current business")
	app.navigate("Profile")
	var switch_buttons := controls(app, "Button").filter(func(button): return button.text == "Switch")
	expect(switch_buttons.size() == 1, "Profile offers company switching for the other owned company")
	if switch_buttons.size() == 1:
		switch_buttons[0].pressed.emit()
		expect(str(app.sim.state.company_id) == str(second_company.company_id)
			and app.sim.state.company == "Harbor Digital" and app.ceo_profile.full_name == "Kai Global CEO",
			"Company switching restores a separate save and keeps CEO progression linked")
		expect(app.find_child("CompanyBankBalance", true, false) != null,
			"Switching companies preserves the global balance display")
		app.navigate("Dashboard")
		var switched_balance: Label = app.find_child("DashboardBankBalanceValue", true, false)
		expect(switched_balance != null and switched_balance.text.contains(app.money(app.sim.state.cash)),
			"Dashboard balance updates to the newly active company's actual cash after switching")
		app.navigate("Profile")
		switch_buttons = controls(app, "Button").filter(func(button): return button.text == "Switch")
		if switch_buttons.size() == 1:
			switch_buttons[0].pressed.emit()
		expect(str(app.sim.state.company_id) == first_company_id and app.sim.state.company == "Harbor Works",
			"Switching back restores the original company and its store history")

	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	app.navigate("Profile")
	var mobile_current_labels := controls(app, "Label").filter(func(node): return node.text == "Current Company")
	var ceo_avatar := app.find_child("CEOAvatar", true, false) as TextureRect
	expect(mobile_current_labels.size() == 1 and mobile_current_labels[0].get_parent() is VBoxContainer,
		"Mobile owned-company rows stack the company name and current status without narrow wrapping")
	var mobile_portrait_frame := app.find_child("CEOAvatarFrame", true, false) as PanelContainer
	expect(mobile_portrait_frame != null and mobile_portrait_frame.custom_minimum_size.x <= 170.0 and ceo_avatar != null and ceo_avatar.custom_minimum_size.x <= 158.0
		and absf(ceo_avatar.custom_minimum_size.y / ceo_avatar.custom_minimum_size.x - 4.0 / 3.0) < 0.01
		and mobile_portrait_frame.get_parent().size_flags_horizontal == Control.SIZE_SHRINK_CENTER,
		"CEO avatar keeps its centered portrait aspect ratio on mobile")
	app.navigate("Finance")
	var secondary_scroll: ScrollContainer = app.find_child("SecondaryNavigationScroll", true, false)
	expect(secondary_scroll != null and secondary_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and secondary_scroll.get_parent() is VBoxContainer and secondary_scroll.get_parent().get_parent() is ScrollContainer,
		"Secondary tabs scroll horizontally inside the page and never remain sticky")
	app.navigate("Profile")
	for target in ["Dashboard", "Market", "Order", "Business", "Marketing", "Finance", "Profile"]:
		press(target)
		expect(app.primary_category(app.page) == target or (target == "Order" and app.primary_category(app.page) == "Order"),
			"Mobile navigation opens %s" % target)
	for viewport in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1024, 768),
		Vector2i(768, 1024), Vector2i(430, 932), Vector2i(390, 844),
		Vector2i(375, 667), Vector2i(360, 800), Vector2i(844, 390), Vector2i(667, 375)]:
		root.size = viewport
		await settle("phase4-%dx%d" % [viewport.x, viewport.y])
		var header_date: Label = app.find_child("GameDate", true, false)
		var global_advance := app.find_child("GlobalAdvanceDayControls", true, false)
		var header_balance_value: Label = app.find_child("HeaderBankBalanceValue", true, false)
		expect(app.find_child("CompanyBankBalance", true, false) != null and header_balance_value != null
			and app.find_child("DeveloperModeButton", true, false) != null and header_date != null and global_advance != null
			and controls(global_advance, "Button").size() == 4 and header_date.text.contains(Catalog.COUNTRIES[app.sim.state.country])
			and header_date.text.contains(" · ") and header_date.text.begins_with("Day %d · " % app.sim.state.day),
			"Header date, Bank Balance, Developer Mode, and global Advance Day remain visible at %dx%d" % [viewport.x, viewport.y])
		await _check_primary_tabs_within_viewport(viewport)
		expect(app.page_grid.columns == (2 if app.size.x >= 768 else 1),
			"Page panels use the intended responsive column count at %dx%d (actual: %d columns at %.1f px / viewport %.1f px)" % [viewport.x, viewport.y, app.page_grid.columns, app.size.x, app.get_viewport_rect().size.x])
		var layout_width: float = app.size.x
		var expected_page_width := minf(1100.0, maxf(280.0, layout_width - (40.0 if layout_width >= 900.0 else 24.0)))
		expect(is_equal_approx(app.page_shell.custom_minimum_size.x, expected_page_width)
			and app.page_grid.get_theme_constant("h_separation", "GridContainer") == Style.CARD_GRID_GAP
			and app.page_grid.get_theme_constant("v_separation", "GridContainer") == Style.CARD_GRID_GAP,
			"Global page width and compact card grid spacing conform at %dx%d" % [viewport.x, viewport.y])
		var metric_rows := controls(app, "BoxContainer").filter(func(control): return str(control.name) == "ResponsiveMetric")
		var compact_metric_rows := true
		for metric_row in metric_rows:
			var metric_box := metric_row as BoxContainer
			if metric_box.vertical or metric_box.get_theme_constant("separation", "BoxContainer") != Style.INFO_ROW_GAP:
				compact_metric_rows = false
		expect(compact_metric_rows,
			"Information cards keep labels and values on compact horizontal rows at %dx%d" % [viewport.x, viewport.y])
		var expected_grid_children: int = 0 if app.size.x >= 768 and app.page_cards.size() == 1 else (2 if app.size.x >= 768 else app.page_cards.size())
		expect(app.page_grid.get_child_count() == expected_grid_children,
			"Card layout reflows without unused columns at %dx%d" % [viewport.x, viewport.y])
		press("Dashboard")
		var kpis: GridContainer = app.find_child("DashboardKpis", true, false)
		expect(kpis != null and kpis.columns == (4 if app.size.x >= 900.0 else 2),
			"Dashboard KPI cards use the intended responsive columns at %dx%d" % [viewport.x, viewport.y])
		var dashboard_balance: Label = app.find_child("DashboardBankBalanceValue", true, false)
		var shortcuts: GridContainer = app.find_child("DashboardShortcuts", true, false)
		expect(dashboard_balance != null and shortcuts != null
			and shortcuts.get_children().map(func(item): return str(item.name)) == ["DashboardStoreManagement", "DashboardListingProducts", "DashboardProductSourcing"],
			"Dashboard places Bank Balance and the three approved shortcuts in their required order at %dx%d" % [viewport.x, viewport.y])
		var overview_panel := app.find_child("DashboardInventoryOverview", true, false) as PanelContainer
		var overview_style := overview_panel.get_theme_stylebox("panel") as StyleBoxFlat if overview_panel != null else null
		expect(overview_style != null and overview_style.content_margin_left == Style.CARD_PADDING
			and overview_style.content_margin_top == Style.CARD_PADDING,
			"Dashboard's dynamic inventory card uses the shared compact padding at %dx%d" % [viewport.x, viewport.y])
		app.navigate("Market")
		await process_frame
		await process_frame
		var market_tabs := app.find_child("SecondaryNavigationScroll", true, false) as ScrollContainer
		var market_workflow := app.find_child("BuyInventoryWorkflow", true, false) as Control
		expect(market_tabs != null and market_tabs.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
			and market_workflow != null and market_tabs.get_global_rect().end.y <= market_workflow.get_global_rect().position.y + Style.PAGE_SECTION_GAP + Style.PAGE_CONTENT_GAP + 1.0,
			"Market tabs remain reachable and sit directly above compact content at %dx%d" % [viewport.x, viewport.y])
		app.navigate("Dashboard")
		if viewport.x == 375:
			var previous_cash: int = app.sim.state.cash
			app.sim.state.cash = 9876543210123
			app.set_notice("Large balance layout check")
			dashboard_balance = app.find_child("DashboardBankBalanceValue", true, false)
			expect(dashboard_balance.text.contains(app.money(app.sim.state.cash)) and not dashboard_balance.clip_text,
				"A 10+ digit mobile bank balance is displayed in full without clipping")
			app.sim.state.cash = previous_cash
			app.set_notice("")
		await _check_primary_tabs_within_viewport(viewport)
		var shell_bounds: Rect2 = app.page_shell.get_global_rect()
		var scale_x: float = float(viewport.x) / app.get_viewport_rect().size.x
		expect(shell_bounds.position.x * scale_x >= 0 and shell_bounds.end.x * scale_x <= float(viewport.x) + 1.0,
			"Centered content shell fits %dx%d" % [viewport.x, viewport.y])
	root.size = Vector2i(390, 844)
	await settle("phase4-mobile-profile")
	app.navigate("Profile")
	press("Edit Profile")
	app.open_avatar_crop(replacement_photo)
	await process_frame
	await process_frame
	var mobile_modal: Control = app.find_child("AvatarCropModal", true, false)
	var mobile_crop: Control = app.find_child("AvatarCropViewport", true, false)
	var mobile_actions: Array = controls(mobile_modal, "Button") if mobile_modal != null else []
	var crop_actions_fit := mobile_actions.filter(func(button): return button.text in ["Cancel", "Reset", "Apply Crop"]).all(
		func(button): return button.get_global_rect().position.y >= 0 and button.get_global_rect().end.y <= root.size.y)
	expect(mobile_modal != null and mobile_crop != null and mobile_crop.custom_minimum_size.x <= 220.0
		and crop_actions_fit, "Mobile crop dialog fits its 3:4 editor and Cancel, Reset, and Apply Crop controls")
	var mobile_avatar: TextureRect = app.find_child("CEOAvatar", true, false)
	expect(mobile_avatar != null and mobile_avatar.custom_minimum_size.x <= 150.0
		and absf(mobile_avatar.custom_minimum_size.y / mobile_avatar.custom_minimum_size.x - 4.0 / 3.0) < 0.01,
		"Mobile Profile keeps a compact 3:4 CEO portrait")
	var modal_cancel: Variant = mobile_actions.filter(func(button): return button.text == "Cancel").back()
	if modal_cancel != null: modal_cancel.pressed.emit()
	press("Cancel")
	root.size = Vector2i(667, 375)
	await settle("phase4-navigation-touch-scroll")
	app.navigate("Dashboard")
	var landscape_menu := app.find_child("NavigationMenuButton", true, false) as Button
	if landscape_menu != null: landscape_menu.pressed.emit()
	await process_frame
	var landscape_scroll := app.find_child("GameContentScroll", true, false) as ScrollContainer
	var landscape_drawer := app.find_child("PrimaryNavigation", true, false) as Control
	var landscape_bar := landscape_scroll.get_v_scroll_bar() if landscape_scroll != null else null
	expect(landscape_scroll != null and landscape_bar != null and landscape_bar.max_value > landscape_bar.page + 0.5
		and landscape_drawer != null, "Small-landscape navigation has a touch-scrollable in-flow drawer")
	if landscape_scroll != null and landscape_drawer != null and landscape_bar != null and landscape_bar.max_value > landscape_bar.page + 0.5:
		var drawer_rect := landscape_drawer.get_global_rect()
		var swipe_start := Vector2(drawer_rect.position.x + drawer_rect.size.x * 0.55,
			minf(drawer_rect.end.y - 20.0, float(root.size.y) - 28.0))
		var swipe_down := InputEventScreenTouch.new()
		swipe_down.index = 29
		swipe_down.position = swipe_start
		swipe_down.pressed = true
		root.push_input(swipe_down)
		await process_frame
		var swipe_drag := InputEventScreenDrag.new()
		swipe_drag.index = 29
		swipe_drag.position = swipe_start + Vector2(0, -110)
		swipe_drag.relative = Vector2(0, -110)
		root.push_input(swipe_drag)
		await process_frame
		expect(landscape_scroll.scroll_vertical > 0,
			"Touch swipe inside the drawer reveals lower navigation actions at 667×375")
		var swipe_up := InputEventScreenTouch.new()
		swipe_up.index = 29
		swipe_up.position = swipe_drag.position
		swipe_up.pressed = false
		root.push_input(swipe_up)
		app.close_navigation_drawer(false)
	root.size = Vector2i(390, 844)
	await settle("phase4-navigation-touch-scroll-restored")
	print("Phase 4 navigation and Management UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_primary_tabs_within_viewport(viewport: Vector2i) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	var nav: Control = app.find_child("PrimaryNavigation", true, false)
	if nav == null:
		expect(false, "Navigation drawer remains reachable at %dx%d" % [viewport.x, viewport.y])
		return
	var opened_here := not nav.is_visible_in_tree()
	if opened_here:
		var menu_button: Button = app.find_child("NavigationMenuButton", true, false)
		if menu_button != null: menu_button.pressed.emit()
	expect(nav.is_visible_in_tree(), "Navigation drawer opens at %dx%d" % [viewport.x, viewport.y])
	var page_scroller: ScrollContainer = app.find_child("GameContentScroll", true, false)
	expect(page_scroller != null and page_scroller.is_ancestor_of(nav) and not nav.top_level,
		"Main Navigation is part of the page's normal scroll layout at %dx%d" % [viewport.x, viewport.y])
	var button_count := 0
	var scale_x: float = float(viewport.x) / app.get_viewport_rect().size.x
	for item in controls(nav, "Button"):
		var button: Button = item
		if not str(button.name).begins_with("Primary_"):
			continue
		var button_bounds: Rect2 = button.get_global_rect()
		button_count += 1
		expect(button_bounds.position.x * scale_x >= 0 and button_bounds.end.x * scale_x <= float(viewport.x) + 1.0
			and button_bounds.position.x >= nav.get_global_rect().position.x - 1.0
			and button_bounds.end.x <= nav.get_global_rect().end.x + 1.0,
			"%s remains horizontally reachable in normal page flow" % button.text)
	expect(button_count == 7, "All seven primary navigation items fit inside the drawer")
	if page_scroller != null:
		var before_scroll := nav.get_global_rect().position.y
		page_scroller.scroll_vertical = mini(page_scroller.get_v_scroll_bar().max_value, 100.0)
		await app.get_tree().process_frame
		expect(nav.get_global_rect().position.y < before_scroll,
			"Main Navigation scrolls with page content at %dx%d" % [viewport.x, viewport.y])
		page_scroller.scroll_vertical = 0
		await app.get_tree().process_frame
	if opened_here:
		app.close_navigation_drawer(false)
