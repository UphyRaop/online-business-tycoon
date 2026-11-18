extends RefCounted

const Catalog = preload("res://catalog.gd")
const Storefront = preload("res://storefront.gd")
const Style = preload("res://corporate_theme.gd")

static func show(app: Control, product: int) -> VBoxContainer:
	var view: VBoxContainer = app.card("Offers")
	var state: Dictionary = app.sim.state
	view.add_child(app.label("Primary product: " + Catalog.PRODUCTS[product].name, 15, Style.GOLD))
	var currency: String = Catalog.CURRENCIES[state.country]
	var form: VBoxContainer = app.stack(view, 8)
	form.add_child(app.label("Create an offer", 18))
	form.visible = false
	var chooser: VBoxContainer = app.stack(form, 8)
	chooser.add_child(app.label("Choose the type of offer to create.", 14, Style.MUTED))
	var chooser_types: HBoxContainer = app.row(chooser)
	var editor: VBoxContainer = app.stack(form, 8)
	editor.visible = false
	editor.add_child(app.label("Offer type", 14, Style.MUTED))
	var switch_row: HBoxContainer = app.row(editor)
	var bundle_form: VBoxContainer = app.stack(editor, 8)
	var upsell_form: VBoxContainer = app.stack(editor, 8)
	var form_state := {"selected_type": 0}

	# Build both forms once inside the collapsed editor so switching types keeps
	# unsaved values in memory. Neither form changes save data until its Save action.
	var quantity: LineEdit = app.field(bundle_form, "Units per bundle (2–10)", "2", 2)
	quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	bundle_form.add_child(app.label("Stock is checked for every bundle unit when an order is placed.", 13, Style.MUTED))
	bundle_form.add_child(app.label("Bundle price", 14, Style.MUTED))
	var bundle_pricing: OptionButton = app.dropdown(bundle_form, ["Percentage discount", "Fixed total price"], 0)
	var bundle_discount_box: VBoxContainer = app.stack(bundle_form, 4)
	var bundle_discount: LineEdit = app.field(bundle_discount_box, "Discount percent (0–50)", "10", 2)
	bundle_discount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var bundle_price_box: VBoxContainer = app.stack(bundle_form, 4)
	var bundle_price: LineEdit = app.field(bundle_price_box, "Fixed total price (%s)" % currency, "0", 16)
	bundle_price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	bundle_price_box.visible = false
	bundle_pricing.item_selected.connect(func(index: int):
		bundle_discount_box.visible = index == 0
		bundle_price_box.visible = index == 1
	)

	var eligible: Array[int] = []
	var product_names: Array[String] = []
	for id in Catalog.PRODUCTS.size():
		if id == product: continue
		eligible.append(id)
		product_names.append(Catalog.PRODUCTS[id].name)
	upsell_form.add_child(app.label("Choose one or two additional units from products other than the primary product.", 14, Style.MUTED))
	upsell_form.add_child(app.label("Upsell quantity", 14, Style.MUTED))
	var composition: OptionButton = app.dropdown(upsell_form, ["1 unit", "2 different products", "2 units of one product"], 0)
	upsell_form.add_child(app.label("Additional product", 14, Style.MUTED))
	var first_product: OptionButton = app.dropdown(upsell_form, product_names, 0)
	upsell_form.add_child(app.label("Second product", 14, Style.MUTED))
	var second_product: OptionButton = app.dropdown(upsell_form, product_names, 0)
	second_product.visible = false
	composition.item_selected.connect(func(index: int): second_product.visible = index == 1)
	upsell_form.add_child(app.label("Upsell price", 14, Style.MUTED))
	var upsell_pricing: OptionButton = app.dropdown(upsell_form, ["Percentage discount", "Fixed total price"], 0)
	var upsell_discount_box: VBoxContainer = app.stack(upsell_form, 4)
	var upsell_discount: LineEdit = app.field(upsell_discount_box, "Discount percent (0–50)", "10", 2)
	upsell_discount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var upsell_price_box: VBoxContainer = app.stack(upsell_form, 4)
	var upsell_price: LineEdit = app.field(upsell_price_box, "Fixed total price (%s)" % currency, "0", 16)
	upsell_price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	upsell_price_box.visible = false
	upsell_pricing.item_selected.connect(func(index: int):
		upsell_discount_box.visible = index == 0
		upsell_price_box.visible = index == 1
	)

	var chooser_cancel_row: HBoxContainer = app.row(chooser)
	var action_row: HBoxContainer = app.row(form)
	var action_buttons := {"bundle": null, "upsell": null, "cancel": null}
	var type_buttons: Array[Button] = []
	var cancel := func():
		form.visible = false
		chooser.visible = true
		editor.visible = false
		action_row.visible = false
		app.set_notice("")
	app.action(chooser_cancel_row, "Cancel", cancel)
	var set_type := func(mode: int):
		form_state.selected_type = mode
		chooser.visible = false
		chooser_cancel_row.visible = false
		editor.visible = true
		bundle_form.visible = mode == 1
		upsell_form.visible = mode == 2
		for i in type_buttons.size(): type_buttons[i].disabled = i == mode - 1
		action_row.visible = true
		chooser_cancel_row.visible = false
		action_buttons.bundle.visible = mode == 1
		action_buttons.upsell.visible = mode == 2
		action_buttons.cancel.visible = true
	var type_bundle: Button = app.action(chooser_types, "Bundle", func(): set_type.call(1), true)
	var type_upsell: Button = app.action(chooser_types, "Upsell", func(): set_type.call(2))
	var switch_bundle: Button = app.action(switch_row, "Bundle", func(): set_type.call(1), true)
	var switch_upsell: Button = app.action(switch_row, "Upsell", func(): set_type.call(2))
	type_buttons.assign([switch_bundle, switch_upsell])
	action_buttons.bundle = app.action(action_row, "Save bundle", func():
		if int(form_state.selected_type) != 1: return
		var qty := _integer(quantity.text, -1)
		var discount := _integer(bundle_discount.text, -1)
		if bundle_pricing.selected == 1 and _price_cents(app, bundle_price.text) <= 0:
			app.set_notice("Enter a positive fixed bundle price.", true)
			return
		if bundle_pricing.selected == 0 and not _valid_price(app, bundle_price.text):
			app.set_notice("Enter a valid fixed bundle price.", true)
			return
		var price := _price_cents(app, bundle_price.text) if bundle_pricing.selected == 1 else 0
		var error := Storefront.set_bundle(state, product, qty, discount, price)
		if not error.is_empty():
			app.set_notice(error, true)
			return
		app.persist("Bundle saved.")
		app.refresh_view()
	, true)
	action_buttons.upsell = app.action(action_row, "Save upsell", func():
		if int(form_state.selected_type) != 2: return
		if eligible.is_empty():
			app.set_notice("No other products are available for this upsell.", true)
			return
		var items: Array = [eligible[first_product.selected]]
		if composition.selected == 1:
			if first_product.selected == second_product.selected:
				app.set_notice("Choose two different products, or select two units of one product.", true)
				return
			items.append(eligible[second_product.selected])
		elif composition.selected == 2:
			items.append(eligible[first_product.selected])
		var discount := _integer(upsell_discount.text, -1)
		if upsell_pricing.selected == 1 and _price_cents(app, upsell_price.text) <= 0:
			app.set_notice("Enter a positive fixed upsell price.", true)
			return
		if upsell_pricing.selected == 0 and not _valid_price(app, upsell_price.text):
			app.set_notice("Enter a valid fixed upsell price.", true)
			return
		var price := _price_cents(app, upsell_price.text) if upsell_pricing.selected == 1 else 0
		var error := Storefront.set_upsell(state, product, items, discount, price)
		if not error.is_empty():
			app.set_notice(error, true)
			return
		app.persist("Upsell saved.")
		app.refresh_view()
	)
	action_buttons.cancel = app.action(action_row, "Cancel", cancel)
	action_row.visible = false

	var load_saved := func():
		var saved := Storefront.offers_for(state, product)
		var saved_bundle: Dictionary = saved.get(1, {})
		var saved_upsell: Dictionary = saved.get(2, {})
		quantity.text = str(saved_bundle.get("quantity", 2))
		bundle_discount.text = str(saved_bundle.get("discount", 10))
		bundle_price.text = _price_text(app, int(saved_bundle.get("price", 0)))
		bundle_pricing.select(1 if int(saved_bundle.get("price", 0)) > 0 else 0)
		bundle_discount_box.visible = bundle_pricing.selected == 0
		bundle_price_box.visible = bundle_pricing.selected == 1
		var saved_items: Array = saved_upsell.get("items", [])
		composition.select(_composition_index(saved_items))
		first_product.select(maxi(0, eligible.find(_first_item(saved_upsell))))
		second_product.select(maxi(0, eligible.find(_second_item(saved_upsell))))
		second_product.visible = composition.selected == 1
		upsell_discount.text = str(saved_upsell.get("discount", 10))
		upsell_price.text = _price_text(app, int(saved_upsell.get("price", 0)))
		upsell_pricing.select(1 if int(saved_upsell.get("price", 0)) > 0 else 0)
		upsell_discount_box.visible = upsell_pricing.selected == 0
		upsell_price_box.visible = upsell_pricing.selected == 1
	var open_create := func():
		load_saved.call()
		form_state.selected_type = 0
		form.visible = true
		chooser.visible = true
		chooser_cancel_row.visible = true
		editor.visible = false
		bundle_form.visible = false
		upsell_form.visible = false
		action_row.visible = false
		action_buttons.bundle.visible = false
		action_buttons.upsell.visible = false
		action_buttons.cancel.visible = false
		app.set_notice("")
	var open_edit := func(mode: int):
		load_saved.call()
		form.visible = true
		editor.visible = true
		chooser.visible = false
		chooser_cancel_row.visible = false
		set_type.call(mode)
		app.set_notice("")

	var existing: VBoxContainer = app.stack(view, 8)
	var offers := Storefront.offers_for(state, product)
	var bundle: Dictionary = offers.get(1, {})
	var upsell: Dictionary = offers.get(2, {})
	if bundle.is_empty() and upsell.is_empty():
		existing.add_child(app.label("No offers saved for this product.", 14, Style.MUTED))
	else:
		if not bundle.is_empty():
			_existing_offer(app, existing, product, 1, bundle, open_edit)
		if not upsell.is_empty():
			_existing_offer(app, existing, product, 2, upsell, open_edit)
	app.action(view, "Create Offer", open_create, true)
	view.move_child(form, view.get_child_count() - 1)
	return view

static func _existing_offer(app: Control, parent: VBoxContainer, product: int, mode: int, offer: Dictionary, edit_action: Callable) -> void:
	var is_bundle := mode == 1
	var card: VBoxContainer = app.stack(parent, 6)
	card.add_child(app.label("Bundle" if is_bundle else "Upsell", 18))
	var shown_price := _format_price(app, int(offer.get("price", 0))) if int(offer.get("price", 0)) > 0 else "%d%% off" % int(offer.get("discount", 0))
	var status := "Enabled" if offer.get("enabled", true) else "Disabled"
	if is_bundle:
		card.add_child(app.label("%d × %s · %s · %s" % [int(offer.get("quantity", 2)), Catalog.PRODUCTS[product].name, shown_price, status], 14, Style.MUTED))
	else:
		var parts: Array[String] = [Catalog.PRODUCTS[product].name]
		for id in offer.get("items", []):
			if int(id) in range(Catalog.PRODUCTS.size()): parts.append(Catalog.PRODUCTS[int(id)].name)
		card.add_child(app.label("%s · %s · %s" % [" + ".join(parts), shown_price, status], 14, Style.MUTED))
	var actions: HBoxContainer = app.row(card)
	var edit_title := "Edit bundle" if is_bundle else "Edit upsell"
	app.action(actions, edit_title, func(): edit_action.call(mode))
	var enable_title := "Enable bundle" if is_bundle else "Enable upsell"
	var disable_title := "Disable bundle" if is_bundle else "Disable upsell"
	var status_title := disable_title if offer.get("enabled", true) else enable_title
	app.action(actions, status_title, func():
		var current := Storefront.offers_for(app.sim.state, product)
		var next_enabled := not bool(current.get(mode, {}).get("enabled", true))
		Storefront.set_enabled(app.sim.state, product, mode, next_enabled)
		app.persist("%s %s." % ["Bundle" if is_bundle else "Upsell", "enabled" if next_enabled else "disabled"])
		app.refresh_view()
	)

static func _integer(value: String, fallback: int) -> int:
	var text := value.strip_edges()
	return text.to_int() if text.is_valid_int() else fallback

static func _price_cents(app: Control, value: String) -> int:
	return app.price_cents(value) if not value.strip_edges().is_empty() else 0

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
