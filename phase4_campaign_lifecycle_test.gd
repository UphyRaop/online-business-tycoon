extends SceneTree

const Sim = preload("res://simulation.gd")
const Stores = preload("res://store_manager.gd")
const Ads = preload("res://advertising.gd")
const Saves = preload("res://save_store.gd")
const AdsView = preload("res://advertising_view.gd")

var failures := 0

func _initialize() -> void:
	test_stop_reactivation_and_archival()
	test_scheduled_completion()
	test_expired_campaign_rejection()
	test_legacy_campaign_migration()
	test_number_formatting()
	print("Phase 4 campaign lifecycle: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func campaign_game() -> Sim:
	var state := Sim.register("Ari", "Lifecycle Labs", "", 0, 0, 0, 903)
	var create_error := Stores.create(state, "Lifecycle Market", 0, "Lifecycle", "", 0)
	var store_id := int(state.stores.back().id)
	var listing_error := Stores.set_listing(state, store_id, 0, 15000, true)
	expect(create_error.is_empty() and listing_error.is_empty(), "Campaign fixture has a valid active destination and listed product")
	return Sim.new(state)

func campaign_config(state: Dictionary, end_day: int = 0) -> Dictionary:
	return {
		"name": "Lifecycle Test", "store_id": int(state.stores[0].id), "product": 0, "platform": 0,
		"objective": 3, "daily_budget": 5000, "start_day": 1, "end_day": end_day,
		"audience": 0, "bid_strategy": 0, "bid": 0, "creative": 0,
	}

func test_stop_reactivation_and_archival() -> void:
	var sim := campaign_game()
	var state: Dictionary = sim.state
	expect(Ads.create(state, campaign_config(state)) == "", "Create a campaign for lifecycle checks")
	var id := int(state.advertising.next_campaign) - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 990
	Ads.simulate_day(sim, rng)
	var prior_history: Array = state.advertising.history.duplicate(true)
	expect(not prior_history.is_empty() and int(prior_history.back().spend) > 0, "Active campaign records its first day's spend and metrics")
	var configuration_before_stop: Dictionary = state.advertising.campaigns[id].duplicate(true)
	expect(Ads.set_status(state, id, "stopped") == "", "Manual stop is a reversible state before a campaign schedule ends")
	var stop_cash := int(state.cash)
	Ads.simulate_day(sim, rng)
	expect(int(state.cash) == stop_cash and state.advertising.history.size() == prior_history.size(), "Stopped campaign has no additional delivery or spend")
	expect(Ads.set_status(state, id, "active") == "", "Eligible stopped campaign can be reactivated")
	configuration_before_stop.status = "active"
	expect(state.advertising.campaigns[id] == configuration_before_stop, "Reactivation preserves campaign configuration and historical performance")
	expect(Ads.aggregate_range(state, id, 1, state.day).spend == int(prior_history.back().spend), "Reactivation preserves historical spend")
	var current_day := int(state.day)
	sim.advance(1)
	var records: Array = state.advertising.history.filter(func(record: Dictionary): return int(record.campaign_id) == id)
	expect(records.size() == prior_history.size() + 1 and int(records.back().day) == current_day,
		"Reactivation resumes on the current simulation day without generating spend for skipped days")
	var history_before_archive: Array = state.advertising.history.duplicate(true)
	expect(Ads.archive(state, id) == "" and bool(state.advertising.campaigns[id].deleted), "Deletion uses a persistent archive flag")
	var archived_error := Ads.set_status(state, id, "active")
	Ads.simulate_day(sim, rng)
	expect(not archived_error.is_empty() and state.advertising.history.size() == history_before_archive.size() and int(state.ledger.back().advertising) == 0,
		"Archived campaigns cannot be reactivated or spend further advertising budget")
	expect(state.advertising.history == history_before_archive, "Archival preserves all campaign metrics and attribution history")
	expect(Saves.valid(state), "Archived campaign remains save-valid")
	var path := "user://phase4_campaign_archive_%d.save" % Time.get_ticks_usec()
	expect(Saves.save(state, path) == OK and Saves.load_state(path) == state, "Archived flag and campaign history survive Save & Load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_scheduled_completion() -> void:
	var sim := campaign_game()
	var state: Dictionary = sim.state
	expect(Ads.create(state, campaign_config(state, 1)) == "", "Create a campaign with an inclusive one-day schedule")
	var id := int(state.advertising.next_campaign) - 1
	sim.advance(1)
	var spend_at_end := int(state.ledger[0].advertising)
	expect(spend_at_end > 0 and state.advertising.campaigns[id].status == "active", "Campaign delivers on its scheduled end day")
	sim.advance(1)
	var cash_at_completion := int(state.cash)
	var history_at_completion: int = state.advertising.history.size()
	expect(state.advertising.campaigns[id].status == "completed", "Campaign moves to Completed after the inclusive end date passes")
	expect(Ads.set_status(state, id, "active") != "" and int(state.cash) == cash_at_completion
		and state.advertising.history.size() == history_at_completion,
		"Completed campaign cannot be reactivated or spend after its schedule ends")
	expect(Ads.duplicate_stopped(state, id) == "" and state.advertising.campaigns[state.advertising.next_campaign - 1].status == "draft",
		"Completed campaign history can be duplicated into a new Draft")
	expect(Saves.valid(state), "Completed and duplicated campaigns pass save validation")

func test_expired_campaign_rejection() -> void:
	var sim := campaign_game()
	var state: Dictionary = sim.state
	expect(Ads.create(state, campaign_config(state, 1)) == "", "Create an expiring campaign")
	var id := int(state.advertising.next_campaign) - 1
	expect(Ads.set_status(state, id, "stopped") == "", "Stop the campaign before its scheduled end")
	sim.advance(2)
	expect(Ads.set_status(state, id, "active") != "" and state.advertising.campaigns[id].status == "completed",
		"Stopped campaign whose schedule expired becomes Completed and cannot be reactivated")
	expect(Saves.valid(state), "Expired campaign remains save-valid")

func test_legacy_campaign_migration() -> void:
	var sim := campaign_game()
	var state: Dictionary = sim.state
	expect(Ads.create(state, campaign_config(state)) == "", "Create a valid campaign before simulating a legacy save")
	var id := int(state.advertising.next_campaign) - 1
	state.advertising.campaigns[id].erase("deleted")
	var loaded: Dictionary = state.duplicate(true)
	Sim.upgrade(loaded)
	expect(loaded.get("advertising", {}).get("campaigns", {}).get(id, {}).get("deleted", false) == false,
		"Legacy campaigns migrate as not archived without losing history")
	loaded.advertising.campaigns[id].status = "stopped"
	loaded.advertising.campaigns[id].end_day = 1
	var sim_loaded := Sim.new(loaded)
	sim_loaded.advance(2)
	expect(loaded.advertising.campaigns[id].status == "completed" and Ads.set_status(loaded, id, "active") != "",
		"Legacy expired stopped campaigns keep history, migrate to Completed, and cannot resume or spend")
	expect(Saves.valid(loaded), "Migrated legacy campaign remains save-valid")

func test_number_formatting() -> void:
	expect(AdsView._count(12450) == "12,450" and AdsView._count(125600) == "125,600" and AdsView._count(1250) == "1,250",
		"Clicks, impressions, and purchases use thousands separators")
	expect(Ads.ctr_percent(1250, 12613) > 9.90 and Ads.cpm_cents(125000, 10000) == 12500,
		"CTR/CPM calculations preserve actual metrics for fixed-precision display")
