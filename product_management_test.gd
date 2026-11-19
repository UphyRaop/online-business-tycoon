extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Stores = preload("res://store_manager.gd")
const Supply = preload("res://supply.gd")
const Storefront = preload("res://storefront.gd")
const Products = preload("res://products_view.gd")
const Saves = preload("res://save_store.gd")

var failures := 0

func _initialize() -> void:
	test_product_management_and_quotes()
	print("Product management and quotations: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func test_product_management_and_quotes() -> void:
	var state := Sim.register("Ari Founder", "North Star Co", "North Star", 0, 0, 1, 731)
	var sim := Sim.new(state)
	var product := 0
	var supplier := int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	expect(Products.owned_products(state).is_empty(), "New company product portfolio begins empty")
	var err := Stores.create(state, "Market One", 0, "North Star", "", 0)
	var market_one := int(state.stores.back().id)
	err += Stores.create(state, "Market Two", 0, "North Star", "", 1)
	var market_two := int(state.stores.back().id)
	expect(err.is_empty() and state.stores.size() == 2, "Company can manage multiple marketplace stores")

	var purchase_error := sim.buy(product, supplier, 4)
	for shipment in state.inbound:
		shipment.eta = state.day
		shipment.arrival = state.day
	Supply.receive(sim)
	expect(purchase_error.is_empty() and sim.stock(product) == 4, "A supplier purchase produces owned, received inventory")
	err = Stores.set_listing(state, market_one, product, 25000, true)
	err += Stores.set_listing(state, market_two, product, 31000, false)
	expect(err.is_empty() and Products.product_status(state, product, sim.stock(product)) == "Active",
		"Product can be actively listed at one store while drafted at another")
	expect(Products.owned_products(state).has(product) and Products.listed_store_names(state, product).size() == 1,
		"My Products derives store-specific listing associations without duplicating product inventory")
	expect(int(Stores.listing(state, market_one, product).price) == 25000 and int(Stores.listing(state, market_two, product).price) == 31000,
		"Store listing prices are independent")

	var unpublish_error := Stores.set_listing(state, market_one, product, 25000, false)
	expect(unpublish_error.is_empty() and Products.product_status(state, product, sim.stock(product)) == "Draft",
		"Unpublishing a listing moves the product into Draft status")
	var publish_error := Stores.set_listing(state, market_one, product, 25000, true)
	expect(publish_error.is_empty() and Products.product_status(state, product, sim.stock(product)) == "Active",
		"A drafted listing can be published again")
	expect(Products.product_status(state, product, 0) == "Out of Stock",
		"Listed products without available inventory appear in Out of Stock")

	var bundle_error := Storefront.set_bundle_for_store(state, market_one, product, 3, 10)
	var bundle := Storefront.offers_for_store(state, market_one, product)
	expect(bundle_error.is_empty() and bundle.has(1), "Bundle settings can be attached to a selected product and store")
	var other_store_offer := Storefront.offers_for_store(state, market_two, product)
	expect(not other_store_offer.has(1), "Store-specific offers do not leak to another store")
	var upsell_error := Storefront.set_upsell_for_store(state, market_one, product, [1], 5)
	var exclusive := Storefront.offers_for_store(state, market_one, product)
	expect(upsell_error.is_empty() and not exclusive[1].enabled and exclusive[2].enabled,
		"Product listing preserves existing Bundle/Upsell exclusivity")

	var quote_error := Supply.negotiate(state, product, supplier, Supply.negotiation_minimum(supplier))
	expect(quote_error.is_empty() and state.quotes.get(product, {}).has(supplier),
		"A product catalogue quotation is stored against its selected product and supplier")
	expect(not state.quotes.get(1, {}).has(supplier), "A product quotation cannot attach to a different product")
	var quote := Supply.quote(state, product, supplier)
	expect(int(quote.discount) > 0 and int(quote.expires) >= int(state.day),
		"A requested supplier quotation returns valid negotiated terms")

	var save_path := "user://product_management_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(state, save_path) == OK, "Store-specific listings and supplier quotations pass save validation")
	var loaded := Saves.load_state(save_path)
	expect(loaded.get("quotes", {}).get(product, {}).has(supplier)
		and Stores.listing(loaded, market_one, product).price == 25000
		and Stores.listing(loaded, market_two, product).price == 31000
		and Storefront.offers_for_store(loaded, market_one, product).has(2),
		"Save/load preserves quotations, independent store prices, and the selected listing offer")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
