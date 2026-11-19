# Phase 4 Financial Management Plan

## Current accounting behavior and assumptions

- Completed orders settle cash when delivered; revenue is recognized on delivery.
- Pre-order deposits are cash received and remain a customer-deposit liability until delivery or refund.
- Supplier orders are paid immediately. Warehouse inventory and supplier-direct goods in transit are already tracked separately.
- Advertising, overhead, shipping, refunds, store setup, and recurring store expenses are recorded in the existing daily ledger.
- There is no accounts-receivable schedule, supplier credit, or borrowing model. Phase 4 must not invent payment terms, loan rates, credit limits, or default rules.
- Any forecast in the first milestone is explicitly informational: it subtracts known next-day fixed costs from current cash and excludes future sales, variable spending, supplier orders, and expected settlement cash.

## Milestones

1. **Financial overview and expense history** — summarize the existing ledger in a dashboard; show income statement, balance sheet, cash flow, trends, categorized ledger costs, and the known-fixed-cost cash estimate. Receivables and payables are shown as zero with the current immediate-settlement rules explained. No simulation or save-schema changes.
2. **Cash settlement events** — if gameplay later adds delayed settlement, represent receivables/payables as explicit dated obligations with deterministic cash events and save migration. Keep existing instant-settlement behavior until settlement policy is approved.
3. **Accrual-aware statements** — separate settlement events from recognized revenue/expense, preserve historical ledger values, and add reconciliation invariants before enabling any delayed settlement.
4. **Company financing** — add loans or credit only after defining eligibility, limits, rate, term, repayment timing, delinquency, and insolvency effects. These are new gameplay policies and are intentionally not guessed.
5. **Expense controls and capital assets** — build on validated expense categories; classify capital expenditures only when the simulation has supported assets and depreciation rules. Preserve existing store setup treatment unless that policy is explicitly defined.

Milestones 1 and subsequent safe reporting work can ship without changing company saves because they derive values from the existing ledger. Milestones that create new balances or obligations require versioned migration and model tests.

## User-Approved Supplier Credit Addendum — 2026-11-19

The later approved “UX Overhaul, Save Isolation, Supplier Credit & Multi-Agent QA” request explicitly authorizes deterministic, trust-based supplier credit. This approval supersedes this plan's earlier statement that supplier credit is not approved. It does not authorize changing existing immediate cash-purchase behavior, customer settlement timing, or unrelated loan/financing policies.

Supplier credit remains in development and is not complete until its trust thresholds, credit-limit formula, due dates, late consequences, payable accounting, repayment behavior, save migration, and financial statement reconciliation are documented and tested. Credit-funded inventory must not reduce cash at receipt; it must create a payable. Repayments must reduce both cash and the payable exactly once. Keep the approved limits and terms conservative and deterministic, and preserve the existing cash-purchase path.
