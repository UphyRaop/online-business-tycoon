# Development Checkpoint — UX Overhaul, Save Isolation, Supplier Credit

Checkpoint updated: 2026-11-19 UTC
Repository: `UphyRaop/online-business-tycoon`
Production: https://obt.ur-project.biz/
Engine: Godot 4.7.2

This is a continuation checkpoint for the full approved 19-requirement UX, save isolation, supplier credit, and multi-agent QA prompt. The approved requirements and scope remain in the original user prompt. Do not start Phase 5 or change existing game/save behavior outside approved work.

## Current State

- Integration branch: `phase4-ux-save-supplier`
- Latest local/remote branch commit: `46aac120d9009742b7b592cfb8484e3867af3efb` (`Polish control labels and semantic actions`)
- PR #16 targets `main`: https://github.com/UphyRaop/online-business-tycoon/pull/16
- PR is open and GitHub reports it mergeable. No PR checks are configured; the project Pages workflow runs on pushes to `main`.
- No merge or deployment for this branch has happened as of this checkpoint.
- Working tree is clean.

## Requirement Status

All 19 requirements have implementation and relevant automated coverage. The remaining platform limitation is listed under QA limits.

| # | Requirement | Verified status |
|---|---|---|
| 1 | Compact hidden-by-default navigation drawer | Implemented; desktop and mobile Chromium interaction passed. |
| 2 | Replace broken/random navigation glyphs with bundled icons | SVG navigation/action icons are bundled and rendered. Source scan found no unsupported UI glyphs from the checked symbol set. |
| 3 | Save Game and Main Menu in drawer | Implemented with existing save workflow and unsaved-progress confirmation. |
| 4 | Single-level sub-navigation | Marketing routes use one compact secondary layer; deeper work remains in panels/details. |
| 5 | Marketing primary section | Advertising, Campaign Management, and Ads Analytics are grouped under Marketing and route-tested. |
| 6 | Clear management names | Store/Company/Inventory Management terminology applied in relevant flows. |
| 7 | Prevent unexpected navigation and protect state | Safe confirmation/back paths and in-flow supplier navigation are covered by UI tests. |
| 8 | Supplier workflow | Product → supplier → details → negotiate → accept → purchase path and input retention are covered. |
| 9 | Supplier credit | Deterministic trust, credit limits, 7-day terms, payables, repayments, returns, and statement reconciliation are implemented and tested; see `SUPPLIER_CREDIT_POLICY.md`. |
| 10 | Company deletion | Explicitly confirmed and scoped; deleted records stay deleted without removing sibling companies/games. |
| 11 | Independent New Games | Stable Game IDs, isolated saves/profiles/career, deterministic legacy migration, and deletion scope have functional tests. |
| 12 | CEO name required for New Game | New Game registration flow collects and validates CEO name before company registration. |
| 13 | CEO identity in profile/menu/save metadata | Identity is game-scoped; profile edits update metadata while stable IDs and company records remain intact. |
| 14 | Professional title from career level | Derived read-only title preserves career XP and migration. |
| 15 | Dashboard inventory overview | Actual stock, reservations, low/out-of-stock items, and pre-order demand are shown in a responsive summary. |
| 16 | Themed 3:4 CEO portrait frame | Integrated with the persisted/cropped CEO photo and placeholder state. |
| 17 | Professional capitalization | Shared formatting helpers and UI labels are covered by tests; preserves proper names and branded casing. |
| 18 | Mobile keyboard/text input | First-tap input, focus visibility, and viewport-height keyboard emulation passed. Native OS keyboard occlusion is unverified because headless Chromium has no virtual keyboard. |
| 19 | Global button and UX audit | Semantic action colors, confirmations, navigation, forms, empty states, and all primary routes were reviewed/tested; 7 drawer routes rendered without errors in desktop Chromium. |

## Integrated Work

Work from `ux-overhaul-suppliers`, `ux-overhaul-games`, and `ux-overhaul-mobileqa` has been recovered and integrated. The branch includes supplier credit, game-scoped persistence and deletion UI, CEO identity flow, Dashboard inventory/profile components, responsive navigation, semantic controls, and associated tests. Work was integrated through isolated worktrees; see Git history for commits.

## Verification

Latest full run: `.github/scripts/build-web.sh` completed on 2026-11-19 UTC.

- 27 regression/UI suites ran; all 27 reported 0 failures.
- Godot `4.7.2.stable.official.ed1daf0bf` Web export succeeded. Latest artifacts are in ignored `web-build/`.
- `git diff --check` passed for the source changes; checkpoint whitespace was subsequently normalized.
- Chromium latest-export smoke: HTTP 200, Dashboard loaded at 1280×720 and 390×844, mobile drawer opened, no page errors or horizontal overflow.
- All 7 drawer routes rendered on desktop without page errors.
- Same-origin, same-profile Chromium close/reopen retained the Harbor Pine autosave and Morgan Lee CEO identity.
- Mobile Market input accepted a single touch and remained visible in viewport-height keyboard emulation.
- Evidence: `/workspace/obt-agent-worktrees/ux-overhaul-mobileqa/evidence/`, including `fresh-export-dashboard-desktop-1280x720.png`, `fresh-export-dashboard-mobile-390x844.png`, and `fresh-export-drawer-mobile-390x844.png`.

## Remaining Work

1. Finish PR #16 review and merge. No required PR status checks are configured; local integrated verification passed.
2. Wait for the main-branch GitHub Pages build/deploy workflow to complete successfully.
3. Verify the deployed `https://obt.ur-project.biz/` version and run desktop/mobile production smoke tests with certificate verification enabled. If Chromium trust blocks the production browser, report that accurately without bypassing TLS.
4. Report the merge SHA, workflow run, deployment URL, requirement statuses, and remaining limitation.

Do not claim production deployment until the Pages workflow and live URL are verified. Native mobile keyboard behavior remains unverified in this environment.
