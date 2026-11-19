extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Saves = preload("res://save_store.gd")
const Stores = preload("res://store_manager.gd")
const Storefront = preload("res://storefront.gd")
const Supply = preload("res://supply.gd")
const Advertising = preload("res://advertising.gd")
const CEOProfile = preload("res://ceo_profile.gd")

var failures := 0

func _initialize() -> void:
	var state := Sim.register("QA Founder", "Continuity Labs", "", 0, 0, 0, 4813)
	var sim := Sim.new(state)
	expect(state.stores.is_empty(), "A new company starts with no product destinations")

	var marketplace_error := Stores.create(state, "Continuity Shopee", 0, "Continuity", "", 0)
	var website_platform := Stores.website_platform_index("shopify")
	var website_error := Stores.create(state, "Continuity Website", 1, "Continuity", "continuity.example.test", 0, website_platform)
	var marketplace_id := int(state.stores[0].id)
	var website_id := int(state.stores[1].id)
	expect(marketplace_error.is_empty() and website_error.is_empty(), "Fixtures create an explicit marketplace and paid website")

	var first_price := Catalog.local_cents(state.country, 100.0)
	var second_price := Catalog.local_cents(state.country, 125.0)
	expect(Stores.set_listing(state, marketplace_id, 0, first_price, true) == ""
		and Stores.set_listing(state, website_id, 0, second_price, true) == "",
		"A product can be listed on multiple stores with independent prices")
	expect(Stores.listing(state, marketplace_id, 0).price == first_price
		and Stores.listing(state, website_id, 0).price == second_price,
		"Store listing prices remain scoped to the selected destination")

	expect(Storefront.set_bundle_for_store(state, marketplace_id, 0, 3, 10) == ""
		and Storefront.set_upsell_for_store(state, website_id, 0, [1], 15) == "",
		"Store listings retain their own exclusive bundle or upsell configuration")
	expect(Storefront.offers_for_store(state, marketplace_id, 0).has(1)
		and Storefront.offers_for_store(state, website_id, 0).has(2),
		"Existing per-store offers are readable by the checkout model")

	var supplier := 3
	var quote_a := Supply.negotiate(state, 0, supplier, 20)
	var quote_b := Supply.negotiate(state, 1, supplier, 20)
	expect(quote_a == "" and quote_b == "" and state.quotes.has(0) and state.quotes.has(1),
		"Supplier quotations remain associated with the selected product ID")
	expect(Supply.quote(state, 0, supplier).cost == state.quotes[0][supplier].cost
		and Supply.quote(state, 1, supplier).cost == state.quotes[1][supplier].cost,
		"Comparing offers for one product cannot overwrite another product's negotiated offer")

	var config := {
		"name": "Persistence Check", "store_id": marketplace_id, "product": 0, "platform": 0,
		"objective": 0, "daily_budget": Catalog.local_cents(state.country, 10.0),
		"audience": 0, "bid_strategy": 0, "bid": 0, "creative": 0,
		"start_day": state.day, "end_day": 0,
	}
	expect(Advertising.create(state, config) == "", "Campaign targets a real listed product and store")
	var campaign_id := int(state.advertising.next_campaign) - 1
	expect(Advertising.set_status(state, campaign_id, "paused") == "", "Existing campaign lifecycle can pause a saved campaign")
	sim.advance(1)
	expect(state.advertising.campaigns[campaign_id].status == "paused"
		and int(state.ledger.back().advertising) == 0,
		"Paused campaigns do not consume advertising budget while simulation days advance")
	expect(not state.advertising.history.any(func(record: Dictionary): return int(record.campaign_id) == campaign_id),
		"A campaign paused before delivery has no attributed spending history")

	var profile := CEOProfile.empty("QA Founder")
	profile = CEOProfile.ensure(profile, "QA Founder")
	expect(profile.personal_cash == null and profile.personal_net_worth == null,
		"Legacy CEO profile migration does not fabricate a personal cash balance")

	var path := "user://phase4_cross_cutting_%d.save" % Time.get_ticks_usec()
	var before := state.duplicate(true)
	var saved := Saves.save(state, path)
	var loaded := Saves.load_state(path)
	expect(saved == OK and not loaded.is_empty(), "Combined product, quote, offers, store, and campaign state saves")
	if not loaded.is_empty():
		expect(loaded.stores == before.stores and loaded.quotes == before.quotes
			and loaded.advertising.campaigns == before.advertising.campaigns,
			"Save/load preserves independent listings, product quotations, and campaign state")
		expect(loaded.cash == before.cash and Saves.valid(loaded),
			"Cross-feature save migration preserves corporate cash and validates the full balance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Phase 4 product/campaign/save integration: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
