# Navigation and scrolling — Ediz OS 0.3.1

The web companion now uses persistent chrome and one contained scrolling surface. Each destination restores its scroll position and module selection. Task rows are stable component instances; an editor or notification no longer remounts every row. Assistant conversations survive tab switches. Navigation uses a short transform/opacity entrance with reduced-motion support. Completion no longer animates layout dimensions. Scrolling content retains glass fills and highlights without live backdrop filters on each control and message. Live glass remains on navigation and overlays.

## Verification

- 16 unit/database/assistant tests passed.
- 12 browser workflows: existing offline capture/edit/search/backup/module/focus/assistant/drag-dock tests plus long-list navigation continuity, stable rows, conversation preservation and stationary chrome.
- Actual Chromium screenshots reviewed at 402 × 874 and 1440 × 1000.
- Isolated 500-record test with 4× CPU throttling: both builds had 16.7 ms p95 requestAnimationFrame intervals and no sampled intervals over 34 ms. The old build remounted rows when the editor opened; the revised build retained them. The reported physical-iPhone stutter was not reproduced by this headless check. These measurements do not establish Safari, ProMotion or device performance.
- The native SwiftUI app is unchanged from its successful iPhone 17 Pro simulator checks: 18 core tests, 7 UI tests, unsigned physical-device archive. New installation helper has shell syntax validation only; its signing/device actions require an authorized Mac and have not run here.

## Interaction references

Reviewed the public Apple Human Interface Guidelines motion reference and Things feature presentation. Persistent context, direct navigation, restrained movement and useful keyboard behavior guided this repair; no third-party components or private app screens were copied.

- https://developer.apple.com/design/human-interface-guidelines/motion
- https://culturedcode.com/things/features/

## Remaining device check

On the owner's signed native build, verify momentum scrolling, swipe-back, sheet dismissal, keyboard transitions and dock scrubbing on the physical iPhone 17 Pro. The current Linux workspace cannot access the owner's Mac, device, signing identity or App Store Connect account. Having a Developer membership alone does not grant this workspace access.
