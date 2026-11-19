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
