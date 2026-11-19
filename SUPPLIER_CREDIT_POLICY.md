# Supplier Credit Policy

Supplier credit is an optional, interest-free trade-payables facility. It does not change the existing cash-purchase path.

- Eligibility requires supplier trust of at least 40, five fully settled supplier purchases, positive company cash and equity, positive trailing-30-day net sales, and no overdue payable to that supplier.
- The credit line is the lower of 15% of positive equity, 25% of trailing-30-day net sales, and USD 500 converted to the company's base currency, multiplied by supplier trust as a percentage. Available credit subtracts the supplier's outstanding payables.
- Each payable is due seven in-game days after purchase. There is no interest or late fee. An overdue obligation reduces supplier trust by 20 once; credit remains unavailable until overdue balances are settled.
- Successful cash purchases add eight trust and count as settled. Timely credit repayment adds six trust and counts as settled. Late repayment does not earn trust.
- Credit-funded purchases create inventory or goods in transit and an equal payable without reducing cash. Repayments reduce cash and the payable once. Returns reduce only the payable linked to the returned purchase up to its remaining balance; any refund beyond that balance is paid in cash.
- Mixed cash/credit purchases allocate inbound freight proportionally to financed value for cash-flow reporting. Legacy ledger entries without credit fields retain zero-valued behavior.

The rules are deterministic and covered by supplier-credit model/workflow tests. Changes require corresponding model tests and documentation updates.
