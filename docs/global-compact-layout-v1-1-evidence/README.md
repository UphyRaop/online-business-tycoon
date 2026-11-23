# Global Compact Layout V1.1 — Browser Evidence

Screenshots are from the Godot 4.7.2 Release Web export, served locally over HTTP in Chromium. They use a disposable local QA profile at `127.0.0.1:8060`; no production origin or player save was changed.

## Before / after

The prior captures show Profile values stacked beneath their labels and large title-to-content gaps:

- [Before: Profile, 390×844](../pr33-evidence/routes/profile-readonly-390.png)
- [After: Profile, 390×844](profile-mobile-390.png)
- [Before: Expenses, desktop](../pr33-evidence/routes/finance-expenses-empty.png)
- [After: Expenses, 390×844](expenses-mobile-390.png)

## Required screen captures

- Mobile: [CEO Profile](profile-mobile-390.png), [Expenses](expenses-mobile-390.png), [Marketing](marketing-mobile-390.png), [Company Management](company-management-mobile-390.png), [Dashboard](dashboard-mobile-390.png), [Market](market-mobile-390.png)
- Desktop: [Dashboard 1366×768](dashboard-desktop-1366.png), [Profile 1366×768](profile-desktop-1366.png), [Main Menu 1366×768](main-menu-desktop-1366.png)
- Mobile landscape: [Expenses 844×390](expenses-landscape-844x390.png)

The QA save has no completed operating days, so Expenses correctly shows its real empty state. A temporary UI-only “Layout QA Amount” row is created inside the Phase 4 automated test to verify populated expense-row geometry; it is never saved and does not touch simulation or financial data.

## Measured layout geometry

The Phase 4 runtime test measures Godot control rectangles after layout at the responsive test sizes. Representative measurements:

| Screen | Viewport | Label/value row width | Parent width | Right aligned | Header to title | Title to tabs | Tabs to first content |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| CEO Profile | 1366×768 | 894 px | 894 px | Yes | 3 px | No tabs | 4 px |
| CEO Profile | 390×844 | 382 px | 382 px | Yes | 3 px | No tabs | 4 px |
| Expenses | 1366×768 | 525 px | 525 px | Yes | 3 px | 4 px | 4 px |
| Expenses | 390×844 | 386 px | 386 px | Yes | 3 px | 4 px | 4 px |
| Marketing | 1366×768 | — | — | — | 3 px | 4 px | 4 px |
| Company Management | 390×844 | — | — | — | 3 px | 4 px | 4 px |

Profile has no secondary tabs; its first content card follows the page title by 4 px. Settings tests the no-tabs/no-content-wrapper case as well.

## Browser verification

- Chromium loaded the local Release Web export without page errors.
- Dashboard, Profile, Market, Marketing, Company Management, and Expenses were opened through game navigation and captured at the viewports listed above.
- The persistent zero-height navigation slot was confirmed as an extra title-to-tab gap: VBox separation was applied even while the slot height was zero. Empty page wrappers could also retain separators. Closed/empty wrappers are now hidden from container layout.
- The Web canvas and document width matched the viewport at all requested browser sizes; no horizontal document overflow occurred. Secondary tabs remain in their horizontal scroll view.
- Viewport testing used Chromium emulation/resizing, not physical iPhone Safari.

## Verification results

- `bash .github/scripts/build-web.sh`: 34 regression/UI suites, all reporting 0 assertion failures; Godot 4.7.2 Release Web export succeeded.
- Runtime typography validation: 120 visible screen/layout checks passed; Standard and Large Text maximum remain 14px.
- Phase 4 geometry checks: passed at all 10 suite viewport sizes, including 360×800, 390×844, 430×932, 844×390, 768×1024, 1024×768, 1366×768, and 1920×1080.
- Chromium browser matrix: 360×800, 390×844, 430×932, 844×390, 768×1024, 1024×768, 1366×768, and 1920×1080. At each size, the document/canvas matched the viewport width, with no document-level horizontal overflow or browser page errors.
- The dashboard inventory test still reports its existing shutdown leak diagnostics (2 CanvasItem RIDs, 8 ObjectDB instances, 1 resource in use) after its 0-failure result. This warning is unrelated to the layout assertions and did not prevent the export.
- Physical iPhone Safari: not tested.
