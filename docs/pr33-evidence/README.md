# PR #33 verification evidence

## Environment

- Branch: `uiux-buy-footer-and-polish`
- Export: Godot 4.7.2 Web, served locally at `http://localhost:8060/`
- Browser: Chromium with certificate checks enabled
- QA data: isolated browser profile `/tmp/obt-pr33-qa-profile`; company `PR33 QA Retail`, CEO `QA Founder`. No production save or origin was used.

## Test results

- **Godot regression/UI suites:** 33/33 passed after the changes in this PR. `dashboard_inventory_test` retains pre-existing shutdown leak warnings (2 CanvasItem RIDs, 8 ObjectDB objects, 1 resource); its assertions pass.
- **Web export:** release export completed and Chromium started it with no page errors during the viewport captures.
- **Registration text entry:** PASS. Godot Web's LineEdit is backed by its hidden `.ime` contenteditable; Playwright `.fill()` does not send text through Godot's keyboard path. The working test method was to focus the visible Godot field, type with `.ime.pressSequentially()`, delete with Backspace, then click Continue/Register. Text appeared in the Godot fields and normal registration completed. This is an automation method limitation, not a confirmed user-facing input defect.
- **Same-origin persistence:** PASS for the QA company. Closing and reopening Chromium with the same profile restored the saved company and dashboard.
- **Buy Inventory browser screens:** Category, Product, Supplier, and Negotiate were captured from the running Web game. The automated Godot UI suite completes quotation, quantity increments, Buy Max, insufficient-funds rejection, confirmation, single shipment creation, ledger debit, and save/load. A complete browser-driven purchase through Confirm and Inbound was not completed; coordinate-based Playwright mouse/touch actions did not reliably target subsequent controls. This is unresolved browser interaction coverage, not evidence that the controls themselves are defective.
- **Developer Mode:** existing Godot UI/API suites pass. The production-like release browser did not reliably open the access dialog under coordinate automation, so browser unlock/tool interaction remains unverified.
- **Production site:** not tested in this pass. Prior PR investigation recorded Chromium `ERR_CERT_AUTHORITY_INVALID`; certificate verification must stay enabled. No merge or deployment was performed.

## Findings and corrections in this update

| Screen/area | Finding | Severity | Correction | Verification |
| --- | --- | --- | --- | --- |
| Buy Inventory category | Category cards omitted the live product count required by the approved flow. | Low | Added catalogue-derived product counts to every category card. | Catalogue UI test checks all category cards have an icon and a product count; actual Web screenshot shows the counts. |
| Buy Inventory footer | Footer geometry had assertions only for presence; it was not checked at every workflow stage or short landscape sizes. | Medium | Added bounds, visibility, no-outer-scroll, and short-landscape assertions for Category, Product, Supplier, Negotiate, and Confirm. | `catalog_flow_ui_test`: 0 failures; Chromium wheel scrolling at 667×375 reveals cards while the footer remains visible. |
| Short mobile landscape | At 844×390 and 667×375, the normal header/page spacing pushed the Buy Inventory content and footer below the viewport. | Medium | Added a height-aware compact landscape treatment for the existing header, Market heading/subnavigation, and Quick Purchase panel. It preserves header fields and uses the same routing and business logic. | Rebuilt Web export screenshots at both viewports show the footer; mouse-wheel scrolling moves only the purchase content, with no document-level horizontal overflow. |
| Godot Web text automation | Playwright `.fill()` alone did not type into a Godot `LineEdit`. | Test tooling | Used the export's `.ime` keyboard bridge after focusing the field. | Typed, deleted, and submitted registration values successfully in the browser. |

## Visual evidence

Screenshots are Chromium captures of the local Godot Web game. The viewport matrix images show Market / Buy Inventory, not every page in the game.

- [Registration form](registration.png)
- [Dashboard](dashboard.png)
- [Navigation drawer](navigation-drawer.png)
- [Buy Inventory Category, desktop 1366×768](buy-category-desktop.png)
- [Buy Inventory Category, mobile 390×844](buy-category-mobile.png)
- [Buy Inventory Category, short landscape 844×390](buy-category-short-landscape.png)
- [Short landscape after real wheel scroll at 667×375](buy-category-short-landscape-scrolled.png)
- [Buy Inventory Product](buy-product.png)
- [Buy Inventory Supplier](buy-supplier.png)
- [Buy Inventory Negotiate](buy-negotiate.png)

The repository contains matrix captures at 1920×1080, 1366×768, 1024×768, 768×1024, 390×844, 375×667, 360×800, 844×390, and 667×375. Automated Chromium checks found no document-level horizontal overflow at these sizes. Visual inspection focused on desktop, mobile portrait, and both short landscape sizes. The visible Market subnavigation is horizontally scrollable on narrow portrait screens so all destinations remain available.

## Acceptance status

This is **partial verification**, not full game-wide acceptance. Main Menu, registration, Dashboard, navigation, Market, and the listed Buy Inventory steps received browser inspection. Remaining game screens (products/listings, stores/websites, suppliers/returns, advertising/analytics, Orders/Fulfilment/Customers, Finance, Company Management, Settings, Save/Load actions, all Developer Mode tools) still need individual browser visual and interaction audits. The Confirm and Inbound steps need browser screenshots and an end-to-end browser purchase. Physical iPhone Safari was not available and was not tested.
