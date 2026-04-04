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

- [ ] **6. Verify all 7 tiles fit on a 13" display without scrolling**  
  Run the app at 1280×800, check nothing clips. Tune the `minimum` adaptive grid size if needed.

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
