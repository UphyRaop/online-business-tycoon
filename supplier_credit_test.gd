extends SceneTree

const Sim = preload("res://simulation.gd")
const Catalog = preload("res://catalog.gd")
const Supply = preload("res://supply.gd")
const Credit = preload("res://supplier_credit.gd")
const Saves = preload("res://save_store.gd")
const FinanceManagement = preload("res://finance_management.gd")

var failures := 0

func _initialize() -> void:
	test_supplier_credit()
	print("Supplier credit and trust: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func test_supplier_credit() -> void:
	var sim := Sim.new(Sim.register("Ari Founder", "North Star Co", "North Star", 0, 0, 1, 841))
	var state: Dictionary = sim.state
	var supplier: int = int(Catalog.SUPPLIER_SELECTION_INDICES[0])
	var initial_cash := int(state.cash)
	var upfront_preview := Supply.purchase_breakdown(state, 0, supplier, 1)
	var cash_error := sim.buy(0, supplier, 1)
	expect(cash_error.is_empty() and int(state.cash) == initial_cash - int(upfront_preview.get("total", 0))
		and int(state.ledger.back().credit_purchases) == 0,
		"Existing upfront purchasing still deducts the exact landed cost immediately and records no credit")
	expect(int(Credit.relationship(state, supplier).trust) == 8 and int(Credit.relationship(state, supplier).settled_purchase_count) == 1,
		"Successful upfront trades increase supplier trust and settled trade history")
	for purchase_id in range(2, 6):
		Credit.record_upfront_purchase(state, supplier, purchase_id)
	var opening_sales := Catalog.local_cents(state.country, 50000.0)
	state.cash += opening_sales
	state.ledger[0].sales += opening_sales
	var before_credit_cash := int(state.cash)
	var eligibility := Credit.eligibility(state, supplier)
	expect(eligibility.eligible and int(eligibility.trust) == 40 and int(eligibility.settled_purchases) == 5
		and int(eligibility.available) > 0,
		"Five settled purchases, trust threshold, sales, and positive company equity unlock a bounded credit limit")

	var preview := Supply.purchase_breakdown(state, 0, supplier, 1)
	var next_purchase_before := int(state.next_purchase)
	var purchases_before := int(state.ledger.back().purchases)
	var too_large := Credit.purchase_on_credit(state, 0, supplier, Supply.maximum_order_quantity(supplier))
	expect(not str(too_large.get("error", "")).is_empty() and int(state.next_purchase) == next_purchase_before
		and int(state.ledger.back().purchases) == purchases_before,
		"Credit orders over the trust-based line are rejected without shipment or accounting mutations")
	expect(str(preview.get("error", "")).is_empty(), "Selected product/supplier returns a valid landed-cost purchase preview")

	var accepted := Credit.purchase_on_credit(state, 0, supplier, 1)
	expect(str(accepted.get("error", "")).is_empty(), "Eligible stock may be purchased on supplier credit")
	if str(accepted.get("error", "")).is_empty():
		var obligation: Dictionary = accepted.obligation
		var total := int(obligation.principal)
		var report := sim.report(state.day)
		expect(int(state.cash) == before_credit_cash and int(state.ledger.back().credit_purchases) == total
			and int(state.ledger.back().purchases) == purchases_before + total and Credit.open_payables(state) == total,
			"Credit receipt adds goods-in-transit inventory and an equal payable without reducing cash (cash %d/%d, credit %d, purchases %d, payable %d, total %d)" % [int(state.cash), before_credit_cash, int(state.ledger.back().credit_purchases), int(state.ledger.back().purchases), Credit.open_payables(state), total])
		expect(int(report.supplier_payables) == total and report.assets == report.overdraft + report.customer_deposits
			+ report.supplier_payables + report.equity_capital + report.retained and report.closing_cash == state.cash,
			"Balance sheet, cash, inventory, retained earnings, and supplier payables reconcile after credit purchase")
		expect(Credit.validate(state), "Supplier credit schema passes domain validation after creating an obligation")

		var half := maxi(1, total / 2)
		var first := Credit.repay(state, int(obligation.id), half, "test-partial-repay")
		var after_first_cash := int(state.cash)
		var duplicate := Credit.repay(state, int(obligation.id), half, "test-partial-repay")
		expect(str(first.get("error", "")).is_empty() and int(first.balance) == total - half
			and int(state.cash) == before_credit_cash - half and str(duplicate.get("error", "")).length() > 0
			and int(state.cash) == after_first_cash,
			"Partial repayment reduces cash/payable once and an identical request ID is idempotently rejected")
		var second := Credit.repay(state, int(obligation.id), total - half, "test-final-repay")
		expect(str(second.get("error", "")).is_empty() and int(second.balance) == 0 and Credit.open_payables(state) == 0
			and int(state.cash) == before_credit_cash - total and int(Credit.relationship(state, supplier).trust) == 46,
			"Final on-time repayment settles the payable, reduces cash, and increases trust once")
		expect(int(state.ledger.back().supplier_repayments) == total and sim.report(state.day).supplier_payables == 0,
			"Repayment ledger and balance-sheet payable snapshot match the settled amount")
		expect(Credit.validate(state), "Fully paid supplier-credit history passes domain validation")
		var invalid_supplier_id: Dictionary = state.duplicate(true)
		invalid_supplier_id.supplier_credit.obligations[0].supplier_id = "supplier.unknown"
		expect(not Credit.validate(invalid_supplier_id), "Supplier-credit validation rejects unknown supplier identities")
		var invalid_payment_owner: Dictionary = state.duplicate(true)
		invalid_payment_owner.supplier_credit.payments[0].supplier = (supplier + 1) % Catalog.SUPPLIERS.size()
		expect(not Credit.validate(invalid_payment_owner), "Supplier-credit validation rejects payments assigned to a different supplier")
		expect(Saves.valid(state), "Credit purchase and repayments remain compatible with the existing save validator")
		var save_path := "user://supplier_credit_%d.save" % Time.get_ticks_usec()
		expect(Saves.save(state, save_path) == OK, "Company state containing supplier-credit records saves")
		var loaded := Saves.load_state(save_path)
		expect(Credit.validate(loaded) and loaded.supplier_credit.payments.size() == 2
			and loaded.supplier_credit.obligations[0].balance == 0,
			"Save/load preserves trust, payable, and payment history")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# A separate company gets independent supplier trust even within the same CEO profile.
	var other := Sim.new(Sim.register("Ari Founder", "Second Co", "Second Co", 0, 0, 1, 842))
	expect(int(Credit.relationship(other.state, supplier).trust) == 0,
		"Supplier trust is scoped to the company save and does not leak between companies")

	test_late_repayment_and_credit_suspension(supplier)
	test_credit_return_adjustment(supplier)

func test_late_repayment_and_credit_suspension(supplier: int) -> void:
	var sim := Sim.new(Sim.register("Ari Founder", "Late Co", "Late Co", 0, 0, 1, 843))
	var state: Dictionary = sim.state
	for id in range(1, 6): Credit.record_upfront_purchase(state, supplier, id)
	var sales := Catalog.local_cents(state.country, 50000.0)
	state.cash += sales
	state.ledger[0].sales += sales
	var result := Credit.purchase_on_credit(state, 0, supplier, 1)
	expect(str(result.get("error", "")).is_empty(), "Eligible company creates a supplier payable with explicit due date")
	if str(result.get("error", "")).is_empty():
		var obligation: Dictionary = result.obligation
		var trust_before := int(Credit.relationship(state, supplier).trust)
		sim.advance(Credit.PAYMENT_TERM_DAYS + 1)
		var relation := Credit.relationship(state, supplier)
		expect(bool(state.supplier_credit.obligations[0].late_event_recorded)
			and int(relation.trust) == trust_before - Credit.LATE_TRUST_PENALTY,
			"Missed due date records one overdue event and applies the trust penalty once")
		Credit.process_due(state)
		expect(int(Credit.relationship(state, supplier).trust) == trust_before - Credit.LATE_TRUST_PENALTY
			and state.supplier_credit.events.filter(func(event): return event.type == "late").size() == 1,
			"Repeated due processing cannot duplicate late penalties or events")
		expect(not Credit.eligibility(state, supplier).eligible,
			"Overdue supplier debt suspends additional credit purchases")
		var late_payment := Credit.repay(state, int(obligation.id), int(obligation.balance), "late-final-payment")
		expect(str(late_payment.get("error", "")).is_empty() and int(late_payment.balance) == 0
			and int(Credit.relationship(state, supplier).late_repayments) == 1
			and int(Credit.relationship(state, supplier).trust) == trust_before - Credit.LATE_TRUST_PENALTY,
			"Late payable remains repayable without restoring trust or duplicating the due-date penalty")
		expect(Credit.validate(state) and Saves.valid(state), "Late debt and repayment remain valid save data")

func test_credit_return_adjustment(supplier: int) -> void:
	var sim := Sim.new(Sim.register("Ari Founder", "Return Co", "Return Co", 0, 0, 1, 844))
	var state: Dictionary = sim.state
	for id in range(1, 6): Credit.record_upfront_purchase(state, supplier, id)
	var sales := Catalog.local_cents(state.country, 50000.0)
	state.cash += sales
	state.ledger[0].sales += sales
	var first := Credit.purchase_on_credit(state, 0, supplier, 2)
	expect(str(first.get("error", "")).is_empty(), "Credit-financed inventory can be returned after supplier receipt")
	if not str(first.get("error", "")).is_empty(): return
	var second := Credit.purchase_on_credit(state, 0, supplier, 1)
	expect(str(second.get("error", "")).is_empty(), "A second order receives its own independent payable")
	if not str(second.get("error", "")).is_empty(): return
	var first_purchase_id := int(first.purchase.purchase_id)
	var second_purchase_id := int(second.purchase.purchase_id)
	for batch in state.inbound:
		batch.arrival = int(state.day)
	Supply.receive(sim)
	expect(int(sim.stock(0)) == 3 and int(sim.product_state(0).lots[0].purchase_id) == first_purchase_id
		and str(sim.product_state(0).lots[0].payment_method) == "credit",
		"Received lots preserve supplier purchase ID and credit origin for accurate returns")
	var first_obligation: Dictionary = state.supplier_credit.obligations[0].duplicate(true)
	var second_obligation: Dictionary = state.supplier_credit.obligations[1].duplicate(true)
	var part := maxi(1, int(first_obligation.principal) / 2)
	var payment := Credit.repay(state, int(first_obligation.id), part, "return-test-partial-payment")
	expect(str(payment.get("error", "")).is_empty(), "Credit payable may be partially repaid before a supplier return")
	if not str(payment.get("error", "")).is_empty(): return
	var cash_before_return := int(state.cash)
	var stock_before_return := sim.stock(0)
	var preview := Supply.preview_return(state, 0, supplier, 1)
	var return_result := Supply.return_stock(state, 0, supplier, 1)
	expect(str(return_result.get("error", "")).is_empty(), "Returning a credit-funded unit records a supplier return")
	if not str(return_result.get("error", "")).is_empty(): return
	var record: Dictionary = return_result.record
	var adjustment := mini(int(preview.refund), int(first_obligation.principal) - part)
	var cash_refund := int(preview.refund) - adjustment
	expect(sim.stock(0) == stock_before_return - 1
		and int(state.cash) == cash_before_return + cash_refund,
		"The return removes one unit and applies the refund to its payable before any excess is paid as cash")
	expect(int(record.get("supplier_credit_adjustments", 0)) == adjustment
		and int(state.ledger.back().supplier_credit_adjustments) == adjustment
		and int(state.ledger.back().supplier_refunds) == int(preview.refund)
		and int(state.ledger.back().inventory_returns) == int(preview.landed_cost),
		"Return ledger separates total supplier refund from noncash payable adjustment and landed inventory removed")
	var first_after: Dictionary = state.supplier_credit.obligations[0]
	var second_after: Dictionary = state.supplier_credit.obligations[1]
	expect(int(first_after.balance) == int(first_obligation.principal) - part - adjustment
		and int(second_after.balance) == int(second_obligation.balance)
		and int(Credit.open_payables(state)) == int(first_after.balance) + int(second_after.balance),
		"Credit return changes only the matching purchase payable, preserving unrelated supplier obligations")
	var report := sim.report(state.day)
	expect(int(report.closing_cash) == int(state.cash)
		and int(report.assets) == int(report.overdraft + report.customer_deposits + report.supplier_payables + report.equity_capital + report.retained),
		"Cash flow and balance sheet reconcile after a partial repayment and credit-funded supplier return")
	var dashboard := FinanceManagement.dashboard(state, report)
	expect(int(dashboard.payables) == int(report.supplier_payables),
		"The financial dashboard reports outstanding supplier credit payables after returns")
	var cash_after_return := int(state.cash)
	var adjustment_total := int(state.ledger.back().supplier_credit_adjustments)
	var duplicate := Credit.record_return_adjustment(state, supplier, 0, first_purchase_id, int(preview.refund), int(record.id))
	expect(bool(duplicate.get("duplicate", false)) and int(state.cash) == cash_after_return
		and int(state.ledger.back().supplier_credit_adjustments) == adjustment_total,
		"Retrying the same return adjustment cannot duplicate cash or reduce another payable")
	expect(Credit.validate(state) and Saves.valid(state), "Credit return adjustments remain valid and save-compatible")

	var legacy := Sim.new(Sim.register("Ari Founder", "Legacy Return Co", "Legacy Return", 0, 0, 1, 845))
	var legacy_cash := int(legacy.state.cash)
	legacy.add_stock(0, {"units": 1, "cost": 1000, "freight": 100, "quality": 0.9,
		"supplier": supplier, "supplier_id": Catalog.supplier_id(supplier), "supplier_name": Catalog.SUPPLIERS[supplier].name})
	var legacy_preview := Supply.preview_return(legacy.state, 0, supplier, 1)
	var legacy_return := Supply.return_stock(legacy.state, 0, supplier, 1)
	expect(str(legacy_return.get("error", "")).is_empty() and int(legacy.state.cash) == legacy_cash + int(legacy_preview.refund)
		and int(legacy.state.ledger.back().supplier_credit_adjustments) == 0,
		"Legacy and cash-purchased supplier returns retain their existing cash refund behavior")
