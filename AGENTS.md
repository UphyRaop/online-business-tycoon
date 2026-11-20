# Online Business Tycoon — Test Agent Instructions

## Build and runtime

- Use Godot **4.7.2 stable**. The canonical project is the repository root and its main scene is `main.tscn`.
- Run the integrated regression suites with `bash .github/scripts/build-web.sh`. The script uses an isolated profile per suite and finishes with a **release** Web export.
- For Developer Mode and the automation bridge, run a debug build. In a browser, export with `godot --headless --path . --export-debug Web web-build/index.html`, serve `web-build`, and open it in Chromium. Godot debug builds expose `window.obtRunDevCommand`; release builds do not register it.
- For native UI testing, run the project with Godot's debug editor/runtime. Debug status is required for Developer Mode.

## Open Developer Mode safely

- Developer Mode is available from the `</> Developer Mode` button on all game screens and the Main Menu in debug builds. On the first open, it creates an isolated `DEV Copy — …` file under `user://obt_dev_tests/`.
- Normal game slots and company archives are not written while `developer_save_active` is true. Exiting Developer Mode asks for confirmation and restores the in-memory normal game snapshot. DEV saves remain separate and clearly labeled.
- Developer saves can be listed, loaded, reset to a new company baseline, restored to their original copied snapshot, and deleted only inside the `obt_dev_tests` namespace. Never edit or delete files in the normal save namespace to prepare tests.
- Developer actions are stored in each DEV save's audit history and the separate `user://obt_dev_tests/audit.jsonl` log. Failed commands and DEV file deletion are logged there; they are not ordinary transactions, achievements, or rankings.

## Preview Device

- Open Developer Mode → **Preview Device** and choose one of the portrait-only presets:
  - Desktop: 900 × 1200
  - Tablet: 768 × 1024
  - Mobile: 390 × 844
- In Web builds, the preview scales the real canvas to the available browser window and updates Godot's logical viewport. The preview toolbar is outside the canvas. Choose **Exit Preview** or **Restore Original Viewport** to restore the original logical dimensions.
- Additional responsive regression viewports are 1920 × 1080, 1366 × 768, 1024 × 768, 375 × 667, and 844 × 390. These are regression sizes, not additional Developer Mode presets.

## Structured test commands

The stable command endpoint is registered only by a debug Web build:

```js
window.obtRunDevCommand(JSON.stringify({
  command: "create_dev_company",
  args: { name: "DEV QA", owner: "QA CEO", company: "DEV QA Co", country: 0, difficulty: 0, seed: 41021 }
}));
```

The result is assigned to `window.OBTDevResult` as `{ ok, code, message, ... }`. Poll for it after dispatch if the browser bridge has not delivered it yet. Every command returns a structured success or failure.

Supported operations include:

- `create_dev_company`, `load_dev`, `reset_dev`, `restore_dev_snapshot`, `delete_dev` (switch away from a DEV save before deleting it)
- `set_cash` and `add_money` (amounts are integer minor currency units)
- `add_inventory` (`product`, `quantity`, optional `supplier`), `empty_stock`
- `generate_orders` (`count` 10 or 100, `product`)
- `apply_marketing_scenario` (`High ROAS`, `Low ROAS`, `Budget Exhausted`, `Zero Conversions`)
- `set_reputation`, `unlock_expansion`
- `advance_days` (7, 30, or 365; an explicit automation command, so no UI confirmation)
- `select_preview` (`desktop`, `tablet`, `mobile`), `navigate` (`page` or `screen`)
- `capture_screenshot` (`name`), `read_state`, and `assert_state`

Examples:

```js
window.obtRunDevCommand(JSON.stringify({command: "set_cash", args: {amount: -50000}}));
window.obtRunDevCommand(JSON.stringify({command: "add_inventory", args: {product: 0, quantity: 8}}));
window.obtRunDevCommand(JSON.stringify({command: "generate_orders", args: {count: 10, product: 0}}));
window.obtRunDevCommand(JSON.stringify({command: "read_state", args: {}}));
window.obtRunDevCommand(JSON.stringify({command: "assert_state", args: {
  validate_save: true, check_cash_ledger: true, check_balance_sheet: true
}}));
```

The UI requires confirmation for large time advances, inventory clearing, and exiting Developer Mode. Automated callers of the explicitly debug-only endpoint may reset their own DEV files without UI confirmation.

## Screenshots and failures

- `capture_screenshot` saves a Godot viewport image under `user://obt_dev_tests/screenshots/`; use Playwright/Chromium's screenshot API for evidence that includes the browser shell or preview toolbar.
- Name screenshots with viewport and page, for example `mobile-390x844-dashboard`.
- A test passes only after actual interaction and state assertions; a successful render or export alone is not sufficient.
- Report reproducible steps, the command/viewport, expected and actual values, relevant logs, and screenshot path. Do not report a failure as fixed until the affected suite is rerun.

## Financial invariants

- `assert_state` supports `validate_save`, `check_cash_ledger`, and `check_balance_sheet`.
- DEV balance and inventory changes use explicit `dev_cash_adjustment` and `dev_inventory_adjustment` ledger fields. These affect cash/assets and equity, never customer revenue or ordinary profit.
- Use the simulation and Finance services for purchases, orders, campaigns, fulfillment, refunds, and time advancement. Do not manually fabricate campaign history or customer transactions.

## Release and production checks

- `bash .github/scripts/build-web.sh` exports the production release and executes the regression suites. Confirm that the output is the release export before deployment.
- Release builds must not register `window.obtRunDevCommand` or expose the Developer Mode button. The UI and command handlers are gated by `OS.is_debug_build()`.
- Preserve `export_presets.cfg`, the existing GitHub Pages workflow, normal save paths, company ownership/profile data, and accounting behavior.
- Do not use certificate-ignore options for production browser verification. If Chromium cannot trust the live certificate, report that test as blocked rather than claiming it passed.
