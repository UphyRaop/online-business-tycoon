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
- **Same-origin persistence:** autosave survived same-profile reload/reopen. Manual Slot 1 had conflicting results: an independent QA profile showed it empty after reload, while a separate same-profile test retained it after immediate reload/reopen. Manual-slot persistence is **UNRESOLVED**, not PASS; evidence is linked in the audit matrix.
- **Buy Inventory browser screens:** Category, Product, Supplier, Negotiate, Confirm, and Inbound Stock were captured from the running Web game. Disposable 1366×768 and 390×844 Chromium journeys completed a one-unit purchase through Inbound Stock. On 390×844, the Godot Web build received a touch drag, scrolled the Confirm summary while the footer remained visible, and accepted a tap on the confirmation action afterward. This is Chromium touch emulation, not physical iPhone Safari.
- **Developer Mode:** local Chromium completed the access-dialog cancel/reopen, `URTN` unlock, tool scroll-to-bottom and close sequence at 390×844. The full set of cheat actions remains unaudited; physical iPhone Safari is untested.
- **Production site:** browser inspection is **BLOCKED**. Chromium's verified request to `https://obt.ur-project.biz/` returns `ERR_CERT_AUTHORITY_INVALID` in this environment. The failure is consistent with the environment TLS-inspection CA and does not establish an origin certificate defect. Certificate checks were not bypassed; no production setting was changed, and no merge/deployment was performed.

## Findings and corrections in this update

| Screen/area | Finding | Severity | Correction | Verification |
| --- | --- | --- | --- | --- |
| Buy Inventory category | Category cards omitted the live product count required by the approved flow. | Low | Added catalogue-derived product counts to every category card. | Catalogue UI test checks all category cards have an icon and a product count; actual Web screenshot shows the counts. |
| Buy Inventory footer | Footer geometry had assertions only for presence; it was not checked at every workflow stage or short landscape sizes. | Medium | Added bounds, visibility, no-outer-scroll, and short-landscape assertions for Category, Product, Supplier, Negotiate, and Confirm. | `catalog_flow_ui_test`: 0 failures; Chromium wheel scrolling at 667×375 reveals cards while the footer remains visible. |
| Short mobile landscape | At 844×390 and 667×375, the normal header/page spacing pushed the Buy Inventory content and footer below the viewport. | Medium | Added a height-aware compact landscape treatment for the existing header, Market heading/subnavigation, and Quick Purchase panel. It preserves header fields and uses the same routing and business logic. | Rebuilt Web export screenshots at both viewports show the footer; mouse-wheel scrolling moves only the purchase content, with no document-level horizontal overflow. |
| Godot Web text automation | Playwright `.fill()` alone did not type into a Godot `LineEdit`. | Test tooling | Used the export's `.ime` keyboard bridge after focusing the field. | Typed, deleted, and submitted registration values successfully in the browser. |
| Available Bank Balance was compressed beside Buy Max in Confirm. | Medium | The balance metric and row expand to use available width; Buy Max remains compact. | `catalog_flow_ui_test` checks width flags; the refreshed Chromium screenshot shows the full label and amount. A new purchase reached Inbound Stock. |

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
- [Buy Inventory Confirm, before balance-row correction](buy-confirm-before-stepper-fix-1366.png)
- [Buy Inventory Confirm, after balance-row correction](buy-confirm-after-stepper-fix-1366.png)
- [Inbound Stock after one browser purchase](buy-inbound-after-stepper-fix-1366.png)
- [Confirm at 390×844, top](buy-confirm-mobile-top-390.png) · [after touch scroll](buy-confirm-mobile-touch-scrolled-390.png) · [confirmation dialog after scrolling](buy-confirm-mobile-touch-action-390.png) · [Inbound Stock](buy-inbound-mobile-touch-390.png)
- Manual-slot discrepancy evidence: [save visible before reload](manual-save-slot1-before-reload-qa.png) · [independent profile showed empty](manual-save-slot1-empty-after-reload-qa.png) · [root same-profile rerun retained slot](manual-save-slot1-present-after-reload-qa.png)

The repository contains matrix captures at 1920×1080, 1366×768, 1024×768, 768×1024, 390×844, 375×667, 360×800, 844×390, and 667×375. Automated Chromium checks found no document-level horizontal overflow at these sizes. Visual inspection focused on desktop, mobile portrait, and both short landscape sizes. The visible Market subnavigation is horizontally scrollable on narrow portrait screens so all destinations remain available. The latest balance-row screenshot is desktop only and does not establish the layout at every viewport.

## Acceptance status

This is **partial verification**, not full game-wide acceptance. Main Menu, registration, Dashboard, navigation, several Business/Marketing/Finance/Orders/Profile/Settings routes, Developer Mode access/scroll/close, and one Buy Inventory purchase through Inbound Stock have local Chromium evidence. Populated company workflows, remaining routes and actions, per-screen viewport coverage, purchase save/reload, and most Developer Mode tools remain unaudited. Physical iPhone Safari was not available and was not tested.

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

This correction does not complete PR #33's full UI/UX audit. Buy Inventory Confirm/Inbound browser screenshots and desktop/mobile browser purchases are now recorded, including a mobile touch-scroll retest. The remaining game screens listed in the acceptance matrix above still need individual browser visual and interaction review. Production verification is still blocked by the previously recorded Chromium `ERR_CERT_AUTHORITY_INVALID`; certificate checks were not bypassed. No merge or deployment was performed.

## Latest PR #33 standardization pass

The route-by-route inventory, V4 design tokens, responsive evidence, and explicit coverage states are recorded in [UI_UX_AUDIT.md](UI_UX_AUDIT.md). This remains an incomplete audit: only rows with concrete browser evidence are marked partial/pass, and all unvisited destinations remain NOT TESTED.

This pass fixed the Product step's redundant nested action: each product card is now one full-card selectable button with a selected state. Supplier count and indicative landed cost remain visible. The search field was reduced to a 40 px minimum height and given a placeholder. A local Chromium run confirmed the selected gold border and no JavaScript errors at 1366×768. Before/after evidence:

- [Before](market-product-before-1366.png)
- [After](market-product-after-1366.png)
- [Selected card](market-product-selected-after-1366.png)

The same pass fixed the Developer Mode unlock double-tap window by guarding the keyboard-dismissal handoff. Local Chromium completed access-dialog cancel/reopen, URTN unlock, console scrolling, and close at 390×844; physical iPhone Safari remains untested. A later disposable Chromium run completed one Buy Inventory purchase through Inbound Stock at 1366×768.


## Latest continuation update — mobile Buy Inventory scrolling

- The Confirm-step `ScrollContainer` responded to mouse-wheel input but did not move during a Chromium touch swipe. Godot Web delivered `InputEventScreenTouch` and `InputEventScreenDrag`; the stock container did not apply screen-drag events. A Buy Inventory-only scroll subclass now handles in-bounds drags after a 10 px deadzone and adjusts the inner vertical offset. The footer remains outside the scroll viewport.
- Godot 4.7.2: all **33/33** regression/UI suites passed, including a touch-drag assertion; the Release Web export passed. `dashboard_inventory_test` retains its prior shutdown leak warning without assertion failures.
- A disposable Chromium emulation run at 390×844 completed registration, category/product/supplier selection, 0% negotiation, Confirm-step touch scrolling, confirmation, one purchase, and Inbound Stock. The footer stayed reachable and the Confirm action worked after scrolling. No JavaScript errors or document horizontal overflow were observed. This is not physical iPhone Safari verification.
- Independent reviewers confirmed the broader audit remains incomplete and highlighted unvisited Main Menu actions, settings/save confirmations, dialogs, populated workflows, all-route viewport coverage, the manual-save discrepancy, and production TLS blockage. The audit matrix keeps these items unverified.
- Evidence: [Confirm before swipe](buy-confirm-mobile-top-390.png), [after touch scrolling](buy-confirm-mobile-touch-scrolled-390.png), [confirmation action after scroll](buy-confirm-mobile-touch-action-390.png), [mobile shipment after purchase](buy-inbound-mobile-touch-390.png).

PR #33 remains draft. No merge or deployment was performed.

## PR #33 continuation — persistence, screen audit, and latest corrections (2026-11-22)

- Controlled same-origin persistent-profile test: Manual Slot 1 remained available after page reload and a full Chromium close/reopen, then loaded its Day 1 snapshot; autosave had independently advanced to Day 2. Evidence is in the `manual-persist-*-20261122.png` captures. This resolves the observed conflict as an automation/profile-path discrepancy; no save-schema change was made.
- Local Release Web screen review added Business/Marketing, Orders, Finance, Profile, settings, registration and all Developer Mode category captures. See the detailed route-by-route status and limitations in [UI_UX_AUDIT.md](UI_UX_AUDIT.md). The overall audit is still INCOMPLETE: populated store/product/campaign/order transactions and all-screen checks at all nine viewports remain open.
- Fixed the repeated Ads Analytics heading and added an assertion. Before/after screenshots: [before](routes/ads-analytics-empty.png), [after](routes/ads-analytics-after-single-title.png).
- Fixed Developer Mode Close/Lock controls scrolling away with long tool content. The header now sits outside the tool `ScrollContainer`; `developer_console_ui_test` checks the visible header and bottom option across all nine viewports. Local Release Web Chromium wheel input at 1366×768 and touch-style swipe at 390×844 reached the final tool while title/Close/Lock stayed visible. Screenshots are linked in `UI_UX_AUDIT.md`. Physical iPhone Safari is not tested.
- Regression and UI suite run: **33/33 passed**. The existing `dashboard_inventory_test` shutdown resource-leak warning remains with zero assertion failures. The first export attempt had an incorrect `XDG_DATA_HOME` and could not find Web templates; rerunning with the installed Godot 4.7.2 template directory succeeded. The Release Web export excludes QA evidence under `docs/pr33-evidence/` to prevent screenshots increasing the shipped pack.
- Production Chromium verification remains **BLOCKED** by the environment TLS-inspection CA; certificate verification was left enabled. No merge, deploy, DNS, hosting or certificate changes were made.
