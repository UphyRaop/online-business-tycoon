# PR #33 — UI/UX Audit Matrix

**Audit state: INCOMPLETE.** This records verified evidence and explicit gaps; a rendered screen is not considered audited by itself. No production browser testing was possible because Chromium rejects the environment-proxy certificate. Certificate verification was not bypassed.

## Ultra Compact V4 reference tokens

Source inspection of `corporate_theme.gd` and the shared header builder in `main.gd`:

| Token | Current V4 reference |
|---|---|
| Main palette | Navy `#101A29`; page background `#0C121C`; surface/card `#141E2D`; input `#101927`; border `#29384D` / header `#34445B`; text `#EEF3FA`; muted `#A6B5C8`; gold `#E8C58B`; positive `#7CDBB1`; negative `#FF9D9C` |
| Header shape | 1 px border, 9 px radius, 7 px padding (5 px compact landscape), row gaps 3 px (2 px compact landscape) |
| Header typography | Brand 12 px; company 14 px mobile / 15 px desktop; date 12 / 13 px; bank label 11 px; bank amount 13 px; Advance Day 11 / 12 px |
| Header controls | Hamburger 40×40 px (36×34 compact landscape), icon max 20 px; Developer Mode 40×34 px (36×30 compact landscape); day buttons 46×40 desktop/tablet, 34 px high mobile, 30 px compact landscape |
| General control target | Shared theme minimum 48 px high × 44 px wide; header controls intentionally override this for compactness |
| Responsive thresholds | Compact landscape when height ≤450 px; header width changes at 760, 600 and 350 px |

Measurements come from source, not production browser inspection. The hierarchy is semantic: these are reference tokens, not a rule to shrink every content label to header size.

## Screen inventory and coverage

`Typography / spacing / icons / interaction / scroll / responsive` are only marked PASS when the screen received that specific browser inspection. Regression coverage alone is not visual acceptance.

| Screen / destination | Typography | Spacing | Icons | Interaction | Scroll | Responsive | Result / evidence |
|---|---|---|---|---|---|---|---|
| Main Menu / Title | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Local Chromium screenshot and route into new game. Full menu actions unverified. |
| New Game / CEO setup | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Local Chromium input and next-step interaction. |
| Company Registration | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Local Chromium typing, deletion and submission were previously exercised through Godot's `.ime` keyboard bridge; not a full validation audit. |
| Company Selection / switching | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional save tests only; browser journey not performed. |
| Legacy CEO / identity prompt | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Browser coverage absent. |
| Load Game | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Save/load regression coverage only. |
| Save Game / overwrite dialog | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Browser visual/interaction audit absent. |
| Settings | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Settings functional suite only. |
| Dashboard | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Chromium capture; dashboard viewport screenshots cover the requested nine canvas sizes. This does not audit every dashboard action or smaller component. |
| Global header / Advance Day | PARTIAL | PARTIAL | PARTIAL | NOT TESTED | NOT TESTED | PARTIAL | V4 tokens source-audited; header test passes. Full day-advance browser journeys at each size not run. |
| Main navigation drawer | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Local open screenshot and Market route. Non-sticky behavior and all destinations not individually browser-tested in this pass. |
| Market — Buy Inventory Category | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | Browser category selection in desktop and touch-style mobile; existing captures cover category on desktop/mobile/short landscape. |
| Market — Buy Inventory Product | PARTIAL | PARTIAL | N/A (no product icon is rendered in this screen) | PASS (real mouse full-card selection) | PARTIAL | PARTIAL | Targeted correction in this update: full-card selection, selected state, supplier count and landed cost preserved; search minimum reduced 48→40 px and placeholder added. Desktop before/after captures included. Full device-by-device review remains open. |
| Market — Buy Inventory Supplier | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Local browser reached and captured supplier selection; purchase flow incomplete. |
| Market — Buy Inventory Negotiate | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Existing workflow UI suite verifies supplier negotiation rules. Current browser journey did not reach it. |
| Market — Buy Inventory Confirm | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Existing suite verifies purchase calculations/validation; browser interaction not completed. |
| Market — Inbound Inventory | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Test suite covers shipment creation/persistence; browser purchase-to-inbound journey not completed. |
| Market — Supplier Relationships | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional tests only. |
| Market — Supplier Returns and history | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional tests only. |
| Order — Customer Orders | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Regression coverage only. |
| Order — Pre-orders | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Regression coverage only. |
| Order — Returns & Service / Customers | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Customer-service regression coverage only. |
| Business — Company Management | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | No browser audit. |
| Business — Store Management / websites | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional regression coverage only. |
| Business — Inventory Management / My Products | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional regression coverage only. |
| Business — Store Listings | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional product/store coverage only. |
| Business — Store Profitability | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Financial regression coverage only. |
| Marketing — Overview | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Campaign suite only. |
| Marketing — Ads Manager | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Campaign lifecycle suite only. |
| Marketing — Campaign Details | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Campaign suite only. |
| Marketing — Ads Analytics | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Analytics regression coverage only. |
| Finance — Dashboard | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Financial regression coverage only. |
| Finance — Income Statement | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reconciliation tests only. |
| Finance — Balance Sheet | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reconciliation tests only. |
| Finance — Cash Flow Statement | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reconciliation tests only. |
| Finance — Expenses / Transactions | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Finance regression tests only. |
| Profile / achievements | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | CEO profile functional suite only. |
| Profile — Avatar Crop | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Crop behavior suite only; native browser file picker not exercised. |
| Company sale confirmation | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Company-sale functional suites only. |
| Developer Mode access dialog | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Existing local Chromium 390×844 cancel/reopen/unlock sequence and Godot UI coverage. Physical iOS keyboard remains untested by Codex. |
| Developer Mode — Preview Device | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | Preview size logic has automated coverage; browser use of each preset not performed in this pass. |
| Developer Mode — Finance cheats | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Existing browser scroll reached the final Finance action; tool-by-tool changes not exercised here. |
| Developer Mode — Inventory cheats | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | API/UI suites only. |
| Developer Mode — Sales & Orders cheats | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | API/UI suites only. |
| Developer Mode — Marketing cheats | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | API/UI suites only. |
| Developer Mode — Company cheats | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | API/UI suites only. |
| Developer Mode — Time cheats | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | API/UI suites only. |
| Developer Mode — Scenarios | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | API/UI suites only. |
| Developer Mode — Lock / Close | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Existing local browser close coverage; new double-tap unlock guard has a UI regression test. |
| Production HTTPS / all screens | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED | Chromium rejects the environment TLS-inspection certificate. No verification bypass was used; HTTP client success alone is not browser acceptance. |

## Responsive and user-journey coverage

| Viewport | Existing local evidence | This task's actual browser interaction | Result |
|---|---|---|---|
| 1920×1080 | Dashboard capture; viewport/canvas sizing check | No complete route walk | NOT TESTED |
| 1366×768 | Main menu, registration, dashboard, drawer, Market; updated product before/after | New registration → Dashboard → Market → category → product select; no purchase | PARTIAL |
| 1024×768 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 768×1024 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 390×844 | Dashboard and Developer Mode captures; Buy Inventory category capture | Earlier category touch interaction; product flow not repeated | PARTIAL |
| 375×667 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 360×800 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 844×390 | Dashboard and short-landscape Market category captures | No complete route walk | PARTIAL |
| 667×375 | Dashboard and scrolled Market category captures | No complete route walk | PARTIAL |

Canvas dimensions matched the requested viewport and the document had no horizontal overflow in the existing viewport captures. That verifies shell sizing only; it does not establish that every page is visually or interactively correct at those sizes. Chromium mobile emulation is not physical iPhone Safari.

The attempted real browser journey used a disposable profile and reached real supplier data after fresh company registration. The runner stopped before negotiation, purchase confirmation, inbound inventory, save/reload, and other gameplay routes. Those paths remain unverified in browser even where functional suites pass.

## Findings and corrections in this update

| Finding | Severity | Change | Verification |
|---|---|---|---|
| Product selection required a large nested “Select Product” button despite the entire card being the natural selection target. | Medium | Product card is now one keyboard/touch/mouse-accessible Button; selected card gets the gold outline and “Selected” state. Supplier count and landed cost remain shown. | `catalog_flow_ui_test`, `phase33_ui_test`, `phase1_ui_test`, and `supplier_workflow_ui_test`; Chromium click selected the product and displayed the gold outline. |
| Product search reserved a tall shared-form input and showed no placeholder. | Low | Search field minimum height is 40 px; added “Search products” placeholder. | Product UI test verifies the compact field; Chromium before/after screenshots show shorter field. |
| Successful Developer Mode unlock had a short re-entry window while waiting for the Web keyboard to dismiss. | Medium | A pending-unlock guard blocks another access dialog until the console handoff completes. No unlock code, game state, cheats or save behavior changed. | `developer_console_ui_test`: immediate second access request is rejected, pending state clears, active profile remains current. |

## Screenshot evidence

- Previous product step: [before, 1366×768](market-product-before-1366.png)
- Updated product step: [after, 1366×768](market-product-after-1366.png)
- Updated selected product: [gold selected state, 1366×768](market-product-selected-after-1366.png)

All captures are local Release Web export screenshots, not production screenshots.

## Test results and limitations

- Godot 4.7.2 script: **33/33 regression/UI suites passed**, including the added Market card interaction assertions and Developer Mode re-entry guard. `dashboard_inventory_test` still prints the pre-existing shutdown leak warning (2 CanvasItem RIDs, 8 ObjectDB instances, 1 resource) while reporting 0 assertion failures.
- Godot 4.7.2 Release Web export: **PASS** (`index.html`, `index.js`, `index.wasm`, `index.pck` produced).
- Local Chromium, 1366×768 targeted product card: **PASS** for rendered card details, full-card mouse selection, selected outline, and no JavaScript/page errors.
- Full game-wide browser visual audit and all-screen user journeys: **INCOMPLETE**. The routes marked NOT TESTED above remain pending; automated suites do not substitute for those checks.
- Physical iPhone Safari and software keyboard: **NOT TESTED** by Codex.
- Production browser: **BLOCKED** by Chromium `ERR_CERT_AUTHORITY_INVALID` from the environment's TLS inspection CA. No certificate bypass, trust-store alteration, production configuration change, merge, or deployment was made.
