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

## Developer Mode iPhone keyboard and viewport correction

### Confirmed causes

1. The Web shell sized `#preview-host` and the game frame to `100vh`, while Godot's Web canvas resize policy follows the browser window. iOS Safari reduces the **visual viewport** for its software keyboard without reliably changing the layout viewport used by those dimensions. The canvas and Godot controls could therefore remain taller than the visible Safari area. The first viewport proxy also showed that resizing only the outer host clipped the still-full-height inner game frame; the final correction resizes both.
2. Cancel and successful unlock removed the focused Godot `LineEdit` without releasing the GUI focus owner or blurring the Web IME element. This could leave the keyboard and reduced viewport active. The dialog also deferred `ensure_control_visible()` for both the input and Unlock button; the latter could scroll the focused input away as the keyboard appeared.
3. The large lower area is not a hidden-control region. The console panel uses `SIZE_SHRINK_BEGIN` inside a vertical `ScrollContainer`; when the active category has less content than the viewport, the panel remains content-sized and unused canvas is visible. On longer categories, scrolling reaches the final control. No feature or explanation was removed to fill that space.

### Corrections

- The custom Web shell now follows `window.visualViewport` on resize/scroll, resizes the preview host, game frame, and browser dimensions used by Godot, and restores their exact prior styles/descriptors when the viewport returns. Standard resize events do not recursively dispatch additional resize events.
- Cancel, Escape, and successful unlock explicitly release Godot GUI focus, hide the virtual keyboard, and blur the browser IME element. Successful unlock waits for the Web keyboard-dismissal resize transition before measuring/opening the current-session console. The input is the only control auto-scrolled into view on dialog open.
- Mobile Developer Mode uses compact Close/Lock controls, 42px minimum action heights, smaller content gaps and bottom padding. All tool categories and descriptions remain present. The access-dialog actions stay in one row at normal phone widths and stack only below 340px.
- Regression coverage now includes all nine requested viewport sizes for the access dialog and console, Cancel focus release and active-game preservation, scrollability, and Web-shell visual viewport resizing/restoration.

### Verification

- Godot 4.7.2: all 33 regression/UI suites passed; Release Web export completed. `dashboard_inventory_test` still prints the pre-existing resource-leak shutdown warning (2 CanvasItem RIDs, 8 ObjectDB instances, 1 resource), with zero assertion failures.
- Chromium loaded the local Release Web export and completed the access-dialog cancel/reopen, successful `URTN` entry, console open, mouse-wheel scroll to the bottom Finance action, scroll back, and Close sequence at 390×844. The IME focus element was `BODY` after Cancel and `CANVAS` after closing the console. No JavaScript errors or document overflow were observed.
- A visual-viewport proxy reduced 390×844 to 390×480 and verified that both the canvas and game host resized to 480px, then returned to 844px. This validates the shell's resize path; it does not emulate an iOS keyboard.
- Browser viewport captures at 1920×1080, 1366×768, 1024×768, 768×1024, 390×844, 375×667, 360×800, 844×390, and 667×375 showed the canvas matching the viewport and zero document-level horizontal overflow. The automated Godot console suite also checked layout, scroll range and final actions at all nine sizes.
- Physical iPhone 15 Pro Max screenshots were described by the user as real-device evidence, but image files were not available to this workspace for annotation or direct comparison. Physical iPhone Safari keyboard testing remains **NOT TESTED by Codex**.

### New evidence

- [Developer Mode dashboard, mobile 390×844](dev-mode-dashboard-390x844.png)
- [Access dialog, mobile 390×844](dev-mode-access-mobile.png)
- [Dashboard after Cancel and focus release](dev-mode-access-cancelled-mobile.png)
- [Access dialog with reduced-viewport proxy](dev-mode-access-mobile-viewport-reduced.png)
- [Access dialog after viewport restoration](dev-mode-access-mobile-viewport-restored.png)
- [Developer console, mobile top](dev-mode-console-mobile-top.png)
- [Developer console, scrolled to final Finance action](dev-mode-console-mobile-scrolled.png)
- [Gameplay after closing Developer Mode](dev-mode-console-closed-mobile.png)
- [Gameplay viewport, 1920×1080](dev-mode-dashboard-1920x1080.png) · [1366×768](dev-mode-dashboard-1366x768.png) · [1024×768](dev-mode-dashboard-1024x768.png)
- [Gameplay viewport, 768×1024](dev-mode-dashboard-768x1024.png) · [390×844](dev-mode-dashboard-390x844.png) · [375×667](dev-mode-dashboard-375x667.png) · [360×800](dev-mode-dashboard-360x800.png)
- [Gameplay viewport, 844×390](dev-mode-dashboard-844x390.png) · [667×375](dev-mode-dashboard-667x375.png)

### Audit status remains partial

This correction does not complete PR #33's full UI/UX audit. Buy Inventory Confirm/Inbound browser screenshots and a browser-driven purchase remain outstanding. The remaining game screens listed in the acceptance checklist above still need individual browser visual and interaction review. Production verification is still blocked by the previously recorded Chromium `ERR_CERT_AUTHORITY_INVALID`; certificate checks were not bypassed. No merge or deployment was performed.

## Latest PR #33 standardization pass

The route-by-route inventory, V4 design tokens, responsive evidence, and explicit coverage states are recorded in [UI_UX_AUDIT.md](UI_UX_AUDIT.md). This remains an incomplete audit: only rows with concrete browser evidence are marked partial/pass, and all unvisited destinations remain NOT TESTED.

This pass fixed the Product step's redundant nested action: each product card is now one full-card selectable button with a selected state. Supplier count and indicative landed cost remain visible. The search field was reduced to a 40 px minimum height and given a placeholder. A local Chromium run confirmed the selected gold border and no JavaScript errors at 1366×768. Before/after evidence:

- [Before](market-product-before-1366.png)
- [After](market-product-after-1366.png)
- [Selected card](market-product-selected-after-1366.png)

The same pass fixed the Developer Mode unlock double-tap window by guarding the keyboard-dismissal handoff; the focused UI suite and all 33 regression/UI suites passed. The full browser purchase, remaining screen-by-screen audit, physical iPhone Safari, and production browser inspection remain incomplete or blocked as shown in the matrix.

The expanded local browser audit also found and corrected two visual inconsistencies: desktop/game page headings were 30 px, so they now use 26 px on desktop and 24 px on mobile; and the Marketing Overview's combined CTR/CPM value wrapped in the middle of a currency code, so CTR and CPM now appear as separately labeled single-line values. `phase4_ui_test` asserts the desktop heading size and KPI rows, and the final local Chromium capture shows both corrections. Additional route screenshots and coverage states are listed in [UI_UX_AUDIT.md](UI_UX_AUDIT.md).
