# Company sale valuation and personal proceeds

All monetary amounts use the sold company's own simulation currency and integer minor units. A CEO who sells companies in different currencies gets separate currency-tagged ledger entries; this feature does not assume an exchange rate or combine currencies into one balance.

## Earnings valuation

For companies with at least 180 operating days and positive normalized operating profit:

```text
Enterprise Value = max(0, Normalized Annual Operating Profit × Adjusted Multiple)
Equity Proceeds = max(0, Enterprise Value + Positive Company Cash - Overdraft - Customer Deposits - Explicit Debt)
```

Normalized profit and revenue use the trailing 365 days. With 180–364 operating days, the observed period is annualized; less than 180 days uses the conservative fallback. Daily operating profit is winsorized around its median using three median absolute deviations before annualization, preventing one unusual day from dominating the earnings estimate. If daily profit has zero median deviation, exceptional days are capped to the median. Revenue growth compares exactly adjacent 90-day periods, counting the boundary day once. Enterprise Value represents the going concern and includes its operating assets and working capital, including inventory, so inventory is shown in the preview but is not added a second time. Positive company cash is added separately; no cash reserve policy is assumed. A negative bank balance is represented by overdraft liability.

The adjusted multiple starts at 2.5 and is bounded to 0.5–5.0. It reflects operating-history stability (up to +0.5), 90-day revenue growth (up to ±0.5, when two full 90-day periods exist), reputation (−0.5 to +0.5), customer satisfaction (−0.5 to +0.5), and risk discounts for recorded bankruptcy, negative cash, or a loss-making observation. These modifiers are deterministic and use the existing simulation fields.

## Conservative fallback

If a company lacks 180 operating days or has no positive normalized operating profit:

```text
Enterprise Value = 10% × Normalized Annual Net Sales
Equity Proceeds = max(0, Enterprise Value + Positive Company Cash + Verified Inventory + Goods in Transit - Overdraft - Customer Deposits - Explicit Debt)
```

In this path, the revenue amount is goodwill only. Positive company cash, inventory, and goods in transit are separately verified assets and each is added once. Sales and inventory are read from company ledger records; no missing history is fabricated. The game does not separately record non-operating assets, so none are assumed. No debt model currently creates loans, so explicit debt defaults to zero and only an actual stored debt balance is considered. Receivable/payable or settlement behavior is not changed.

## Sale accounting

Completing a sale marks the CEO's company reference as sold and preserves its save path and historical ledger. It appends exactly one `company_sale:<company_id>` entry to the CEO's personal finance ledger with amount, currency, country, and valuation snapshot. The company save and corporate cash are not modified or transferred. The profile's legacy `personal_cash` and `personal_net_worth` remain unknown (`null`); sale proceeds are reported only as known, currency-separated credits.

The module API is `CompanySale.preview(state)`, `CompanySale.sell(profile, state)`, and `CompanySale.known_sale_proceeds_by_currency(profile)`. `CEOProfile.owned_companies(profile)` filters active ownership while `CEOProfile.company_index` continues to find archived sold companies.
