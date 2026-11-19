extends RefCounted

const Catalog = preload("res://catalog.gd")
const Calendar = preload("res://game_calendar.gd")
const Fulfillment = preload("res://fulfillment.gd")
const Service = preload("res://customer_service.gd")
const Stores = preload("res://store_manager.gd")
const Style = preload("res://corporate_theme.gd")
const PAGE_SIZE := 5
const FILTERS := ["Active orders", "Queued", "In transit", "Delivered", "All orders"]

static func show(app: Control) -> void:
	var navigation: VBoxContainer = app.card("Store Operations")
	var tab: OptionButton = app.dropdown(navigation, ["Fulfillment", "Customer service", "Sales analytics", "Shipping settings"], app.orders_tab)
	tab.custom_minimum_size.y = 44
	tab.add_theme_font_size_override("font_size", 13)
	tab.item_selected.connect(func(index: int):
		tab.select(app.orders_tab)
		app.discard_form_then(func():
			app.orders_tab = index
			app.order_page = 0
			app.render()
		)
	)
	match app.orders_tab:
		0: fulfillment(app)
		1: service(app)
		2: analytics(app)
		3: shipping_settings(app)

static func preorders(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var view: VBoxContainer = app.card("Pre-orders")
	var ids: Array = []
	for id in state.orders:
		if state.orders[id].get("preorder", false): ids.append(id)
	ids.sort_custom(func(a: int, b: int):
		var first: Dictionary = state.orders[a]
		var second: Dictionary = state.orders[b]
		return first.placed < second.placed if first.placed != second.placed else a < b
	)
	var pending := ids.filter(func(id): return state.orders[id].status not in ["delivered", "cancelled"])
	app.metric(view, "Outstanding pre-orders", str(pending.size()))
	var overdue := 0
	for id in pending:
		var order: Dictionary = state.orders[id]
		if int(order.get("expected_restock", 0)) > 0 and state.day > int(order.expected_restock): overdue += 1
	if overdue > 0:
		view.add_child(app.label("%d pre-orders are past their estimated replenishment date. Review supplier shipments." % overdue, 14, Style.GOLD))
	if ids.is_empty():
		view.add_child(app.label("No customer pre-orders yet. Enable pre-orders on a product listing in Market / Management.", 14, Style.MUTED))
		return
	for id in ids:
		var order: Dictionary = state.orders[id]
		var store: Dictionary = Stores.get_store(state, int(order.store_id))
		var card: VBoxContainer = app.card("Pre-order #%04d" % int(id))
		var product_names := PackedStringArray()
		for line in order.items:
			product_names.append(Catalog.PRODUCTS[int(line.product)].name)
		app.metric(card, "Product", " + ".join(product_names))
		app.metric(card, "Store / Website", str(store.get("name", "Unknown store")))
		app.metric(card, "Quantity", str(order.items.size()))
		app.metric(card, "Order date", Calendar.format(int(order.placed)))
		app.metric(card, "Payment", "Collected · held as customer deposit" if order.status != "delivered" else "Captured · revenue recognized on delivery")
		app.metric(card, "Pre-order status", _preorder_status(str(order.get("preorder_status", "awaiting_stock"))))
		app.metric(card, "Customer wait", "%d days estimated" % int(order.get("fulfillment_delay", 0)))
		if int(order.get("expected_restock", 0)) > 0 and order.status not in ["delivered", "cancelled"]:
			var confirmed := false
			for batch in state.inbound:
				if int(batch.product) in order.items.map(func(line): return int(line.product)):
					confirmed = true
			app.metric(card, "Estimated replenishment", "%s%s" % [Calendar.format(int(order.expected_restock)), " · shipment confirmed" if confirmed else " · estimate only"])
		else:
			app.metric(card, "Estimated replenishment", "Uncertain" if order.status not in ["delivered", "cancelled"] else "Completed")
		app.metric(card, "Payment amount", app.money(int(order.total)))
		if order.status not in ["delivered", "cancelled"]:
			app.action(card, "Cancel and refund pre-order", func():
				var error := Service.cancel_preorder(app.sim, int(id))
				if not error.is_empty():
					app.set_notice(error, true)
					return
				Fulfillment.allocate_preorders(app.sim)
				app.persist("Pre-order cancelled. Customer deposit refunded.")
				app.refresh_view()
			)
		elif order.status == "delivered" and Service.can_refund(state, order):
			app.action(card, "Issue refund", refund.bind(app, int(id)))

static func _preorder_status(value: String) -> String:
	match value:
		"awaiting_stock": return "Pre-order placed · Awaiting stock"
		"stock_allocated": return "Stock allocated · Awaiting remaining items"
		"ready_for_fulfillment": return "Ready for fulfillment"
		"shipped": return "Shipped"
		"delivered": return "Delivered"
		"cancelled": return "Cancelled / refunded"
		_: return value.capitalize()

static func shipping_settings(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var settings: VBoxContainer = app.card("Dispatch Settings")
	if app.shipping_settings_editing:
		var method: OptionButton = app.dropdown(settings, methods(app), state.shipping)
		var mode: OptionButton = app.dropdown(settings, ["Automatic Dispatch", "Manual Dispatch"], 0 if state.auto_dispatch else 1)
		method.custom_minimum_size.y = 44
		mode.custom_minimum_size.y = 44
		method.add_theme_font_size_override("font_size", 13)
		mode.add_theme_font_size_override("font_size", 13)
		app.watch_edits([method, mode])
		app.action(settings, "Save Changes", func():
			state.shipping = method.selected
			state.auto_dispatch = mode.selected == 0
			app.shipping_settings_editing = false
			app.persist("Dispatch settings saved.")
			app.refresh_view()
		, true)
		app.action(settings, "Cancel", func():
			app.shipping_settings_editing = false
			app.edit_checks.clear()
			app.refresh_view()
		)
	else:
		app.metric(settings, "Shipping Method", methods(app)[state.shipping])
		app.metric(settings, "Dispatch Mode", "Automatic Dispatch" if state.auto_dispatch else "Manual Dispatch")
		app.action(settings, "Edit Dispatch Settings", func():
			app.shipping_settings_editing = true
			app.refresh_view()
		)
	settings.add_child(app.label("Automatic dispatch sends queued orders when you advance time. Manual dispatch lets you choose the method for each order. New orders use the selected method to set their delivery promise.", 14, Style.MUTED))

static func fulfillment(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var report: Dictionary = app.sim.report(30)
	var delivered: int = total(report, "tracked_deliveries")
	var filter: VBoxContainer = app.card("Order Tracking")
	app.metric(filter, "Awaiting delivery", str(state.active_orders.size()))
	app.metric(filter, "30-day on-time rate", percent(total(report, "on_time"), delivered))
	var picker: OptionButton = app.dropdown(filter, FILTERS, app.order_filter)
	picker.item_selected.connect(func(index: int):
		app.order_filter = index
		app.order_page = 0
		app.refresh_view()
	)
	var orders: Array = []
	var ids: Array = state.active_orders if app.order_filter <= 2 else state.orders.keys()
	for id in ids:
		var order: Dictionary = state.orders[id]
		if app.order_filter == 1 and order.status != "queued":
			continue
		if app.order_filter == 2 and order.status != "shipped":
			continue
		if app.order_filter == 3 and order.status != "delivered":
			continue
		orders.append(order)
	show_orders(app, filter, orders, false)
	var performance: VBoxContainer = app.card("Fulfillment · Last 30 days")
	app.metric(performance, "Orders dispatched", str(total(report, "dispatched")))
	app.metric(performance, "Orders delivered", str(delivered))
	app.metric(performance, "On-time delivery", percent(total(report, "on_time"), delivered))
	app.metric(performance, "Shipping cost", app.money(report.shipping))

static func methods(app: Control) -> Array:
	var choices: Array = []
	for method in Catalog.SHIPPING:
		var cost := Catalog.local_cents(app.sim.state.country, method.cost)
		choices.append("%s · %d days · %s" % [method.name, method.days, app.money(cost)])
	return choices

static func service(app: Control) -> void:
	var state: Dictionary = app.sim.state
	var scores: VBoxContainer = app.card("Customer Satisfaction and Reputation")
	app.metric(scores, "Satisfaction", "%d / 100" % state.satisfaction)
	app.metric(scores, "Store reputation", "%d / 100" % state.reputation)
	app.metric(scores, "Open cases", str(state.open_cases.size()))
	scores.add_child(app.label("Unanswered cases escalate after five days. Store reputation affects future checkout traffic and conversion.", 14, Style.MUTED))
	var queue: VBoxContainer = app.card("Complaints and Returns")
	var orders: Array = []
	for id in state.open_cases:
		orders.append(state.orders[id])
	show_orders(app, queue, orders, true)

static func show_orders(app: Control, parent: VBoxContainer, orders: Array, cases_only: bool) -> void:
	if orders.is_empty():
		parent.add_child(app.label("No cases to review." if cases_only else "No orders in this view.", 14, Style.MUTED))
		app.order_page = 0
		return
	var last := floori((orders.size() - 1) / float(PAGE_SIZE))
	app.order_page = clampi(app.order_page, 0, last)
	var first: int = app.order_page * PAGE_SIZE
	var count := mini(PAGE_SIZE, orders.size() - first)
	app.metric(parent, "Showing %d–%d of %d" % [first + 1, first + count, orders.size()], "")
	if last > 0:
		var buttons: HBoxContainer = app.row(parent)
		var newer: Button = app.action(buttons, "Newer", change_page.bind(app, -1))
		var older: Button = app.action(buttons, "Older", change_page.bind(app, 1))
		newer.disabled = app.order_page == 0
		older.disabled = app.order_page == last
	for i in range(first, first + count):
		order_card(app, orders[orders.size() - 1 - i], cases_only)

static func change_page(app: Control, delta: int) -> void:
	app.order_page += delta
	app.refresh_view()

static func order_card(app: Control, order: Dictionary, cases_only: bool) -> void:
	var state: Dictionary = app.sim.state
	var view: VBoxContainer = app.card("Order #%04d" % order.id)
	var names := PackedStringArray()
	for item in order.items:
		names.append(Catalog.PRODUCTS[item.product].name)
	view.add_child(app.label(" + ".join(names), 15))
	app.metric(view, Catalog.CHANNELS[order.channel], app.money(order.total))
	if not cases_only:
		tracking(app, view, order)
	if order.case_status == "open":
		app.divider(view)
		var suffix := " · escalated" if order.escalated else ""
		view.add_child(app.label("%s · %s%s" % [order.reason, Calendar.format(order.case_day), suffix], 15, Style.GOLD))
		if order.return_requested:
			view.add_child(app.label("Returned stock is resellable." if order.restockable else "Defective return will be written off.", 14, Style.MUTED))
			app.action(view, "Approve return and refund", refund.bind(app, order.id), true)
			app.action(view, "Decline return", func():
				finish(app, Service.reject_return(state, order.id), "Return declined.")
			)
		else:
			app.action(view, "Respond and resolve", func():
				finish(app, Service.respond(state, order.id), "Complaint resolved.")
			)
			app.action(view, "Issue refund", refund.bind(app, order.id))
	elif order.refunded:
		view.add_child(app.label("Refunded", 14, Style.GREEN))
	else:
		if order.case_status == "resolved":
			view.add_child(app.label("Complaint resolved", 14, Style.GREEN))
		elif order.case_status == "declined":
			view.add_child(app.label("Return declined", 14, Style.MUTED))
		if Service.can_refund(state, order):
			app.action(view, "Issue full refund", refund.bind(app, order.id))

static func tracking(app: Control, view: VBoxContainer, order: Dictionary) -> void:
	var state: Dictionary = app.sim.state
	app.metric(view, "Placed", Calendar.format(order.placed))
	app.metric(view, "Promised", Calendar.format(order.promise))
	if order.get("preorder", false):
		view.add_child(app.label("Pre-order · %s" % _preorder_status(str(order.get("preorder_status", "awaiting_stock"))), 14, Style.GOLD))
	match order.status:
		"queued":
			view.add_child(app.label("Awaiting dispatch", 15, Style.GOLD))
			var method: OptionButton = app.dropdown(view, methods(app), order.method)
			app.action(view, "Dispatch order", func():
				finish(app, Fulfillment.ship(state, order.id, method.selected), "Order dispatched.")
			, true)
		"shipped":
			var estimate: int = order.arrival if order.delayed else order.eta
			app.metric(view, "In transit · %s" % Catalog.SHIPPING[order.method].name,
				"%s%s" % [Calendar.format(estimate), " · delayed" if order.delayed else ""])
			app.metric(view, "Tracking", "OBT-%04d" % order.id)
		"delivered":
			app.metric(view, "Delivered", Calendar.format(order.delivered))
			app.metric(view, Catalog.SHIPPING[order.method].name, "On time" if order.delivered <= order.promise else "Late")
			app.metric(view, "Tracking", "OBT-%04d" % order.id)

static func refund(app: Control, id: int) -> void:
	finish(app, Service.refund(app.sim, id), "Full refund issued.")

static func finish(app: Control, error: String, success: String) -> void:
	if not error.is_empty():
		app.set_notice(error, true)
		return
	app.persist(success)
	app.refresh_view()

static func analytics(app: Control) -> void:
	var view: VBoxContainer = app.card("Checkout Analytics")
	var window: OptionButton = app.dropdown(view, ["Last 7 days", "Last 30 days", "Last 365 days"], app.analytics_window)
	window.item_selected.connect(func(index: int):
		app.analytics_window = index
		app.refresh_view()
	)
	var days: int = [7, 30, 365][app.analytics_window]
	var report: Dictionary = app.sim.report(days)
	view.add_child(app.label(Calendar.format_range(report.start, report.end), 14, Style.MUTED))
	for channel in Catalog.FEES.size():
		var totals: Dictionary = report.channels[channel]
		var details: VBoxContainer = app.card(Catalog.CHANNELS[channel])
		app.metric(details, "Checkout attempts", str(totals.checkouts))
		app.metric(details, "Abandoned checkouts", str(totals.abandoned))
		app.metric(details, "Lost to stockouts", str(totals.stockouts))
		app.metric(details, "Orders placed", str(totals.placed))
		app.metric(details, "Checkout conversion", percent(totals.placed, totals.checkouts), Style.GOLD)
		app.divider(details)
		app.metric(details, "Bundles ordered", str(totals.bundles))
		app.metric(details, "Upsells accepted", str(totals.upsells))
		app.metric(details, "Refunds issued", str(totals.refunded))
		app.metric(details, "Net sales", app.money(totals.sales - totals.refunds))

static func percent(count: int, denominator: int) -> String:
	return "%.1f%%" % (count * 100.0 / denominator) if denominator > 0 else "—"

static func total(report: Dictionary, field: String) -> int:
	return report.channels[0][field] + report.channels[1][field]
