# Online Business Tycoon

Open the workspace root's `project.godot` in Godot 4.7.2 and press **F5**.

## Play the business loop

1. Choose **New Game** to register an entrepreneur and company. Choose a country, difficulty, and marketplace, website, or both. **Continue Game** opens the latest readable save, and **Settings** lets you increase text size.
2. In **Market**, choose a product and compare each supplier's quote, quality, lead time, and on-time rate. Enter a quantity to negotiate a seven-day volume quote or copy the forecast's restock quantity. Purchase stock to create an inbound shipment. Track its ETA in the product's **Inbound stock** card.
3. Publish your listing and set its selling price. The listing estimates contribution after landed cost, the channel fee, and default outbound delivery. Use **Offers** on the selected product to create, edit, enable, or disable its bundle and upsell. A bundle is 2–10 units of that same product at a fixed total price or percentage discount. An upsell adds one or two units from another listed product, either two distinct items or two units of the same additional item. A fixed offer price replaces the percentage discount.
4. In **Dashboard**, advance 1, 2, 7, or 30 days. The game calendar begins on Thu, 1 Jan 2026. Inbound stock becomes sellable as it arrives. Customers can place orders, abandon checkout, or leave because a product is out of stock.
5. In **Orders**, select **Fulfillment** to track orders through delivery. Open **Shipping settings** to choose Economy, Standard, or Express and automatic or manual dispatch. Manual dispatch lets you override the shipping method on each queued order.
6. Open **Customer service** under **Orders** to resolve complaints and approve or decline returns. Refunds on recent delivered orders are also available in the order history. Review conversion, stockouts, bundle orders, and upsells by channel in **Sales analytics**.
7. Open **My Products** from Dashboard, Market, or Business to see drafts, active listings, and published products awaiting stock. Manage each product's price, inventory, and preferred channels independently. A listing can sell only on channels enabled in Business. The active count covers published products that have stock and can sell.
8. Review the Income Statement, Balance Sheet, and Cash Flow Statement in **Finance**. Choose daily, Monday–Sunday weekly, calendar-month, or calendar-year reports. The date range and recorded portion are shown above the statement. Use **Previous** and **Next** to navigate recorded periods. Rename your company or store and change company channels in **Business**.

Use **Save Game** in the gameplay header to save, load, or delete a slot. Three manual slots hold independent snapshots, and committed gameplay updates **Autosave**. Overwriting or deleting requires confirmation. **Load Game** on the title screen shows the company, country, game date, and local saved time for each slot. In **Business**, edit your company, brand, marketplace store, website domain, and website channel availability independently.

## Phase 3: Advertising and store expansion

Open **Growth** for campaign management, advertising analytics, and store management. Campaigns use locally simulated Meta, Google, TikTok, or Marketplace Sponsored Ads inventory. Select an active store, a published product, objective, daily budget, audience, bidding strategy, and creative. Retargeting unlocks after 15 recorded visits; lookalikes unlock after five delivered purchases. Pause, resume, edit, or stop campaigns. Campaign analytics separate placed-order attribution from delivered revenue recognized in the financial statements.

Open **Store Management** to create Marketplace or Own Website stores. Setup prices are shown before creation; new stores charge a type- and country-scaled setup fee and daily operating fee. Legacy Phase 1/2 stores retain their original cost model. Stores share company inventory, with independent names, brands, website domains, product listing prices, and sales reporting. Bundle quantities are limited to 2–10 units.

## Accounting and saves

Supplier purchases are paid up front at landed cost, including inbound freight. Checkout collects cash as a deposit and reserves FIFO stock. Dispatch expenses outbound delivery. Delivery recognizes sales and landed cost of goods sold, releases the deposit, and charges the channel fee. Refunds reverse revenue and restore resellable inventory at its original landed cost. The original outbound shipping and channel fees remain expenses.

Existing Phase 1 and Phase 2 saves retain their elapsed game days, now dated from 1 Jan 2026. Pre-slot saves appear in **Autosave** when the slot is empty unless you deleted Autosave. The older file is retained. Legacy inventory keeps its original cost, with zero recorded inbound freight. Older aggregate sales remain in Finance, and older multi-item orders without line prices use cost-based allocation. My Products shows gross margin on the next FIFO unit, inbound unit, or supplier quote, together with net sales and historical profit after direct costs.

Supplier terms, carriers, and customer behavior are simulated locally. The forecast uses up to 14 days of observed demand and a catalog estimate when no history is available. A return refunds the whole order and resolves immediately on approval. Currency scales and fees are fictional game values.

## Run automated tests on Windows

Run this from the project root. Each UI suite needs a fresh profile to test first launch and local saves independently of your game.

```powershell
$godot = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
$originalAppData = $env:APPDATA
try {
    foreach ($suite in 'phase1_test', 'phase2_test', 'final_test', 'corrective_test', 'phase3_test', 'phase1_ui_test', 'phase2_ui_test', 'final_ui_test', 'phase3_ui_test') {
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) ('obt-test-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $env:OBT_ISOLATED_TEST_PROFILE = '1'
        & $godot --headless --path . --script "res://$suite.gd"
        if ($LASTEXITCODE -ne 0) { throw "$suite failed with exit code $LASTEXITCODE" }
    }
} finally {
    $env:APPDATA = $originalAppData
    Remove-Item Env:OBT_ISOLATED_TEST_PROFILE -ErrorAction SilentlyContinue
}
```

## Phase 3 Web build

The exported Godot game is in `web-build/`. Keep `index.html`, `index.js`, `index.wasm`, `index.pck`, and the other exported assets together. For a local test, run this from the project root with Node.js installed.

```powershell
node tools/serve-web.mjs
```

Open [the local game](http://localhost:8060/). For a quick iPhone test on the same Wi-Fi, run `node tools/serve-web.mjs --lan` and open `http://<Windows IPv4 address>:8060/` in Safari. Use the active Wi-Fi IPv4 address shown by `ipconfig` and leave the server running.

### GitHub Pages deployment

The Pages workflow runs on pushes to `main` and can also be run manually on `main`. It runs all nine regression and UI suites with isolated save profiles before exporting and deploying the single-threaded Web release.

In the repository's **Settings → Pages**, select **GitHub Actions** as the source and set **Custom domain** to `obt.ur-project.biz`. In the DNS settings for `ur-project.biz`, point the `obt` CNAME record to `uphyraop.github.io`. Once GitHub provisions the certificate, enable **Enforce HTTPS**. The deployment target is `https://obt.ur-project.biz/`.

Browser saves use IndexedDB. Keep using the same HTTPS hostname and browser profile to retain saves across deployments. Saves from a localhost, LAN, or different hosted origin stay with that origin.

### Separate GitHub Pages playtest repository

Create a public GitHub repository dedicated to the playtest. Copy the **contents** of `web-build/` into its root, then commit and push with GitHub Desktop or Git. The WebAssembly file is about 38 MiB, so use a Git push for the upload. In the repository, open **Settings → Pages**, choose **Deploy from a branch**, and select **main / (root)**. Open the HTTPS URL shown on the Pages screen on your iPhone. [GitHub Pages publishing guide](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) · [GitHub file limits](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)

### Re-export and browser limitations

Install the matching **Godot 4.7.2 Standard export templates** from **Editor → Manage Export Templates**. Select **Project → Export → Web → Export Project**, export to `web-build/index.html`, and leave **Export With Debug** unchecked. The preset is single-threaded and uses the Compatibility renderer, so it needs WebAssembly and WebGL 2 without cross-origin isolation headers. [Godot Web export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

The browser uses IndexedDB for the game's local saves. Saves belong to that browser profile and site origin. A hosted HTTPS URL has separate progress from localhost, a LAN URL, or the Windows game. Privacy settings or cleared site data can remove or prevent persistence. Some Safari devices may encounter WebGL issues or reload the tab under memory pressure. [Godot Web export limitations](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

The earlier Phase 2 export was exercised in Chrome over HTTP. For Phase 3, the updated gameplay screens pass the automated Godot UI suite at a 390 × 844 viewport, but this environment could not complete a browser request to its local server, so Web startup and browser IndexedDB persistence for this build remain unverified. Physical iPhone Safari compatibility has not been tested. On an iPhone, check that tapping name, quantity, and price fields opens the appropriate keyboard, swiping scrolls Market and Business, and your save survives closing and reopening the same Safari URL.

## Earlier browser prototype

Open `browser/index.html` in a desktop browser to run the earlier standalone prototype. The browser version has its own independent save.
