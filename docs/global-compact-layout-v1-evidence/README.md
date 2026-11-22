# Global Compact Layout V1 — Visual Evidence

Screenshots were captured from the Godot 4.7.2 Release Web export served locally over HTTP in Chromium. The browser used a persistent disposable QA profile containing the existing `PR33 DevTools QA Company` save. No production origin, player save, game data, or deployment was changed.

## Before / after references

The pre-change Dashboard captures from the existing Ultra Compact V4 evidence set are [desktop 1366×768](../ultra-compact-v4-evidence/dashboard-desktop-1366x768.png) and [mobile 390×844](../ultra-compact-v4-evidence/dashboard-mobile-390x844.png). Current captures are [desktop Dashboard](dashboard-1366x768.png), [mobile Dashboard](dashboard-390x844.png), and [short landscape Dashboard](dashboard-844x390.png). The updated shared layout uses a 10px card inset (previously 12px), 6px information-row / card-content spacing, 10px card-grid spacing, and consistent 10px card corner radii. Buttons retain their 44px minimum touch target.

## Current captures

- [Dashboard 1366×768](dashboard-1366x768.png)
- [Dashboard 390×844](dashboard-390x844.png)
- [Dashboard 844×390](dashboard-844x390.png)
- [Main Navigation open, desktop 1366×768](navigation-desktop-1366.png)
- [Main Navigation open, mobile 390×844](navigation-mobile-390.png)
- [Market and Buy Inventory category step, desktop 1366×768](market-desktop-1366.png)
- [Market and Buy Inventory category step, mobile 390×844](market-mobile-390.png)
- [Electronics selected by browser tap](market-category-selected-mobile-390.png)
- [Filtered product step with persistent Back/Continue footer](market-product-mobile-390.png)

## Browser viewport checks

The same loaded gameplay session was resized through 360×800, 390×844, 430×932, 844×390, 768×1024, 1024×768, 1366×768, and 1920×1080. At each size the HTML document and Web canvas matched the viewport dimensions, no document-level horizontal overflow was present, and no Chromium page errors were logged. Screenshots are retained for mobile portrait, mobile landscape, and desktop.

These are Chromium desktop-browser viewport checks, including resized mobile viewports; they are not physical iPhone Safari tests. The browser checks verify layout bounds and representative real navigation clicks, while the Godot suites exercise the broader screen and responsive layout matrix. A real browser tap selected Electronics and Continue opened its filtered product list; the footer remained visible while product content scrolled.
