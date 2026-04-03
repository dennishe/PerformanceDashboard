# PerformanceDashboard — Roadmap

Tracks outstanding work from current state to a fully functional dashboard.  
Legend: 🔴 Correctness · 🟡 UI/UX & Polish · 🟢 Testing & Code Quality

---

## 🔴 Correctness

- [x] **0. App shows no UI when launched via `swift run`** *(fixed)*  
  SPM executables run as CLI processes — macOS doesn't promote them to foreground GUI apps without an app bundle or an explicit activation call. Fixed by adding `AppDelegate` with `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)`, wired in via `@NSApplicationDelegateAdaptor`.

- [ ] **1. Verify GPU tile shows real values**  
  Run `ioreg -l -n IOAccelerator | grep "Device Utilization"` to confirm the IOKit key name on this machine matches what `GPUMonitorService` reads. Fix key if needed.

- [ ] **2. Discover real ANE keys**  
  Run `ioreg -l -n ANE0 | grep -i "util\|power\|load"` to find the actual key names on this machine. Update `AcceleratorMonitorService` with correct keys.

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

- [ ] **20. Power draw tile**  
  Read total system power via SMC key `PSTR` (or `PDTR` on Apple Silicon). Display watts with a sparkline. Gate on key availability; gracefully degrade if absent.

- [ ] **21. Fan speed tile**  
  Read fan RPMs via SMC keys `F0Ac`, `F1Ac`, etc. Show RPM per fan and % of max (`F0Mx`). Handle Macs with zero fans (MacBook Air M-series) gracefully.

- [ ] **22. Temperatures tile**  
  Read CPU die and GPU die temperatures via SMC. Display in °C with threshold colour coding (green → orange → red). Key names differ between Intel and Apple Silicon — detect at runtime.

- [ ] **23. Battery tile**  
  Show charge %, health (design vs current capacity), cycle count, and charging/discharging state + time-to-empty via `IOPMPowerSource` / `IOKit`. Hide tile entirely on desktop Macs (no battery present).

- [ ] **24. Media Engine tile** *(Apple Silicon only)*  
  Report H.264/HEVC encode and decode engine utilisation via IOKit (`AppleAVD` / `AppleVXD`). Follow the same IOReport pattern used for the ANE tile. Gate with `#if arch(arm64)`.

- [ ] **25. Wi-Fi / Bluetooth signal tile**  
  Show current Wi-Fi RSSI and channel via `CoreWLAN` (`CWWiFiClient`). Show connected Bluetooth device count / RSSI via `IOBluetooth`. Combine into a single "Wireless" tile with two rows.

---

## ��� Testing

- [ ] **15. Test `stream()` + `stop()` lifecycle on each service**  
  Write async tests that call the real `stream()`, collect one emission via `for await`, then call `stop()`. This covers the poll-loop infrastructure currently at 0%.

- [x] **16. Test ViewModel `stop()` paths** *(fixed)*  
  Added a `stop_haltsUpdates()` test to all 6 ViewModel test files.

- [x] **17. Extract Network throughput normalisation into ViewModel** *(fixed)*  
  Added `inGauge`, `outGauge`, `historyInGauge`, `historyOutGauge` to `NetworkViewModel`. `DashboardView` now uses these instead of inline `min(/ 100_000_000, 1)` calls. Tests added for normalised gauge values.

---

## 🟢 Code Quality

- [ ] **18. Reduce `DashboardView` duplication**  
  The 7 `MetricTileView` call-sites are repetitive. Introduce a `MetricTileViewModel` protocol or a helper method to reduce boilerplate while keeping type safety.

- [x] **19. Remove spurious `async` from `startAll()`** *(fixed)*  
  Removed `async` from `startAll()` and replaced `.task { await startAll() }` with `.onChange(of: scenePhase, initial: true)` (see item 14).
