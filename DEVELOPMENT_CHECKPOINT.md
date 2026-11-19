# Development Checkpoint — UX Overhaul, Save Isolation, Supplier Credit

Checkpoint captured: 2026-11-19 UTC  
Repository: `UphyRaop/online-business-tycoon`  
Production: https://obt.ur-project.biz/  
Engine: Godot 4.7.2

This checkpoint preserves the full approved scope from the user's “ONLINE BUSINESS TYCOON — USER EXPERIENCE OVERHAUL, SAVE ISOLATION, SUPPLIER CREDIT & MULTI-AGENT QA” request. The usage-limit pause does not change any requirement or authorize a reduction in scope. Do not deploy this unfinished work.

## Repository State

- Integration branch: `phase4-ux-save-supplier`
- Integration HEAD: `1c571eb79ba174b150bce2a658fd0639c9b883ac` — `Implement compact primary navigation drawer`
- Integration branch is four commits ahead of `origin/main` and has no uncommitted changes.
- `origin/main`: `bb78332c498d67b0d809ea03bc02cf3d5b36ebd7` — PR #15 merge.
- No PR has been opened for this UX overhaul. No changes from this task have been pushed to `main`, merged, or deployed.
- The root integration branch contains these task commits:
  - `c3c2851` — Dashboard inventory and CEO portrait frame components.
  - `a3457a1` — Shared semantic control styles and safe text helpers.
  - `6269a9c` — Game-scoped save/profile persistence and migration APIs.
  - `1c571eb` — Navigation drawer, Marketing routing, SVG navigation assets, and related UI labels/tests.

## Approved Requirements and Verified Status

“Complete” below means the feature is present and its focused tests passed. No requirement is marked fully complete unless integrated and verified in the game flow.

| # | Requirement | State at pause |
|---|---|---|
| 1 | Compact, hidden-by-default sidebar; close on selection/outside; accessible touch targets | Implemented on the integration branch. Navigation UI tests and mobile Chromium interactions passed. Whole-game UX audit remains pending. |
| 2 | Replace missing/random glyphs with bundled graphical icons; audit all game icons | SVG assets now serve primary drawer/action icons. A full audit of every icon/glyph throughout the game is not yet complete. |
| 3 | Put Save Game and Main Menu in drawer; preserve save/load/autosave and safe unsaved-progress handling | Drawer actions are implemented; existing save workflow and safe Main Menu confirmation are retained. Full game/save isolation integration remains pending. |
| 4 | One level of sub-navigation; deeper work in internal panels/dialogs/detail views | Advertising's duplicate in-page navigation was removed. A complete audit of every screen for nested navigation is pending. |
| 5 | Dedicated Marketing primary section for Advertising, Campaign Management, Ads Analytics | Implemented and route-tested (including Marketing → Ads Analytics). |
| 6 | Use specific names such as Store Management, Company Management, Inventory Management | Several navigation and management labels are updated. A consistent whole-game label audit remains pending. |
| 7 | Prevent unexpected navigation; preserve page state and unsaved input; clear Back path | Safe menu/discard flows and drawer route behavior are implemented. Full action-by-action workflow audit and state-retention verification remain pending. |
| 8 | Simplify supplier catalogue, detail, negotiation, and purchase workflow | Partial implementation exists only as uncommitted worktree changes; focused supplier workflow UI test was reported passing. It is not integrated into the root branch. |
| 9 | Trust-based supplier credit, limits/terms/due dates, payables, repayment, delinquency, accounting, persistence | Partial implementation exists only as uncommitted supplier worktree changes. Supplier domain tests were reported passing. SaveStore validation and financial statement integration are pending; the full suite has not run against this code. |
| 10 | Repair company/game deletion with explicit confirmation and scoped save removal | `GameStore.delete_game_data()` and focused backend tests are committed and passed. Main Menu deletion UI is only partially implemented in uncommitted `main.gd`; not complete. |
| 11 | Independent New Games: CEO, companies, finances, suppliers, career/date, autosave/manual saves, ownership/sales history | Game-scoped persistence APIs and deterministic legacy migration are committed; 21 focused game-store checks and the existing 21-suite runner were reported passing. UI wiring is incomplete and uncommitted. |
| 12 | New Game requires CEO name before company registration | Partial `main.gd` work exists in the games worktree. Registration flow and UI tests are unfinished. |
| 13 | CEO name consistent across Profile, title/menu, save/load and metadata; edits update labels safely | Backend profile/slot metadata update API and tests exist. Main/Profile/menu/save UI wiring is incomplete. |
| 14 | Professional Title derived read-only from career level; preserve XP migration | Backend title derivation and validation are committed and tested. Current Profile UI still has an editable title field until the uncommitted UI integration is finished. |
| 15 | Dashboard inventory: real totals, available/reserved, low/out-of-stock, preorder demand | `dashboard_inventory.gd` component and focused test are committed; component test passed. It is not yet attached to `main.gd` Dashboard. |
| 16 | Professional themed 3:4 CEO portrait frame; preserve upload/crop behavior | `portrait_frame.gd` component and focused test are committed; component test passed. It is not yet wired into Profile or responsive-layout lookup. |
| 17 | Professional, consistent capitalization; preserve entered proper names | Safe heading/sentence helpers are committed and tested. They are not yet consistently applied; full text audit remains pending. |
| 18 | Mobile first-tap focus and keyboard visibility | Chromium at 390×844 verified one-tap focus/typing, touch selection, no horizontal overflow, and viewport-height resize/restore behavior. This runtime has no native virtual keyboard, so actual keyboard occlusion remains unverified. No code fix was warranted for first-tap focus. |
| 19 | Global button/action UX audit and semantic roles | Shared semantic roles/helper and focused style test are committed. Main's common `action()` helper has not yet been wired to them; full button audit and confirmation review remain pending. |

## Worktrees and Agent Branches

Active work for this task is isolated in these worktrees. Keep all of them; do not reset, rebase, or delete them during resumption.

| Worktree | Branch / HEAD | State |
|---|---|---|
| `/workspace/online-business-tycoon` | `phase4-ux-save-supplier` / `1c571eb` | Clean integration branch; four task commits ahead of remote `main`. |
| `/workspace/obt-agent-worktrees/ux-overhaul-nav` | `ux-overhaul-nav` / `68adfd3` | Clean; completed navigation changes and test updates. Equivalent implementation is cherry-picked to integration branch as `1c571eb`. |
| `/workspace/obt-agent-worktrees/ux-overhaul-controls` | `ux-overhaul-controls` / `290e36c` | Clean; semantic style/text helpers and focused test. Cherry-picked to integration branch as `a3457a1`. |
| `/workspace/obt-agent-worktrees/ux-overhaul-dashboard` | `ux-overhaul-dashboard` / `f740693` | Clean; inventory/portrait components and focused test. Cherry-picked to integration branch as `c3c2851`. |
| `/workspace/obt-agent-worktrees/ux-overhaul-games` | `ux-overhaul-games` / `652b9ac` | Four commits based on `bb78332`; **uncommitted partial `main.gd` integration (190-line diff: 125 insertions, 65 deletions)**. Preserve exactly; it wires scoped game operations but New Game/menu/save flow and UI tests are unfinished. |
| `/workspace/obt-agent-worktrees/ux-overhaul-suppliers` | `ux-overhaul-suppliers` / `bb78332` | **Uncommitted implementation in progress.** Modified `finance_management.gd`, `market_view.gd`, `simulation.gd`, `supply.gd`; untracked `supplier_credit.gd`, its UID, `supplier_credit_test.gd`, its UID, `supplier_workflow_ui_test.gd`, its UID. Preserve all files. |
| `/workspace/obt-agent-worktrees/ux-overhaul-mobileqa` | `ux-overhaul-mobileqa` / `bb78332` | Untracked QA evidence only: `evidence/` screenshots and `qa-mobile-390-setup.png`, `qa-mobile-390-title.png`. Preserve these as test evidence. |

Older worktrees (`ads`, `company-sale`, `milestone1`, `milestone2`, `products`, `qa`, `ui`) remain present from completed prior tasks. They are not part of this unfinished UX work and were not modified in this pause.

Six specialized agents were used: navigation/icons (completed), supplier workflow/credit (interrupted with uncommitted changes), game-save isolation/CEO identity (backend completed; UI integration interrupted with uncommitted changes), shared controls/text helpers (completed), Dashboard/Profile components (completed), and mobile QA (completed). Root is the integration owner. The agent roster reported no other running agents when the pause was recorded.

## Tests and Browser Checks Already Completed

- Baseline on the integration base: all **20 existing regression/UI suites passed** and Godot 4.7.2 Web export succeeded. The first baseline attempt had host-path errors because the default Godot XDG directories were unwritable; rerunning with the bundled writable Godot data/config/cache paths fixed the environment issue.
- Navigation branch: all **20 listed suites passed**, Web export succeeded, `git diff --check` clean. Marketing → Ads Analytics was explicitly route-tested. A stale assertion/helper was adjusted to exercise the new route rather than skip it.
- GameStore backend branch: all **21 listed suites passed** including `game_store_test`, Web export succeeded, `git diff --check` clean. Focused game-store checks covered isolation, deterministic migration, deletion scope, and metadata.
- Shared control-style helper: `control_style_test.gd` and `phase4_ui_test.gd` passed.
- Dashboard/profile components: `dashboard_inventory_test.gd` passed.
- Mobile Chromium: 390×844, one-tap registration input, drawer touch selection/outside close/Escape, scrolling, no horizontal overflow, and height resize/restore checked. Screenshots retained under the mobile QA worktree. Native OS keyboard behavior is unverified because the headless Chromium environment exposes no virtual keyboard.
- Supplier branch: focused credit and workflow UI tests plus Phase 1, Phase 2, Phase 3.3, Phase 4 inventory/ads, and Phase 4 UI suites were reported passing. This code remains uncommitted and has not had a full 24+ suite integration run.
- No production browser test or deployment for this task has happened.

## Known Gaps / Blockers

1. Supplier agent hit its usage limit after reporting tests; its files remain uncommitted in the supplier worktree. Resume by inspecting those files, rerunning the focused tests, and committing them only after recovering the complete implementation. No test failures were reported, but integration is unverified.
2. `SupplierCredit.validate(state)` is not yet called from `SaveStore.valid_operations()`. The Balance Sheet still needs supplier payables included in total liabilities and equity, and the Cash Flow Statement needs supplier repayments shown separately with credit-funded purchases excluded from immediate cash payments.
3. GameStore UI work in `ux-overhaul-games/main.gd` is unfinished and uncommitted. Menu game listing/deletion, explicit New Game → CEO name → company registration, per-game Profile edits, scoped save/load labels/flows, and UI-level two-game isolation/deletion tests remain.
4. After game UI integration, wire the Dashboard inventory and portrait-frame modules; update responsive avatar lookup; remove manual Professional Title editing; connect semantic button roles to the shared action helper; continue the full text/icon/navigation/button audit.
5. Add the new game, supplier-credit/workflow, control-style, and Dashboard inventory test suites to `.github/scripts/build-web.sh` without removing or weakening existing test assertions. Run the complete integrated suite and Web export only after all schemas/UI are integrated.
6. Real mobile keyboard occlusion cannot be verified in this headless browser. Retest on a supported device/emulator when available; report this limitation if it remains unavailable.

No merge conflicts are currently recorded. No production changes should occur until all approved requirements are implemented and the complete regression/UI suite, finance reconciliation, Web export, and browser checks pass.

## Existing Plan Update

`PHASE4_FINANCIAL_PLAN.md` predates the latest user approval and says supplier credit has not been approved. A dated addendum now records that the approved supplier-credit requirement supersedes that earlier assumption, while preserving existing cash-purchase and unrelated settlement/loan policies. The actual limits, terms, trust changes, and delinquency rules still need documentation beside the implementation after verification.

## Exact Next Step on Resumption

1. Read this checkpoint and inspect the current Git status of the integration, `ux-overhaul-games`, and `ux-overhaul-suppliers` worktrees. Preserve all current uncommitted files.
2. Resume the multi-agent workflow. First recover and validate the supplier-credit worktree: run `supplier_credit_test.gd` and `supplier_workflow_ui_test.gd`, inspect the accounting invariants, then commit the complete feature on `ux-overhaul-suppliers`.
3. Finish the uncommitted GameStore UI integration in `ux-overhaul-games`, add tests for two separate CEO/game identities and deletion isolation, and verify scoped save/load behavior.
4. Integrate both completed branches into `phase4-ux-save-supplier`; wire supplier payable validation/statements, Dashboard inventory, portrait framing, read-only career title, and global button roles.
5. Run all existing and new suites plus Godot 4.7.2 Web export; fix and rerun failures before opening a PR or deploying.

