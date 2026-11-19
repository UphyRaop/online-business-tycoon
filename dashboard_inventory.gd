extends RefCounted

## Dashboard inventory summary. Stock in active customer orders has already
## left warehouse lots, so it is reported separately as reserved and included
## in total stock units until fulfillment records COGS.
const Catalog = preload("res://catalog.gd")
const Style = preload("res://corporate_theme.gd")

const LOW_STOCK_THRESHOLD := 3
const MOBILE_ROW_LIMIT := 5
const DESKTOP_ROW_LIMIT := 8

static func summary(sim: RefCounted) -> Dictionary:
	var per_product: Array[Dictionary] = []
	var reserved_by_product := {}
	var preorder_by_product := {}
	var active_orders: Array = sim.state.get("active_orders", [])
	for order_id in active_orders:
		var order: Dictionary = sim.state.get("orders", {}).get(order_id, {})
		if order.is_empty() or str(order.get("status", "")) in ["delivered", "cancelled"]:
			continue
		for line in order.get("items", []):
			var product := int(line.get("product", -1))
			if product not in range(Catalog.PRODUCTS.size()):
				continue
			if line.get("awaiting_stock", false):
				if order.get("preorder", false):
					preorder_by_product[product] = int(preorder_by_product.get(product, 0)) + 1
				continue
			if line.has("direct_supplier"):
				continue
			reserved_by_product[product] = int(reserved_by_product.get(product, 0)) + 1

	var available_units := 0
	var reserved_units := 0
	var products_in_stock := 0
	var low_stock_products := 0
	var out_of_stock_products := 0
	var preorder_demand := 0
	for product in Catalog.PRODUCTS.size():
		var available: int = maxi(0, int(sim.stock(product)))
		var reserved: int = int(reserved_by_product.get(product, 0))
		var pending: int = int(preorder_by_product.get(product, 0))
		var physical_and_reserved := available + reserved
		available_units += available
		reserved_units += reserved
		preorder_demand += pending
		if available > 0:
			products_in_stock += 1
			if available <= LOW_STOCK_THRESHOLD:
				low_stock_products += 1
		else:
			out_of_stock_products += 1
		per_product.append({
			"id": product,
			"name": str(Catalog.PRODUCTS[product].name),
			"available": available,
			"reserved": reserved,
			"units": physical_and_reserved,
			"preorder_demand": pending,
			"status": _status(available),
		})
	per_product.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_rank := _priority(a)
		var b_rank := _priority(b)
		if a_rank != b_rank:
			return a_rank < b_rank
		if int(a.units) != int(b.units):
			return int(a.units) < int(b.units)
		return str(a.name) < str(b.name)
	)
	return {
		"available_units": available_units,
		"reserved_units": reserved_units,
		"total_units": available_units + reserved_units,
		"products_in_stock": products_in_stock,
		"low_stock_products": low_stock_products,
		"out_of_stock_products": out_of_stock_products,
		"preorder_demand": preorder_demand,
		"products": per_product,
	}

static func build(sim: RefCounted, mobile: bool = false) -> PanelContainer:
	var data := summary(sim)
	var panel := PanelContainer.new()
	panel.name = "DashboardInventoryOverview"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.LINE, 12, 14))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = "Inventory Overview"
	heading.add_theme_font_size_override("font_size", 19)
	content.add_child(heading)
	var note := Label.new()
	note.text = "Low stock is based on %d or fewer available units; reserved units are shown separately." % LOW_STOCK_THRESHOLD
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Style.MUTED)
	content.add_child(note)
	var metrics := GridContainer.new()
	metrics.name = "InventorySummaryMetrics"
	metrics.columns = 3 if mobile else 6
	metrics.add_theme_constant_override("h_separation", 6)
	metrics.add_theme_constant_override("v_separation", 6)
	content.add_child(metrics)
	_add_metric(metrics, "Total Units", _number(data.total_units), Style.TEXT)
	_add_metric(metrics, "Available", _number(data.available_units), Style.GREEN)
	_add_metric(metrics, "Reserved", _number(data.reserved_units), Style.GOLD)
	_add_metric(metrics, "Products In Stock", _number(data.products_in_stock), Style.TEXT)
	_add_metric(metrics, "Low Stock", _number(data.low_stock_products), Style.GOLD)
	_add_metric(metrics, "Out Of Stock", _number(data.out_of_stock_products), Style.RED)
	var demand := Label.new()
	demand.name = "PreorderDemandSummary"
	demand.text = "Pending pre-order demand: %s units" % _number(data.preorder_demand)
	demand.add_theme_font_size_override("font_size", 13)
	demand.add_theme_color_override("font_color", Style.GOLD if data.preorder_demand > 0 else Style.MUTED)
	content.add_child(demand)
	var separator := HSeparator.new()
	content.add_child(separator)
	var table_title := Label.new()
	table_title.text = "Stock by Product"
	table_title.add_theme_font_size_override("font_size", 15)
	content.add_child(table_title)
	var rows: Array = data.products
	var row_limit := MOBILE_ROW_LIMIT if mobile else DESKTOP_ROW_LIMIT
	var visible_count := mini(rows.size(), row_limit)
	for index in visible_count:
		var item: Dictionary = rows[index]
		if mobile:
			_add_mobile_row(content, item)
		else:
			_add_desktop_row(content, item)
	if rows.size() > visible_count:
		var more := Label.new()
		more.text = "%d more products · Open Inventory Management for all stock" % (rows.size() - visible_count)
		more.add_theme_font_size_override("font_size", 12)
		more.add_theme_color_override("font_color", Style.MUTED)
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(more)
	return panel

static func _add_metric(parent: GridContainer, title: String, value: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 8, 7))
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	var caption := Label.new()
	caption.text = title
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", Style.MUTED)
	stack.add_child(caption)
	var amount := Label.new()
	amount.text = value
	amount.add_theme_font_size_override("font_size", 16)
	amount.add_theme_color_override("font_color", color)
	stack.add_child(amount)

static func _add_mobile_row(parent: VBoxContainer, item: Dictionary) -> void:
	var row := PanelContainer.new()
	row.name = "InventoryProductRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", Style.box(Style.INPUT, Style.LINE, 7, 8))
	parent.add_child(row)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	row.add_child(stack)
	var title := Label.new()
	title.text = str(item.name)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Style.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	var details := Label.new()
	details.text = "Available %s  ·  Reserved %s  ·  Pre-orders %s" % [_number(item.available), _number(item.reserved), _number(item.preorder_demand)]
	details.add_theme_font_size_override("font_size", 11)
	details.add_theme_color_override("font_color", Style.MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(details)

static func _add_desktop_row(parent: VBoxContainer, item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "InventoryProductRow"
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name := Label.new()
	name.text = str(item.name)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 13)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name)
	var quantities := Label.new()
	quantities.text = "Available %s  ·  Reserved %s  ·  Pre-orders %s" % [_number(item.available), _number(item.reserved), _number(item.preorder_demand)]
	quantities.size_flags_horizontal = Control.SIZE_SHRINK_END
	quantities.add_theme_font_size_override("font_size", 12)
	quantities.add_theme_color_override("font_color", Style.MUTED)
	quantities.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(quantities)

static func _status(units: int) -> String:
	if units <= 0:
		return "out_of_stock"
	return "low_stock" if units <= LOW_STOCK_THRESHOLD else "in_stock"

static func _priority(item: Dictionary) -> int:
	match str(item.status):
		"low_stock": return 0
		"in_stock": return 1
		_: return 2

static func _number(value: int) -> String:
	var raw := str(value)
	var result := ""
	for index in raw.length():
		if index > 0 and (raw.length() - index) % 3 == 0:
			result += ","
		result += raw[index]
	return result
