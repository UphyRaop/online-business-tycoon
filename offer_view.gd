extends RefCounted

const Catalog = preload("res://catalog.gd")
const Storefront = preload("res://storefront.gd")
const Style = preload("res://corporate_theme.gd")

static func show(app: Control, product: int) -> VBoxContainer:
	var view: VBoxContainer = app.card("Bundles and upsells")
	var state: Dictionary = app.sim.state
	var primary: Dictionary = app.sim.product_state(product)
	view.add_child(app.label("Primary product: " + Catalog.PRODUCTS[product].name, 15, Style.GOLD))
	var offers := Storefront.offers_for(state, product)
	var bundle: Dictionary = offers.get(1, {})
	var bundle_card: VBoxContainer = app.stack(view, 8)
	bundle_card.add_child(app.label("Same-product bundle", 18))
	bundle_card.add_child(app.label("Bundle quantities use only the selected product. Stock is checked for every unit.", 14, Style.MUTED))
	var quantity: LineEdit = app.field(bundle_card, "Units per bundle (2–10)", str(bundle.get("quantity", 2)), 2)
	quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var bundle_discount: LineEdit = app.field(bundle_card, "Discount percent (0–50)", str(bundle.get("discount", 10)), 2)
	bundle_discount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var currency: String = Catalog.CURRENCIES[state.country]
	var bundle_price: LineEdit = app.field(bundle_card, "Fixed total price (%s · optional, 0 uses discount)" % currency, _price_text(app, int(bundle.get("price", 0))), 16)
	bundle_price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	var bundle_enabled: Button = app.action(bundle_card, "", func():
		var current: Dictionary = Storefront.offers_for(state, product).get(1, {})
		if current.is_empty():
			app.set_notice("Save the bundle before changing its status.", true)
			return
		var next: bool = not current.get("enabled", true)
		Storefront.set_enabled(state, product, 1, next)
		app.persist("Bundle %s." % ("enabled" if next else "disabled"))
		app.refresh_view()
	)
	bundle_enabled.text = "Disable bundle" if bundle.get("enabled", true) else "Enable bundle"
	bundle_enabled.disabled = bundle.is_empty()
	app.action(bundle_card, "Save bundle", func():
		var qty := _integer(quantity.text, -1)
		var discount := _integer(bundle_discount.text, -1)
		if not _valid_price(app, bundle_price.text):
			app.set_notice("Enter a valid fixed bundle price, or leave it blank or set it to 0.", true)
			return
		var fixed_price: int = app.price_cents(bundle_price.text) if not bundle_price.text.strip_edges().is_empty() else 0
		if bundle_price.text.strip_edges() == "0":
			fixed_price = 0
		var error := Storefront.set_bundle(state, product, qty, discount, fixed_price)
		if not error.is_empty():
			app.set_notice(error, true)
			return
		app.persist("Same-product bundle saved.")
		app.refresh_view()
	, true)
	var bundle_info := "No bundle saved."
	if not bundle.is_empty():
		bundle_info = "%d × %s · %s" % [bundle.quantity, Catalog.PRODUCTS[product].name,
			(_format_price(app, bundle.price) if bundle.price > 0 else "%d%% off" % bundle.discount)]
	bundle_card.add_child(app.label(bundle_info, 14, Style.MUTED))
	var upsell: Dictionary = offers.get(2, {})
	var upsell_card: VBoxContainer = app.stack(view, 8)
	upsell_card.add_child(app.label("Additional-product upsell", 18))
	upsell_card.add_child(app.label("Adds one or two units from other products. The primary product is excluded.", 14, Style.MUTED))
	var eligible: Array[int] = []
	var names: Array[String] = []
	for id in Catalog.PRODUCTS.size():
		if id != product:
			eligible.append(id)
			names.append(Catalog.PRODUCTS[id].name)
	var composition: OptionButton = app.dropdown(upsell_card, ["One additional unit", "Two different products", "Two units of one product"], _composition_index(upsell.items if not upsell.is_empty() else []))
	var first: OptionButton = app.dropdown(upsell_card, names, maxi(0, eligible.find(_first_item(upsell))))
	var second: OptionButton = app.dropdown(upsell_card, names, maxi(0, eligible.find(_second_item(upsell))))
	second.visible = composition.selected == 1
	composition.item_selected.connect(func(index: int): second.visible = index == 1)
	var upsell_discount: LineEdit = app.field(upsell_card, "Discount percent across the upsell basket (0–50)", str(upsell.get("discount", 10)), 2)
	upsell_discount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var upsell_price: LineEdit = app.field(upsell_card, "Fixed total price (%s · optional, 0 uses discount)" % currency, _price_text(app, int(upsell.get("price", 0))), 16)
	upsell_price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	var upsell_enabled: Button = app.action(upsell_card, "", func():
		var current: Dictionary = Storefront.offers_for(state, product).get(2, {})
		if current.is_empty():
			app.set_notice("Save the upsell before changing its status.", true)
			return
		var next: bool = not current.get("enabled", true)
		Storefront.set_enabled(state, product, 2, next)
		app.persist("Upsell %s." % ("enabled" if next else "disabled"))
		app.refresh_view()
	)
	upsell_enabled.text = "Disable upsell" if upsell.get("enabled", true) else "Enable upsell"
	upsell_enabled.disabled = upsell.is_empty()
	app.action(upsell_card, "Save upsell", func():
		var selected_items: Array = [eligible[first.selected]]
		if composition.selected == 1:
			if first.selected == second.selected:
				app.set_notice("Choose two different products, or select two units of one product.", true)
				return
			selected_items.append(eligible[second.selected])
		elif composition.selected == 2:
			selected_items.append(eligible[first.selected])
		var discount := _integer(upsell_discount.text, -1)
		if not _valid_price(app, upsell_price.text):
			app.set_notice("Enter a valid fixed upsell price, or leave it blank or set it to 0.", true)
			return
		var fixed_price: int = app.price_cents(upsell_price.text) if not upsell_price.text.strip_edges().is_empty() else 0
		if upsell_price.text.strip_edges() == "0": fixed_price = 0
		var error := Storefront.set_upsell(state, product, selected_items, discount, fixed_price)
		if not error.is_empty():
			app.set_notice(error, true)
			return
		app.persist("Additional-product upsell saved.")
		app.refresh_view()
	, true)
	if not upsell.is_empty():
		var parts: Array[String] = [Catalog.PRODUCTS[product].name]
		for id in upsell.items:
			parts.append(Catalog.PRODUCTS[id].name)
		upsell_card.add_child(app.label("Current offer: %s · %s · %s" % [" + ".join(parts),
			(_format_price(app, upsell.price) if upsell.price > 0 else "%d%% off" % upsell.discount),
			"Enabled" if upsell.enabled else "Disabled"], 14, Style.MUTED))
	return view

static func _integer(value: String, fallback: int) -> int:
	var text := value.strip_edges()
	return text.to_int() if text.is_valid_int() else fallback

static func _price_text(app: Control, cents: int) -> String:
	return "0" if cents <= 0 else app.amount_text(cents, true).replace(",", "")

static func _format_price(app: Control, cents: int) -> String:
	return app.money(cents)

static func _valid_price(app: Control, value: String) -> bool:
	var text := value.strip_edges()
	return text.is_empty() or text == "0" or app.price_cents(text) > 0

static func _composition_index(items: Array) -> int:
	if items.size() != 2: return 0
	return 2 if items[0] == items[1] else 1

static func _first_item(offer: Dictionary) -> int:
	var items: Array = offer.get("items", [])
	return int(items[0]) if not items.is_empty() else -1

static func _second_item(offer: Dictionary) -> int:
	var items: Array = offer.get("items", [])
	return int(items[1]) if items.size() > 1 else -1
