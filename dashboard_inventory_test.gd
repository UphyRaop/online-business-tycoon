extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const InventoryOverview = preload("res://dashboard_inventory.gd")
const PortraitFrame = preload("res://portrait_frame.gd")
const Stores = preload("res://store_manager.gd")

var failures := 0

func _initialize() -> void:
	test_inventory_counts()
	test_mobile_layout()
	test_portrait_frame()
	print("Dashboard inventory and portrait: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func test_inventory_counts() -> void:
	var sim := Sim.new(Sim.register("Ari Founder", "Ari Trading", "", 0, 1, 0, 991))
	sim.add_stock(0, _lot(1000))
	sim.add_stock(1, _lot(0))
	sim.add_stock(2, _lot(1))
	sim.add_stock(3, _lot(0))
	sim.add_stock(4, _lot(2))
	sim.add_stock(5, _lot(998))
	var store_error := Stores.create(sim.state, "Ari Marketplace", 0, "Shopee", "", 0)
	var store_id := int(sim.state.stores.back().id)
	var listing_error := Stores.set_listing(sim.state, store_id, 0, 12500, true)
	sim.state.active_orders = [1, 2, 3]
	sim.state.orders = {
		1: {"status": "queued", "items": [{"product": 0, "cost": 4000}, {"product": 3, "cost": 2500}, {"product": 1, "cost": 3000, "direct_supplier": 0}]},
		2: {"status": "shipped", "preorder": true, "items": [{"product": 1, "awaiting_stock": true}, {"product": 1, "awaiting_stock": true}]},
		3: {"status": "queued", "preorder": true, "items": [{"product": 2, "awaiting_stock": true}]},
	}
	var before_cash := int(sim.state.cash)
	var before_units := sim.stock(0) + sim.stock(2) + sim.stock(4) + sim.stock(5)
	var result := InventoryOverview.summary(sim)
	var reserved_only := {}
	for product_row in result.products:
		if int(product_row.id) == 3:
			reserved_only = product_row
	expect(result.total_units == 2003 and result.available_units == 2001 and result.reserved_units == 2,
		"The dashboard distinguishes available warehouse units from warehouse units reserved for active orders")
	expect(result.products_in_stock == 4 and result.low_stock_products == 2 and result.out_of_stock_products == 2
		and reserved_only.get("status", "") == "out_of_stock" and int(reserved_only.get("reserved", 0)) == 1,
		"Stock totals include only the six business-owned products, exclude unrelated catalogue items, and show reservations separately")
	expect(result.preorder_demand == 3,
		"Pending pre-order demand counts only awaiting-stock units and excludes supplier-direct fulfillment")
	var published_row: Dictionary = result.products.filter(func(item): return int(item.id) == 0).front()
	expect(store_error.is_empty() and listing_error.is_empty() and published_row.get("listing_status", "") == "Published"
		and published_row.get("stock_status", "") == "In Stock" and result.products.size() == 6,
		"Dashboard rows show actual owned listing status and do not include catalogue-only products")
	expect(sim.state.cash == before_cash and sim.stock(0) + sim.stock(2) + sim.stock(4) + sim.stock(5) == before_units,
		"Building inventory metrics does not change company cash or stock")
	expect(InventoryOverview._number(1200345) == "1,200,345",
		"Dashboard inventory counts use grouped number formatting")

func test_mobile_layout() -> void:
	var sim := Sim.new(Sim.register("Ari Founder", "Ari Trading", "", 0, 1, 0, 992))
	var panel := InventoryOverview.build(sim, true)
	var metrics := panel.find_child("InventorySummaryMetrics", true, false) as GridContainer
	expect(metrics != null and metrics.columns == 3,
		"Mobile inventory KPI cards use a compact three-column grid")
	expect(panel.find_child("PreorderDemandSummary", true, false) is Label,
		"The mobile overview exposes pending pre-order demand")
	root.add_child(panel)
	await process_frame
	expect(panel.size.x >= 0 and panel.get_child_count() == 1,
		"Mobile overview builds as a single responsive panel without separate wide table columns")
	panel.queue_free()
	await process_frame
	var empty_sim := Sim.new(Sim.register("Ari Founder", "Empty Trading", "", 0, 1, 0, 994))
	var empty_panel := InventoryOverview.build(empty_sim, true)
	expect(InventoryOverview.summary(empty_sim).products.is_empty()
		and empty_panel.find_child("EmptyProductState", true, false) is Label
		and empty_panel.find_child("InventoryBrowseProductCatalogue", true, false) == null,
		"Companies with no products show the precise empty state without fabricating catalogue stock rows")
	empty_panel.queue_free()
	await process_frame

func test_portrait_frame() -> void:
	var frame := PortraitFrame.new()
	var portrait_image := Image.create(120, 160, false, Image.FORMAT_RGBA8)
	portrait_image.fill(Color(0.2, 0.4, 0.8, 1.0))
	var portrait_texture := ImageTexture.create_from_image(portrait_image)
	frame.set_portrait(portrait_texture, 150.0)
	expect(is_equal_approx(frame.custom_minimum_size.x / frame.custom_minimum_size.y, 0.75),
		"The CEO avatar frame preserves a 3:4 portrait ratio")
	expect(frame.portrait.name == "CEOAvatar" and frame.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"The framed avatar keeps the existing uploaded-photo crop presentation")
	expect(frame.get_theme_stylebox("panel").get_border_width(SIDE_LEFT) == 2,
		"The portrait frame uses a subtle theme-accent border")
	expect(frame.portrait.get_parent() == frame.portrait_padding
		and frame.portrait_padding.get_parent() == frame
		and frame.portrait_padding.get_theme_constant("margin_left") == 6
		and frame.portrait_padding.get_theme_constant("margin_right") == 6
		and frame.portrait_padding.get_theme_constant("margin_top") == 6
		and frame.portrait_padding.get_theme_constant("margin_bottom") == 6,
		"The image stays inside a consistent inset on every side of the gold frame")
	var displayed_portrait := frame.portrait.texture.get_image()
	expect(displayed_portrait != null
		and is_equal_approx(displayed_portrait.get_pixel(0, 0).a, 0.0)
		and is_equal_approx(displayed_portrait.get_pixel(299, 0).a, 0.0)
		and is_equal_approx(displayed_portrait.get_pixel(0, 399).a, 0.0)
		and is_equal_approx(displayed_portrait.get_pixel(299, 399).a, 0.0)
		and displayed_portrait.get_pixel(150, 0).a > 0.99,
		"The display-only image mask rounds all four corners while keeping its straight frame edges opaque")
	expect(portrait_texture.get_size() == Vector2(120, 160)
		and frame.portrait.texture.get_size() == Vector2(300, 400)
		and is_equal_approx(frame.portrait.texture.get_size().x / frame.portrait.texture.get_size().y, 0.75),
		"A portrait photo displays in the frame without modifying its original texture")
	var landscape_image := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	landscape_image.fill(Color(0.8, 0.4, 0.2, 1.0))
	var landscape_texture := ImageTexture.create_from_image(landscape_image)
	frame.set_portrait(landscape_texture, 150.0)
	expect(landscape_texture.get_size() == Vector2(160, 120)
		and frame.portrait.texture.get_size() == Vector2(300, 400)
		and is_equal_approx(frame.portrait.texture.get_size().x / frame.portrait.texture.get_size().y, 0.75),
		"A landscape source is center-cropped for display while its source remains unchanged")
	var square_image := Image.create(120, 120, false, Image.FORMAT_RGBA8)
	var square_texture := ImageTexture.create_from_image(square_image)
	frame.set_portrait(square_texture, 150.0)
	expect(square_texture.get_size() == Vector2(120, 120)
		and frame.portrait.texture.get_size() == Vector2(300, 400)
		and is_equal_approx(frame.portrait.texture.get_size().x / frame.portrait.texture.get_size().y, 0.75),
		"A square legacy source is center-cropped for display without changing stored image data")
	var jpeg_image := Image.create(120, 160, false, Image.FORMAT_RGBA8)
	jpeg_image.fill(Color(0.7, 0.3, 0.2, 1.0))
	var decoded_jpeg := Image.new()
	decoded_jpeg.load_jpg_from_buffer(jpeg_image.save_jpg_to_buffer())
	var jpeg_texture := ImageTexture.create_from_image(decoded_jpeg)
	frame.set_portrait(jpeg_texture, 150.0)
	var displayed_jpeg := frame.portrait.texture.get_image()
	expect(displayed_jpeg.get_format() == Image.FORMAT_RGBA8
		and is_equal_approx(displayed_jpeg.get_pixel(0, 0).a, 0.0)
		and displayed_jpeg.get_pixel(150, 0).a > 0.99
		and decoded_jpeg.get_format() != Image.FORMAT_RGBA8,
		"JPEG photos gain display-only transparency at the rounded corners without changing the decoded source")
	frame.set_portrait(null, 150.0)
	expect(frame.portrait.texture == null,
		"Removing an avatar restores the empty frame without stale image content")
	frame.free()

func _lot(units: int) -> Dictionary:
	return {"units": units, "cost": 1000, "freight": 0, "quality": 0.9,
		"supplier": 0, "supplier_id": Catalog.supplier_id(0), "supplier_name": Catalog.SUPPLIERS[0].name}
