extends "res://phase1_ui_test.gd"

const CEOProfile = preload("res://ceo_profile.gd")
const CompanySale = preload("res://company_sale.gd")
const Sim = preload("res://simulation.gd")
const Games = preload("res://game_store.gd")

func run() -> void:
	if OS.get_environment("OBT_ISOLATED_TEST_PROFILE") != "1" or not Slots.latest().is_empty() or not Games.list_games().is_empty():
		push_error("Run company sale UI checks with a fresh isolated profile.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	app = Main.instantiate()
	root.add_child(app)
	create_new_game_for_test("Nora Founder", "Northstar Goods")
	var first_id := str(app.sim.state.company_id)
	var cash_before := int(app.sim.state.cash)
	var report_before: Dictionary = app.sim.report(1)
	var second_state := Sim.register("Nora Founder", "Northstar Home", "", 0, 1, 0, 107)
	app.ceo_profile = CEOProfile.register_company(app.ceo_profile, second_state)
	expect(Saves.save(second_state, CEOProfile.company_path_for_game(app.active_game_id, str(second_state.company_id))) == OK
		and Games.update_game_profile(app.active_game_id, app.ceo_profile) == OK,
		"A second owned company can be archived before a company sale")
	var second_id := str(second_state.company_id)
	expect(Slots.write_for_game(app.active_game_id, 1, app.sim.state, app.ceo_profile) == OK, "A manual pre-sale save remains intact as historical company data")
	press("Business")
	expect(has_label("Sell Company") and has_label("Estimated equity sale proceeds")
		and has_label("Outstanding liabilities"), "Company Management shows a transparent valuation before a sale")
	press("Sell Company")
	expect(is_instance_valid(app.confirmation), "Selling a company requires an explicit confirmation")
	if is_instance_valid(app.confirmation): app.confirmation.confirmed.emit()
	await process_frame
	expect(app.screen == "Company Selection" and app.sim == null,
		"Selling the active company returns to company selection")
	var first_index := CEOProfile.company_index(app.ceo_profile, first_id)
	expect(first_index >= 0 and not CEOProfile.owns_company(app.ceo_profile, first_id)
		and app.ceo_profile.personal_finance_ledger.size() == 1,
		"Sale removes company ownership and records personal proceeds exactly once")
	var archived_state := Saves.load_state(CEOProfile.company_path_for_game(app.active_game_id, first_id))
	expect(not archived_state.is_empty() and int(archived_state.cash) == cash_before
		and Sim.new(archived_state).report(1) == report_before,
		"Sold-company cash and financial statements remain preserved in its archive")
	expect(Slots.read_for_game(app.active_game_id, Slots.AUTOSAVE).is_empty(), "Autosave no longer resumes a sold active company")
	app.request_load(Slots.read_for_game(app.active_game_id, 1))
	expect(app.screen == "Company Selection" and app.sim == null,
		"An older manual save cannot reopen a sold company")
	app.switch_company(second_id)
	expect(app.sim != null and str(app.sim.state.company_id) == second_id,
		"Company switching still opens another owned company's separate save")
	press("Business")
	press("Sell Company")
	if is_instance_valid(app.confirmation): app.confirmation.confirmed.emit()
	await process_frame
	expect(app.screen == "Company Selection" and CEOProfile.owned_companies(app.ceo_profile).is_empty()
		and has_button("Start a New Company"),
		"The final company sale offers a path to start another company")
	expect(not has_button("Delete Company") and has_label("Sold businesses remain in your career history and cannot be reopened or deleted."),
		"Sold company histories remain retained and are excluded from company deletion actions")
	var retained_sold_profile: Dictionary = CEOProfile.load_game_profile(app.active_game_id)
	var sold_cleanup: Dictionary = Games.delete_company_data(app.active_game_id, first_id)
	expect(str(sold_cleanup.get("error", "")).contains("Sold company records")
		and CEOProfile.company_index(retained_sold_profile, first_id) >= 0
		and not Saves.load_state(CEOProfile.company_path_for_game(app.active_game_id, first_id)).is_empty(),
		"Company deletion rejects sold businesses and preserves their historical sale record and archive")
	var persisted := CEOProfile.load_game_profile(app.active_game_id)
	expect(CEOProfile.valid(persisted) and persisted.personal_finance_ledger.size() == 2
		and not CEOProfile.owns_company(persisted, first_id) and not CEOProfile.owns_company(persisted, second_id),
		"Sold ownership and CEO sale proceeds persist through browser-local profile reload")
	expect(CompanySale.known_sale_proceeds_by_currency(persisted).has("MYR"),
		"Personal sale proceeds remain currency-tagged")
	app.queue_free()
	await process_frame
	print("Company sale UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
