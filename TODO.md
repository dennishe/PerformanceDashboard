# PerformanceDashboard — Roadmap

Tracks outstanding work from current state to a fully functional dashboard.  
Legend: 🔴 Correctness · 🟡 UI/UX & Polish · 🟢 Testing & Code Quality

---

## 🔴 Correctness

- [x] **0. App shows no UI when launched via `swift run`** *(fixed)*  
  SPM executables run as CLI processes — macOS doesn't promote them to foreground GUI apps without an app bundle or an explicit activation call. Fixed by adding `AppDelegate` with `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)`, wired in via `@NSApplicationDelegateAdaptor`.

- [x] **1. Verify GPU tile shows real values** *(verified)*  
  Confirmed `Device Utilization %` key is present in the IOAccelerator `PerformanceStatistics` dict on this machine — `GPUMonitorService` is correct.

- [x] **2. Discover real ANE keys** *(resolved)*  
  ANE data is read via IOReport channels (channel name `"ANE"`) in `AcceleratorMonitorService`; no plain IOKit key lookup needed.

- [x] **3. Fix Task.sleep cancellation in all 6 services** *(fixed)*  
  Replaced `try? await Task.sleep(...)` with `do { try await Task.sleep(...) } catch { break }` so poll loops exit promptly on cancellation.

- [x] **4. Move `MockMonitors.swift` out of `Sources/`** *(fixed)*  
  Wrapped all mock types in `#if DEBUG` so they are excluded from release builds.

- [x] **5. Fix fragile entitlements path in `Package.swift`** *(fixed)*  
  Moved `PerformanceDashboard.entitlements` from `Sources/` to the project root and updated the linker flag accordingly.

---

## 🟡 UI/UX

- [x] **7. Enforce minimum window size** *(fixed)*  
  Added `.frame(minWidth: 730, minHeight: 400)` on the root view and `.windowResizability(.contentMinSize)` on the scene.

- [x] **8. Hide ANE tile on Intel** *(fixed)*  
  Wrapped the ANE `MetricTileView` with `#if arch(arm64)` in `DashboardView`.

- [x] **9. Fix ring gauge colour for unavailable metrics** *(fixed)*  
  Changed `gaugeValue` in `MetricTileView` to `Double?`. Ring and sparkline use `.secondary` (grey) when the value is `nil`.

- [x] **10. Animate value label transitions** *(fixed)*  
  Added `.contentTransition(.numericText())` to the value `Text` in `MetricTileView`.

- [ ] **11. Clarify Network In / Network Out tiles**  
  Two separate tiles for one logical metric is potentially confusing. Consider combining into a single tile with two rows, or make the distinction visually clearer.

---

## 🟡 Polish

- [ ] **12. Add an app icon**  
  Create an `AppIcon.appiconset` asset so the app shows a proper icon in the Dock and App Switcher.

- [x] **13. Add a window title or subtitle** *(fixed)*  
  Changed `WindowGroup` to `WindowGroup("Performance Dashboard")` and re-enabled `showsTitle: true`.

- [x] **14. Pause polling when window is minimised** *(fixed)*  
  Replaced `.task { await startAll() }` with `.onChange(of: scenePhase, initial: true)` — starts all monitors when `.active`, stops them on any other phase.

---

## 🟡 Product Enhancements

- [ ] **26. Add a detail view for each metric tile**  
  The current dashboard works well for scanning, but every metric is compressed into the same small footprint. Add a drill-down interaction so clicking a tile opens a richer metric-specific view with a larger chart, more historical context, and derived stats that do not fit in the dashboard grid.

  Suggested scope:
  - Clicking a tile animates the tile to fill more tiles or the whole app, depending on what to show.
  - Show a larger sparkline or time-series chart with selectable ranges such as 60 seconds, 5 minutes, and 15 minutes, or depending on context more detailed information that is not already visible. F.ex. what app is causing the load or for the battery tile, if possible, show other attached battery devices such as mice or wireless keyboards.
  - Add metric-specific secondary values. Examples: CPU user/system split, Memory used/wired/compressed, Disk free space trend, Wi-Fi RSSI plus channel, Battery health and cycle count.
  - Keep the implementation aligned with the existing MVVM split by adding per-metric detail presenters or a reusable detail model rather than embedding formatting logic directly in the view.

  Why this matters:
  - Preserves the compact single-screen dashboard while still allowing deeper inspection.
  - Makes the app more useful during diagnosis, not just passive monitoring.
  - Creates a natural place for future features such as history persistence or exports.

- [ ] **27. Consolidate and deepen Network monitoring**  
  Network In and Network Out are currently shown as two separate tiles for one logical subsystem. Combine them into a single network tile with clearer visual hierarchy, then deepen the feature so it can answer more than total bytes per second.

  Suggested scope:
  - Replace the two-tile layout with one tile that shows inbound and outbound throughput together.
  - Use separate rows, labels, and colours so the distinction is obvious at a glance.
  - Add per-interface breakdown support for Wi‑Fi, Ethernet, VPN, and other active interfaces where available.
  - Show a compact top-line total in the dashboard and reserve interface-level detail for the metric detail view.
  - Continue filtering irrelevant traffic such as loopback unless explicitly enabled for diagnostics.

  Why this matters:
  - Fixes an existing UX ambiguity already noted in this roadmap.
  - Uses dashboard space more efficiently.
  - Makes network activity easier to interpret during real-world tasks such as downloads, video calls, backups, or VPN usage.

- [ ] **28. Make the dashboard customizable**  
  Different users care about different signals. Add lightweight customization so the dashboard can adapt without fragmenting the core experience.

  Suggested scope:
  - Let users hide rarely used tiles and reorder visible tiles.
  - Support compact and comfortable density presets to balance readability against information density.
  - Allow users to pin a small set of favourite metrics into the menu bar view.
  - Persist layout and visibility preferences between launches using a simple local settings model.
  - Keep defaults opinionated so first launch remains clean even if the customization UI is never used.

  Why this matters:
  - Improves day-to-day usefulness without requiring new monitoring backends.
  - Helps the app fit both smaller laptop screens and larger external displays.
  - Creates a path for advanced users without making the base product more complex for everyone else.

- [ ] **29. Improve product polish and shell quality**  
  Beyond the core metrics, the app still needs a more finished product shell. Focus this work on visual identity, unavailable-state handling, and small UI quality issues, but do not add onboarding flows.

  Suggested scope:
  - Add a proper app icon for Dock, App Switcher, and release builds.
  - Improve empty and unavailable states so unsupported metrics explain why they are missing or disabled instead of merely disappearing or appearing inactive.
  - Review copy, labels, spacing, and threshold messaging for consistency across all tiles.
  - Validate the dashboard layout on smaller displays and tune grid behaviour where needed.
  - Audit accessibility labels and values so all gauges and compact views remain understandable with assistive technologies.

  Why this matters:
  - Raises the perceived quality of the app without changing its architecture.
  - Makes unsupported hardware cases feel intentional instead of broken.
  - Reduces friction when moving from a developer tool to something that feels release-ready.

---

## � New Tiles

- [x] **20. Power draw tile** *(done)*  
  `PowerMonitorService` + `PowerViewModel` + `PowerTileView` implemented.

- [x] **21. Fan speed tile** *(done)*  
  `FanMonitorService` + `FanViewModel` + `FanTileView` implemented.

- [x] **22. Temperatures tile** *(done)*  
  `ThermalMonitorService` + `ThermalViewModel` + `ThermalTileView` implemented.

- [x] **23. Battery tile** *(done)*  
  `BatteryMonitorService` + `BatteryViewModel` + `BatteryTileView` implemented. Tile hides gauge when no battery present.

- [x] **24. Media Engine tile** *(done, Apple Silicon only)*  
  `MediaEngineMonitorService` + `MediaEngineViewModel` + `MediaEngineTileView` implemented. Gated with `#if arch(arm64)`.

- [x] **25. Wi-Fi / Bluetooth signal tile** *(done)*  
  `WirelessMonitorService` + `WirelessViewModel` + `WirelessTileView` implemented.

---

## ��� Testing

- [x] **15. Test `stream()` + `stop()` lifecycle on each service** *(fixed)*  
  Added `service_conformsToProtocol()` + `stream_canBeStartedAndStopped()` to all 12 service test suites (CPU, GPU, Memory, Network, Disk were missing; pre-existing `let _` lint violations also fixed).

- [x] **16. Test ViewModel `stop()` paths** *(fixed)*  
  Added a `stop_haltsUpdates()` test to all 6 ViewModel test files.

- [x] **17. Extract Network throughput normalisation into ViewModel** *(fixed)*  
  Added `inGauge`, `outGauge`, `historyInGauge`, `historyOutGauge` to `NetworkViewModel`. `DashboardView` now uses these instead of inline `min(/ 100_000_000, 1)` calls. Tests added for normalised gauge values.

---

## 🟢 Code Quality

- [x] **18. Reduce `DashboardView` duplication** *(fixed)*  
  Introduced `MetricTilePresenting` protocol (`Shared/Protocols/`) and mapped all 11 non-Network ViewModels to it via `Shared/Extensions/ViewModels+MetricTilePresenting.swift`. `MetricTiles.swift` now uses a single `MonitorTileView<VM>` generic with `typealias` per metric; Network tiles remain explicit (two tiles, one ViewModel).

- [x] **19. Remove spurious `async` from `startAll()`** *(fixed)*  
  Removed `async` from `startAll()` and replaced `.task { await startAll() }` with `.onChange(of: scenePhase, initial: true)` (see item 14).
