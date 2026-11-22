# Global Ultra Compact V4 Verification Evidence

These screenshots were captured from the Godot 4.7.2 Release Web export served locally at `http://127.0.0.1:8060/` in Chromium. The QA browser used the existing disposable test profile and its PR #33 DevTools QA company. The production site was not opened or changed.

| Evidence | Viewport | Screen |
| --- | ---: | --- |
| `dashboard-desktop-1366x768.png` | 1366×768 | Dashboard header and KPI layout |
| `dashboard-mobile-390x844.png` | 390×844 | Dashboard header and cards |
| `dashboard-mobile-landscape-844x390.png` | 844×390 | Dashboard header and compact landscape layout |
| `buy-inventory-desktop-1366x768.png` | 1366×768 | Market / Quick Purchase category step |
| `buy-inventory-mobile-390x844.png` | 390×844 | Market / Quick Purchase category step |
| `navigation-mobile-390x844.png` | 390×844 | Main navigation drawer |

The browser checks recorded no JavaScript errors. Canvas and document dimensions matched the tested viewport on all three layouts, with no document-level horizontal overflow. Automated Godot coverage now includes the runtime typography validator, which checks 120 visible screen/layout combinations in Standard and Large Text modes; its measured maxima were 14 px in Standard and 14 px in Large Text mode. The Large Text setting uses the approved category sizes (13 px captions, 14 px buttons/descriptions/body/navigation/inputs/headings/financial values) and the absolute cap is 14 px in both modes. All 34 regression/UI suites report zero assertion failures, including global control styling, navigation, Buy Inventory, Developer Mode, and header suites. The Release Web export completed successfully.

During this run, `dashboard_inventory_test` reported zero test failures but emitted Godot CanvasItem/ObjectDB/resource cleanup warnings at process exit. These warnings do not fail the suite.
