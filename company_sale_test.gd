extends SceneTree

const CompanySale = preload("res://company_sale.gd")
const CEO = preload("res://ceo_profile.gd")
const Sim = preload("res://simulation.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	test_profitable_sale_and_persistence()
	test_loss_and_debt_valuation()
	test_verified_assets_fallback()
	test_revenue_growth_windows()
	test_outlier_profit_normalization()
	test_legacy_profile_migration()
	test_currency_separation()
	print("Company sale domain: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func test_profitable_sale_and_persistence() -> void:
	var state := active_state("Northwind Trading", 0, true)
	state.ledger[1].purchases = 7212345
	var profile := CEO.register_company(CEO.ensure({}, "Ari Founder"), state)
	var before_cash := int(state.cash)
	var before_report := Sim.new(state).report(365, int(state.day) - 1)
	var preview := CompanySale.preview(state)
	expect(preview.error.is_empty() and preview.enterprise_value > 0 and preview.equity_value > 0,
		"A profitable operating company receives a positive earnings-based valuation")
	expect(preview.annual_operating_profit > 0 and preview.multiple >= 0.5 and preview.multiple <= 5.0
		and preview.inventory_value == 12345
		and preview.equity_value == preview.enterprise_value + preview.positive_company_cash - preview.liabilities,
		"Valuation uses normalized operating history, bounds its multiple, and does not add inventory twice")
	var sale := CompanySale.sell(profile, state)
	expect(sale.error.is_empty() and sale.record.amount == preview.equity_value,
		"Confirmed sale records the previewed equity proceeds exactly once")
	var sold_profile: Dictionary = sale.profile
	var index := CEO.company_index(sold_profile, str(state.company_id))
	expect(index >= 0 and sold_profile.companies[index].ownership_status == "sold"
		and not CEO.owns_company(sold_profile, str(state.company_id)),
		"Sold company remains in the CEO archive but is no longer owned")
	expect(sold_profile.personal_finance_ledger.size() == 1
		and sold_profile.personal_finance_ledger[0].currency == "MYR"
		and sold_profile.personal_finance_ledger[0].amount == sale.record.amount,
		"Sale proceeds are credited to a currency-tagged personal ledger, not corporate cash")
	expect(sold_profile.personal_cash == null and sold_profile.personal_net_worth == null
		and state.cash == before_cash,
		"Sale does not invent prior CEO balances or transfer proceeds into company cash")
	var duplicate := CompanySale.sell(sold_profile, state)
	expect(not duplicate.error.is_empty() and sold_profile.personal_finance_ledger.size() == 1,
		"Duplicate sale is rejected without duplicating personal proceeds")
	expect(Sim.new(state).report(365, int(state.day) - 1) == before_report,
		"Company sale preserves the sold company's financial statement history")
	var path := "user://company_sale_profile_test.json"
	expect(CEO.save_profile(sold_profile, path) == OK, "Sale proceeds and archive status save successfully")
	var loaded := CEO.load_profile(path)
	expect(not loaded.is_empty() and loaded.personal_finance_ledger.size() == 1
		and loaded.companies[index].ownership_status == "sold" and CEO.valid(loaded),
		"Sale status and personal proceeds survive profile reload")
	_cleanup(path)

func test_loss_and_debt_valuation() -> void:
	var distressed := active_state("Distressed Retail", 0, false)
	distressed.bankrupt = true
	distressed.cash = -10000
	distressed.ledger[0].capital = 0
	distressed.ledger[0].sales = 0
	var loss_value := CompanySale.preview(distressed)
	expect(loss_value.used_fallback and loss_value.annual_operating_profit == 0 and loss_value.equity_value == 0,
		"A bankrupt company with no verified assets or sales has zero equity value")
	var profitable := active_state("Leveraged Services", 1, true)
	var without_debt := CompanySale.preview(profitable)
	profitable.debt = 250000
	var with_debt := CompanySale.preview(profitable)
	expect(with_debt.debt == 250000 and with_debt.equity_value == without_debt.equity_value - 250000,
		"Recorded debt reduces equity proceeds dollar-for-dollar without altering enterprise value")

func test_verified_assets_fallback() -> void:
	var state := Sim.register("Ari Founder", "Asset Holdings", "", 0, 1, 0, 941)
	state.products[0] = {"product_id": "obt.electronics.wireless_earbuds", "supplier": 0,
		"supplier_id": "supplier.economy", "price": 10000, "listed": false, "lots": [
		{"units": 3, "cost": 1200, "freight": 200, "quality": 1.0}], "channel_mask": 3}
	state.ledger[0].purchases = 3600
	var value := CompanySale.preview(state)
	var expected := int(state.cash) + 3600
	expect(value.used_fallback and value.inventory_value == 3600 and value.equity_value == expected,
		"Fallback adds verified inventory and cash once, without adding inventory to an earnings multiple")

func test_revenue_growth_windows() -> void:
	var state := Sim.register("Ari Founder", "Growth Test", "", 0, 1, 0, 832)
	for index in 180:
		var row: Dictionary = state.ledger[0] if index == 0 else Sim.entry()
		row.sales = 1000 if index < 90 else 2000
		if index == 89: row.sales = 10000000
		if index > 0: state.ledger.append(row)
	state.day = 181
	var result := CompanySale.preview(state)
	var expected_previous := 89.0 * 1000.0 + 10000000.0
	var expected_latest := 90.0 * 2000.0
	var expected_growth := (expected_latest - expected_previous) / expected_previous
	expect(is_equal_approx(float(result.revenue_growth), expected_growth),
		"Revenue growth uses adjacent, non-overlapping 90-day windows with the boundary day counted once")

func test_outlier_profit_normalization() -> void:
	var state := Sim.register("Ari Founder", "Outlier Test", "", 0, 1, 0, 833)
	for index in 240:
		var row: Dictionary = state.ledger[0] if index == 0 else Sim.entry()
		row.sales = 10000
		row.cogs = 10000
		if index == 120:
			row.sales = 10000000
			row.cogs = 0
		if index > 0: state.ledger.append(row)
	state.day = 241
	var result := CompanySale.preview(state)
	expect(result.used_fallback and result.annual_operating_profit == 0 and result.enterprise_value == roundi(float(result.annual_revenue) * CompanySale.FALLBACK_REVENUE_MULTIPLE),
		"A single unusually profitable day is winsorized and cannot establish an earnings multiple")

func test_legacy_profile_migration() -> void:
	var legacy := CEO.empty("Legacy CEO")
	legacy.schema_version = 1
	legacy.erase("personal_finance_ledger")
	legacy.personal_cash = null
	legacy.personal_net_worth = null
	var state := Sim.register("Legacy CEO", "Legacy Company", "", 0, 1, 0, 101)
	legacy = CEO.register_company(legacy, state)
	for index in legacy.companies.size(): legacy.companies[index].erase("ownership_status")
	legacy.schema_version = 1
	var migrated := CEO.migrate_profile(legacy)
	expect(migrated.schema_version == CEO.VERSION and migrated.personal_finance_ledger.is_empty()
		and migrated.personal_cash == null and migrated.personal_net_worth == null
		and migrated.companies[0].ownership_status == "owned",
		"Legacy profiles migrate with existing ownership and no fabricated personal cash or sale history")
	var path := "user://company_sale_legacy_profile_test.json"
	expect(CEO.save_profile(legacy, path) == OK and CEO.load_profile(path).companies.size() == 1,
		"Version 1 CEO profiles remain save/load compatible after migration")
	_cleanup(path)

func test_currency_separation() -> void:
	var myr_company := active_state("MYR Company", 0, true)
	var usd_company := active_state("USD Company", 1, true)
	var profile := CEO.ensure({}, "Ari Founder")
	profile = CEO.register_company(profile, myr_company)
	profile = CEO.register_company(profile, usd_company)
	var first := CompanySale.sell(profile, myr_company)
	var second := CompanySale.sell(first.profile, usd_company)
	var proceeds := CompanySale.known_sale_proceeds_by_currency(second.profile)
	expect(second.error.is_empty() and proceeds.has("MYR") and proceeds.has("USD")
		and int(proceeds.MYR) == first.record.amount and int(proceeds.USD) == second.record.amount,
		"Personal proceeds remain separated by each company's currency without undocumented FX conversion")
	expect(second.profile.personal_cash == null,
		"Multi-currency sale history does not become a misleading single-currency personal cash balance")

func active_state(name: String, country: int, profitable: bool) -> Dictionary:
	var state := Sim.register("Ari Founder", name, "", country, 1, 0, 773)
	if profitable:
		for index in 240:
			var row: Dictionary = state.ledger[0] if index == 0 else Sim.entry()
			row.sales = 100000
			row.cogs = 30000
			row.fees = 5000
			row.channels[0].sales = row.sales
			row.channels[0].cogs = row.cogs
			row.channels[0].fees = row.fees
			if index > 0: state.ledger.append(row)
		state.day = 241
		state.cash = 2000000
		state.reputation = 85
		state.satisfaction = 92
	return state

func _cleanup(path: String) -> void:
	for suffix in [".tmp", ".bak", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
