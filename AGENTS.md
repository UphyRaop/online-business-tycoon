# Online Business Tycoon — Test Agent Instructions

## Build and runtime

- Use Godot **4.7.2 stable**. The canonical project is the repository root and its main scene is `main.tscn`.
- Run the integrated regression suites with `bash .github/scripts/build-web.sh`. The script uses an isolated profile per suite and finishes with a **release** Web export.
- The player-facing Developer Mode console is available in release and debug builds from the `</>` header button. Its `URTN` code is public convenience UI, not authentication. The console operates only on the active local company session.
- The browser automation bridge remains debug-only. For automated commands, export a debug Web build and serve it in Chromium. Release builds do not register `window.obtRunDevCommand`.

## Open Developer Mode safely

- Unlocking Developer Mode does not change the selected company, CEO profile, game ID, screen, or save slot. It does not create, load, reset, or switch to a second company.
- Developer cheats mutate the active in-memory game. The UI confirms mutations and marks them unsaved. Autosave does not overwrite the player's existing save while developer changes are pending; the player must choose an existing save slot to persist them.
- The Cheats tab offers a confirmed local backup of the active session and existing save-slot bytes under `user://obt_dev_backups/`. Backup files use unique names and are never overwritten.
- Locking or closing the console does not reset game state. Lock hides the tools; the existing save/load and accounting paths remain in use.

## Preview Device

- Open Developer Mode → **Preview Device** and choose one of the portrait-only presets:
  - Desktop: 900 × 1200
  - Tablet: 768 × 1024
  - Mobile: 390 × 844
- In Web builds, the preview scales the real canvas to the available browser window and updates Godot's logical viewport. The preview toolbar is outside the canvas. Choose **Exit Preview** or **Restore Original Viewport** to restore the original logical dimensions. Device preview is available in release and debug builds.
- Additional responsive regression viewports are 1920 × 1080, 1366 × 768, 1024 × 768, 375 × 667, and 844 × 390. These are regression sizes, not additional Developer Mode presets.

## Structured test commands

The structured command endpoint is registered only by a debug Web build and runs against the active game session. It must not be used to access other save slots or games:

```js
window.obtRunDevCommand(JSON.stringify({command: "read_state", args: {}}));
```

The result is assigned to `window.OBTDevResult` as `{ ok, code, message, ... }`. Poll for it after dispatch if the browser bridge has not delivered it yet. Every command returns a structured success or failure.

Supported operations include:

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

Mutating UI actions require confirmation. Automated callers use a debug-only bridge and must be confined to isolated QA browser profiles; their state changes affect only the active company in that browser profile.

## Screenshots and failures

- `capture_screenshot` saves a Godot viewport image under `user://developer_captures/`; use Playwright/Chromium's screenshot API for evidence that includes the browser shell or preview toolbar.
- Name screenshots with viewport and page, for example `mobile-390x844-dashboard`.
- A test passes only after actual interaction and state assertions; a successful render or export alone is not sufficient.
- Report reproducible steps, the command/viewport, expected and actual values, relevant logs, and screenshot path. Do not report a failure as fixed until the affected suite is rerun.

## Financial invariants

- `assert_state` supports `validate_save`, `check_cash_ledger`, and `check_balance_sheet`.
- Developer balance and inventory changes use explicit adjustment ledger fields. These affect cash/assets and equity, never customer revenue or ordinary profit.
- Use the simulation and Finance services for purchases, orders, campaigns, fulfillment, refunds, and time advancement. Do not manually fabricate campaign history or customer transactions.

## Release and production checks

- `bash .github/scripts/build-web.sh` exports the production release and executes the regression suites. Confirm that the output is the release export before deployment.
- Release builds expose the player-facing Developer Mode UI, but not `window.obtRunDevCommand`. Client-side URTN is never owner authentication; actions stay local to the active game and cannot affect remote/shared data.
- Preserve `export_presets.cfg`, the existing GitHub Pages workflow, normal save paths, company ownership/profile data, and accounting behavior.
- Do not use certificate-ignore options for production browser verification. If Chromium cannot trust the live certificate, report that test as blocked rather than claiming it passed.
