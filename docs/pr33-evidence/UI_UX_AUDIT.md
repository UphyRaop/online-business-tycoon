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
| Main Menu — Continue / Choose Company / Load / New Game | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Only New Game was taken through registration; other entry actions and company-switch isolation remain unverified in browser. |
| Main Menu — Delete Game confirmation | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Deletion safeguards have functional coverage; browser confirmation and cancel behavior not exercised. |
| New Game / CEO setup | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Local Chromium input and next-step interaction. |
| Company Registration | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Local Chromium typing, deletion and submission were previously exercised through Godot's `.ime` keyboard bridge; not a full validation audit. |
| Company Selection / switching | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional save tests only; browser journey not performed. |
| Legacy CEO / identity prompt | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Browser coverage absent. |
| Load Game / slot picker | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Opened slot picker after browser reload. Manual Slot 1 persisted in one isolated same-profile test, but an independent QA run showed it empty after reload. Conflicting result remains unresolved; do not mark save/load PASS. |
| Save Game / overwrite dialog | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Normal UI saved a disposable company to Manual Slot 1 and showed its timestamp. The slot survived reload/reopen in one Chromium profile but disappeared in another QA profile. Overwrite/delete dialogs and repeated persistence remain unverified. Evidence: [saved state](manual-save-slot1-before-reload-qa.png), [empty after independent reload](manual-save-slot1-empty-after-reload-qa.png), [present after root same-profile reload](manual-save-slot1-present-after-reload-qa.png). |
| Settings | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Settings screenshot and route at 1366×768; Edit Display Settings action not tested. |
| Settings — Edit Display dialog | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Dialog, keyboard behavior and validation not tested in browser. |
| Dashboard | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Chromium capture; dashboard viewport screenshots cover the requested nine canvas sizes. This does not audit every dashboard action or smaller component. |
| Global header / Advance Day | PARTIAL | PARTIAL | PARTIAL | NOT TESTED | NOT TESTED | PARTIAL | V4 tokens source-audited; header test passes. Full day-advance browser journeys at each size not run. |
| Main navigation drawer | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Local open screenshot and Market route. Non-sticky behavior and all destinations not individually browser-tested in this pass. |
| Market — Buy Inventory Category | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | Browser category selection in desktop and touch-style mobile; existing captures cover category on desktop/mobile/short landscape. |
| Market — Buy Inventory Product | PARTIAL | PARTIAL | N/A (no product icon is rendered in this screen) | PASS (real mouse full-card selection) | PARTIAL | PARTIAL | Targeted correction in this update: full-card selection, selected state, supplier count and landed cost preserved; search minimum reduced 48→40 px and placeholder added. Desktop before/after captures included. Full device-by-device review remains open. |
| Market — Buy Inventory Supplier | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Disposable local Chromium journey selected the actual AliExpress supplier for Wireless Earbuds and continued to negotiation at 1366×768; supplier economics are covered by functional suites. No all-viewport review. |
| Market — Buy Inventory Negotiate | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Browser requested a 0% offer and continued; this exercises the real interaction but not discounted acceptance/rejection outcomes. Negotiation model is covered by suites. Screenshot: [negotiation](buy-negotiate-browser-1366.png). |
| Market — Buy Inventory Confirm | PARTIAL | PARTIAL | NOT TESTED | PASS at desktop and Chromium touch | PASS at desktop wheel and 390×844 touch swipe | PARTIAL | The Confirm content scrolls while Back/Confirm remain fixed; an emulated touch swipe reached the summary's lower fields, then Confirm opened the dialog and Place Order completed a disposable mobile purchase. The new scroll handler also passes a Godot touch-drag assertion. Physical iPhone Safari remains untested; other viewport purchase journeys remain open. Evidence: [desktop after fix](buy-confirm-after-stepper-fix-1366.png), [mobile top](buy-confirm-mobile-top-390.png), [scrolled lower summary](buy-confirm-mobile-touch-scrolled-390.png), [confirmation dialog](buy-confirm-mobile-touch-action-390.png). |
| Market — Purchase confirmation dialog | PARTIAL | PARTIAL | NOT TESTED | PASS at desktop and 390×844 Chromium touch | N/A | PARTIAL | Confirmation text was reviewed and the mobile Place Order action completed once. Cancel behavior and all requested viewport sizes remain unverified. Evidence: [mobile dialog](buy-confirm-mobile-touch-action-390.png). |
| Market — Inbound Inventory | PARTIAL | PARTIAL | NOT TESTED | PASS at desktop and 390×844 Chromium touch | PARTIAL | PARTIAL | Both disposable journeys transitioned to Inbound Stock and displayed PO-0001, product, supplier, quantity, ETA, possible delay, MYR 33.65 total and In Transit status. Mobile screenshot: [inbound shipment](buy-inbound-mobile-touch-390.png). Save/reload and other viewports remain untested. |
| Market — Supplier Relationships | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional tests only. |
| Market — Supplier Returns and history | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional tests only. |
| Order — Customer Orders / Fulfilment | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Local Chromium screenshots and route navigation at 1366×768 and 390×844. Empty QA company had no orders; fulfilment controls not exercised. |
| Order — Pre-orders | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Empty-state screenshot and route navigation at desktop and mobile; no preorder fixture to test actions. |
| Order — Returns & Service / Customers | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Empty-state screenshot and route navigation at desktop and mobile; no cases/customer records to exercise. |
| Business — Company Management | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Local screenshot, edit-details form opened, and wheel scroll reached Sell Company at 1366×768; no edit or sale submitted. Page heading is reduced by this update from 30 px to 26 px desktop (24 px mobile). |
| Business — Store Management / websites | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Empty-state screenshot, Owned Stores: 0 verified, new-store form opened but not submitted. Desktop only. |
| Business — Inventory Management / My Products | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Empty-state and Product Catalogue route screenshot at desktop. Populated editing/listing untested. |
| Business — Store Listings | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Functional product/store coverage only. |
| Business — Store Profitability | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Empty-state and Store Management action screenshot at desktop. Profitability with a store remains untested. |
| Marketing — Overview | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Local Chromium before/after screenshots and navigation at desktop. Combined CTR/CPM value wrapped before; separate labeled rows now keep CTR and currency-formatted CPM on one line each. No JavaScript error or document overflow after the fix. |
| Marketing — Ads Manager | PARTIAL | PARTIAL | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | Empty-list screenshot and navigation at desktop. Campaign creation/management not verified; fresh QA company had no stores/products. |
| Marketing — Campaign Details | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Campaign suite only. |
| Marketing — Ads Analytics | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Local route screenshot and mouse-wheel scroll at desktop; no completed days/campaigns, so populated charts and filters were unavailable. |
| Finance — Dashboard | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Local empty-company screenshot and route click at desktop; financial regression suites cover reconciliation. |
| Finance — Statements selector / Income Statement | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | NOT TESTED | PARTIAL | Statements screen and selector route opened; no completed activity. Population/value behavior not browser-tested. |
| Finance — Balance Sheet | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reconciliation tests only; statement selector option not independently selected in browser. |
| Finance — Cash Flow Statement | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reconciliation tests only; statement selector option not independently selected in browser. |
| Finance — Expenses / Transactions | PARTIAL | PARTIAL | NOT TESTED | PARTIAL | PARTIAL | PARTIAL | Empty-state screenshot and mouse-wheel scroll at desktop; no transaction records for detail inspection. |
| Profile / achievements | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | Profile screenshot at desktop and mobile, edit action opened on mobile, scroll works. Fresh profile uses default avatar; achievements and populated progression not deeply inspected. |
| Profile — Avatar Crop | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Crop behavior suite only; native browser file picker not exercised. |
| Company sale confirmation | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Company-sale functional suites only. |
| Advance Day confirmation dialog | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Automated header tests cover controls; browser confirmation, repeat-tap behavior and event warning were not exercised. |
| Generic operation confirmations / notices / error states | NOT TESTED | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | NOT TESTED | Purchase confirmation was exercised. Other confirmations, notifications, tooltips, empty/error/loading states remain unreviewed per route. |
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
| 1366×768 | Main menu, registration, dashboard, drawer, Market; updated product and Confirm/Inbound screenshots | New registration → Dashboard → Market → Category → Product → AliExpress → 0% negotiation → Confirm → one purchase → Inbound Stock | PARTIAL |
| 1024×768 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 768×1024 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 390×844 | Dashboard and Developer Mode captures; Buy Inventory category, scrolled Confirm and Inbound Stock captures | Touch-style new company → Market → Category → Product → Supplier → Negotiate → touch-scroll Confirm → confirmation dialog → one purchase → Inbound Stock | PARTIAL |
| 375×667 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 360×800 | Dashboard capture and canvas sizing check | No complete route walk | NOT TESTED |
| 844×390 | Dashboard and short-landscape Market category captures | No complete route walk | PARTIAL |
| 667×375 | Dashboard and scrolled Market category captures | No complete route walk | PARTIAL |

Canvas dimensions matched the requested viewport and the document had no horizontal overflow in the existing viewport captures. That verifies shell sizing only; it does not establish that every page is visually or interactively correct at those sizes. Chromium mobile emulation is not physical iPhone Safari.

The desktop purchase journey used disposable browser data and completed one 1366×768 purchase through Inbound Stock. After the mobile scroll correction, a separate 390×844 Chromium touch journey scrolled the Confirm summary, submitted the confirmation dialog, and completed one purchase into Inbound Stock. Both had no JavaScript error or document-level horizontal overflow. Discounted negotiation outcomes, purchase save/reload, physical iPhone touch behavior, and all-screen/all-viewport journeys remain open.

### Save persistence discrepancy

Two isolated Chromium runs produced conflicting Manual Slot 1 results. Independent QA captured the slot as saved with a timestamp, then showed it empty after same-profile reload. A separate root run saved Manual Slot 1, immediately reloaded the same-origin page in the same persistent Chromium profile, reopened Load Saves, and saw both Autosave and Manual Slot 1 still present. No production data was used. Since the failure was not reproduced in the second run, this is an unresolved intermittent/test-path discrepancy rather than a confirmed code defect. Manual-slot persistence is **PARTIAL / UNRESOLVED**, not PASS. More repeated browser-profile cycles are required before acceptance.

## Findings and corrections in this update

| Finding | Severity | Change | Verification |
|---|---|---|---|
| Product selection required a large nested “Select Product” button despite the entire card being the natural selection target. | Medium | Product card is now one keyboard/touch/mouse-accessible Button; selected card gets the gold outline and “Selected” state. Supplier count and landed cost remain shown. | `catalog_flow_ui_test`, `phase33_ui_test`, `phase1_ui_test`, and `supplier_workflow_ui_test`; Chromium click selected the product and displayed the gold outline. |
| Product search reserved a tall shared-form input and showed no placeholder. | Low | Search field minimum height is 40 px; added “Search products” placeholder. | Product UI test verifies the compact field; Chromium before/after screenshots show shorter field. |
| Confirm step's Buy Max balance metric was compressed beside its action. | Medium | The Buy Max row and balance metric now claim remaining horizontal width; Buy Max keeps a fixed compact touch size. | `catalog_flow_ui_test` asserts expansion flags; fresh browser screenshot shows the full label, MYR balance, and compact button. A new browser purchase reached Inbound Stock. |
| Buy Inventory's inner ScrollContainer accepted desktop wheel scrolling, but the mobile Confirm summary did not respond to touch drags. | High | Added a small `ScrollContainer` subclass to consume in-bounds screen drags after a 10 px deadzone and update only the inner vertical scrollbar. Passive workflow descendants allow the gesture to reach it; the footer remains a sibling outside the scroll viewport. | Godot test injects a screen touch/drag and verifies the scroll offset changes. Chromium 390×844 touch journey scrolls to the lower summary, leaves Back/Confirm reachable, opens the confirmation dialog and completes one disposable purchase. No horizontal overflow or JS errors. Physical iPhone Safari is still NOT TESTED. |
| Successful Developer Mode unlock had a short re-entry window while waiting for the Web keyboard to dismiss. | Medium | A pending-unlock guard blocks another access dialog until the console handoff completes. No unlock code, game state, cheats or save behavior changed. | `developer_console_ui_test`: immediate second access request is rejected, pending state clears, active profile remains current. |

## Screenshot evidence

- Previous product step: [before, 1366×768](market-product-before-1366.png)
- Updated product step: [after, 1366×768](market-product-after-1366.png)
- Updated selected product: [gold selected state, 1366×768](market-product-selected-after-1366.png)
- Buy Inventory Confirm, 390×844 Chromium touch: [top](buy-confirm-mobile-top-390.png) · [lower summary after swipe](buy-confirm-mobile-touch-scrolled-390.png) · [confirmation dialog](buy-confirm-mobile-touch-action-390.png) · [Inbound Stock after purchase](buy-inbound-mobile-touch-390.png)
- Company Management: [before title-size refinement](routes/company-management-before-title-refinement.png) · [after title-size refinement](routes/company-management-after-title-1366.png)
- Marketing Overview: [before KPI correction](routes/marketing-overview-before-kpi-fix-1366.png) · [after KPI correction](routes/marketing-overview-after-kpi-fix-1366.png)
- Other local route captures: [Business, Marketing, Finance, Orders, Profile and Settings screenshots](routes/)

All captures are local Release Web export screenshots, not production screenshots.

## Test results and limitations

- Godot 4.7.2 script: **33/33 regression/UI suites passed**, including the added Market card interaction assertions and Developer Mode re-entry guard. `dashboard_inventory_test` still prints the pre-existing shutdown leak warning (2 CanvasItem RIDs, 8 ObjectDB instances, 1 resource) while reporting 0 assertion failures.
- Godot 4.7.2 Release Web export: **PASS** (`index.html`, `index.js`, `index.wasm`, `index.pck` produced).
- Local Chromium, 1366×768 targeted product card: **PASS** for rendered card details, full-card mouse selection, selected outline, and no JavaScript/page errors.
- Local Chromium, 390×844 emulated touch: **PASS** for Confirm-step swipe scrolling, keeping the footer fixed, using the confirmation action after scrolling, and completing one disposable purchase to Inbound Stock. This is browser emulation, not physical iPhone Safari testing.
- Full game-wide browser visual audit and all-screen user journeys: **INCOMPLETE**. The routes marked NOT TESTED above remain pending; automated suites do not substitute for those checks.
- Physical iPhone Safari and software keyboard: **NOT TESTED** by Codex.
- Production browser: **BLOCKED** by Chromium `ERR_CERT_AUTHORITY_INVALID` from the environment's TLS inspection CA. No certificate bypass, trust-store alteration, production configuration change, merge, or deployment was made.
