extends RefCounted

const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Summary = preload("res://product_summary.gd")
const Style = preload("res://corporate_theme.gd")

static func show(app: Control) -> void:
	var sim: RefCounted = app.sim
	var state: Dictionary = sim.state
	var overview: VBoxContainer = app.card("Product portfolio")
	app.metric(overview, "Active products", str(sim.active_product_count()), Style.GOLD)
	app.metric(overview, "Default outbound delivery", app.money(Catalog.local_cents(state.country, Catalog.SHIPPING[state.shipping].cost)) + " / order")
	app.action(overview, "Browse catalog", app.navigate.bind("Market"))
	var activity := Summary.collect(state)
	var count := 0
	for id in Catalog.PRODUCTS.size():
		if not state.products.has(id) and not state.quotes.has(id) and not state.offers.has(id):
			continue
		count += 1
		var item: Dictionary = sim.product_state(id)
		var view: VBoxContainer = app.card(Catalog.PRODUCTS[id].name)
		var available: int = sim.stock(id)
		var inbound := Supply.incoming(state, id)
		var channels := PackedStringArray()
		for channel in Catalog.FEES.size():
			if sim.product_on_channel(item, channel):
				channels.append(Catalog.CHANNELS[channel])
		var status := "Draft" if channels.is_empty() else ("Out of Stock" if available == 0 else "Active")
		var status_color := Style.GREEN if status == "Active" else (Style.MUTED if status == "Draft" else Style.GOLD)
		view.add_child(app.label(status, 15, status_color))
		app.metric(view, "Supplier", Catalog.SUPPLIERS[item.supplier].name)
		app.metric(view, "Inventory", "%d available · %d inbound" % [available, inbound])
		var cost: Dictionary = sim.unit_cost(id, item.supplier)
		var gross: int = item.price - cost.landed
		view.add_child(app.label(cost.source, 13, Style.MUTED))
		app.metric(view, "Goods per unit", app.money(cost.goods))
		app.metric(view, "Inbound freight per unit", app.money(cost.freight))
		app.metric(view, "Landed unit cost", app.money(cost.landed))
		app.metric(view, "Selling price", app.money(item.price))
		app.metric(view, "Est. unit gross profit", app.money(gross), app.profit_color(gross))
		app.metric(view, "Est. gross margin", "%.1f%%" % (100.0 * gross / item.price), app.profit_color(gross))
		if channels.is_empty():
			app.metric(view, "Prepared channels", Catalog.CHANNELS[int(item.get("channel_mask", 3)) - 1])
		else:
			app.metric(view, "Live channels", ", ".join(channels))
		if channels.is_empty() and item.listed:
			view.add_child(app.label("Enable a selected sales channel in Business to publish.", 13, Style.MUTED))
		app.divider(view)
		var totals: Dictionary = activity.get(id, {"units": 0, "revenue": 0, "profit": 0})
		app.metric(view, "Units sold (net)", str(totals.units))
		app.metric(view, "Net revenue", app.money(totals.revenue))
		app.metric(view, "Product profit", app.money(totals.profit), app.profit_color(totals.profit))
		app.action(view, "Manage " + Catalog.PRODUCTS[id].name, app.open_product.bind(id))
	if count == 0:
		overview.add_child(app.label("Prepare a listing, select a supplier, or buy stock in Market to add a product here.", 15, Style.MUTED))
	else:
		var notes: VBoxContainer = app.card("About product profit")
		notes.add_child(app.label("Estimated gross profit uses landed cost. Historical product profit also deducts customer delivery and channel fees, and reflects refunds.", 14, Style.MUTED))
