extends SceneTree

const Main = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")

var failures := 0
var app: Control

func _initialize() -> void:
	run.call_deferred()

func controls(node: Node, type: String) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child.is_class(type): result.append(child)
		result.append_array(controls(child, type))
	return result

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func button(title: String, scope: Node = null) -> Button:
	var root: Node = app if scope == null else scope
	for candidate in controls(root, "Button"):
		if candidate.text.to_lower() == title.to_lower() and candidate.is_visible_in_tree(): return candidate
	return null

func has_validation_label(prefix: String) -> bool:
	return controls(app, "Label").any(func(candidate): return candidate.text.begins_with(prefix) and candidate.is_visible_in_tree())

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = Main.instantiate()
	root.add_child(app)
	await process_frame
	var state := Sim.register("Ari Founder", "North Star Co", "North Star", 0, 0, 1, 954)
	app.sim = Sim.new(state)
	app.screen = "Game"
	app.page = "Market"
	app.selected_product = 0
	app.render()
	await process_frame
	await process_frame
	var list := app.find_child("CompactSupplierList", true, false)
	expect(list != null, "Product Catalogue shows a compact supplier list before details")
	var first_supplier := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var supplier_choice := app.find_child("SupplierChoice%d" % first_supplier, true, false)
	expect(supplier_choice != null, "Selected product lists available supplier choices")
	var detail_button := button("View Details", supplier_choice)
	expect(detail_button != null and not detail_button.disabled, "Supplier selection opens its details without navigating away")
	if detail_button != null:
		detail_button.pressed.emit()
		await process_frame
		await process_frame
	expect(app.find_child("SelectedSupplierDetails", true, false) != null, "Supplier Details opens for the selected product and supplier")
	for action in ["Negotiate", "Accept Offer", "Purchase", "Back"]:
		expect(button(action) != null, "Supplier details provides the %s action" % action)
	expect(button("Request Quotation") == null, "The obsolete prominent Quotation action is replaced by Negotiate")
	var quantity := app.find_child("SelectedSupplierDetails", true, false).find_child("SupplierPurchaseQuantity", true, false)
	expect(quantity != null, "Purchase quantity appears only in supplier details")
	var payment_labels := controls(app.find_child("SelectedSupplierDetails", true, false), "OptionButton")
	expect(not payment_labels.is_empty(), "Supplier Details offers an upfront or supplier-credit payment choice")
	var accept := button("Accept Offer")
	if accept != null and quantity is LineEdit:
		accept.pressed.emit()
		await process_frame
		await process_frame
		var accepted_details := app.find_child("SelectedSupplierDetails", true, false)
		var accepted_quantity := accepted_details.find_child("SupplierPurchaseQuantity", true, false) as LineEdit
		accepted_quantity.text = "0"
		accepted_quantity.text_changed.emit("0")
		var accepted_label := controls(accepted_details, "Label").any(func(candidate): return candidate.text == "Offer accepted")
		expect(accepted_label and button("Purchase").disabled and has_validation_label("Enter a quantity from"),
			"Changing quantity preserves accepted supplier terms while invalid quantities remain blocked with an inline message")
		accepted_quantity.text = str(int(Catalog.SUPPLIERS[first_supplier].minimum))
		accepted_quantity.text_changed.emit(accepted_quantity.text)
		expect(button("Purchase") != null and not button("Purchase").disabled,
			"A valid quantity can use the accepted offer without forcing another acceptance action")
	var back := button("Back")
	if back != null:
		back.pressed.emit()
		await process_frame
		await process_frame
	expect(app.find_child("CompactSupplierList", true, false) != null and app.find_child("SelectedSupplierDetails", true, false) == null,
		"Back returns to the supplier list for the same product")
	root.size = Vector2i(390, 844)
	await process_frame
	expect(app.find_child("CompactSupplierList", true, false) != null,
		"Supplier list remains present at a mobile portrait viewport")
	print("Supplier workflow UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
