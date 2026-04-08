# RFC: DRY & Elegance Audit — 2026-04-08

## Status
Implemented

## Summary

Full audit of `Sources/` and `Tests/` (1 executable target, ~70 Swift files). **Total issues: 2 critical, 7 high, 8 medium, 4 low.** Top themes: (1) every ViewModel repeats the same structural boilerplate for history management, tileModel update guards, and string formatting that could be absorbed into the base class; (2) `MetricThresholds.swift` has 5 identical threshold structs that differ only in numeric literals; (3) `PMPSamplerProtocol`, `MetricTilePresenting`, and `DetailPresenting` are single-property protocols whose abstraction pays no dividend.

## Final Status

This audit has been fully implemented. The findings in this document remain useful as historical context, but there are no outstanding action items left from this report.

### Completed Refactor Work

- Replaced duplicated threshold implementations with shared threshold helpers in `MetricThresholds.swift`.
- Removed the single-purpose presentation protocols and their empty conformance extensions; dashboard detail and tile access now use direct concrete models.
- Removed `PMPSamplerProtocol` and simplified the ANE / Media Engine services to use the concrete sampler directly.
- Added shared formatting and update helpers, including `Double+Formatting`, `AppFormatters.byteCountString`, `ringBufferAppending`, and `assignIfChanged`.
- Added shared design tokens and tile chrome helpers, including `DashboardDesign` and `.tileCard()`, to reduce repeated view styling literals.
- Reworked ViewModels to store source-of-truth snapshots more directly and reduce redundant derived state, including the larger `WirelessViewModel` and `NetworkViewModel` cleanups.
- Replaced stringly-typed update lanes with a typed `UpdateLane` API.
- Consolidated repeated ViewModel test settle delays behind a shared async test helper.

### Final Validation

- `swift build` passed.
- `swift test` passed with 221 tests in 29 suites.
- `swiftlint lint --strict` passed with 0 violations.

### Notes

- The issue list below reflects the original audit state on 2026-04-08.
- The recommended action order is retained as historical planning context only; the work is complete.

---

## Issues

### Critical

#### [C1] `MetricTilePresenting` and `DetailPresenting` — zero-body protocols across 12 ViewModels
- **Smell**: Abstraction Smell — single-property protocols used only as type-erasers
- **Files**:
  - `Sources/Shared/Protocols/MetricTilePresenting.swift` lines 1–9
  - `Sources/Shared/Protocols/DetailPresenting.swift` lines 1–9
  - `Sources/Shared/Extensions/ViewModels+MetricTilePresenting.swift` lines 1–60 (24 empty conformance declarations)
- **Problem**: Both protocols expose exactly one property (`tileModel` / `detailModel`). All 12 conformers are declared via empty extension blocks added purely to satisfy the type system. The protocols serve as existential-erasing mechanisms (`any MetricTilePresenting`, `any DetailPresenting`) but the `any` usage sites are narrow enough to be replaced by a concrete generic or a direct property access pattern. The 24 empty extension lines contribute ceremony with zero logic.
- **Suggestion**: Collapse both into the existing `MonitorViewModelBase` as `@objc`-free requirements, or represent them as direct keyed access on `ServiceContainer` (e.g. `(any MetricTilePresenting)?` replaced by generic view helpers). At minimum, delete the empty extension file and move conformance declarations inline in each ViewModel.

---

#### [C2] Five identical `ThresholdEvaluating` structs in `MetricThresholds.swift`
- **Smell**: Structural Duplication — parallel structs with copy-paste bodies
- **Files**:
  - `Sources/Shared/Thresholds/MetricThresholds.swift` lines 6–16 (`CPUThreshold`), 19–29 (`GPUThreshold`), 72–82 (`AcceleratorThreshold`), 85–95 (`PowerThreshold`), 137–147 (`MediaEngineThreshold`)
- **Problem**: These five structs are byte-for-byte identical: `case ..<0.6: .normal`, `case ..<0.85: .warning`, `default: .critical`. Every future change to the shared threshold curve (e.g. raising the warning boundary to 0.9) must be applied five times. The remaining seven threshold types share the same two-boundary switch shape with only the numeric literals differing.
- **Suggestion**: Introduce a `LinearThreshold(normal: Double, warning: Double)` value type conforming to `ThresholdEvaluating`. Replace the five (or twelve) structs with `let cpuThreshold = LinearThreshold(normal: 0.6, warning: 0.85)` constants. Keep `BatteryThreshold` as the single hand-written case (inverted range logic).

---

### High

#### [H1] `WirelessViewModel` reimplements `MonitorViewModelBase` history logic manually
- **Smell**: Logic Duplication
- **Files**:
  - `Sources/ViewModels/WirelessViewModel.swift` lines 33, 149–163 (`updatedHistory`, `updatedExtendedHistory`)
  - `Sources/Shared/MonitorViewModelBase.swift` lines 42–53 (`appendRingBuffer`)
- **Problem**: `WirelessViewModel` doesn't inherit from `MonitorViewModelBase` (it manages two streams) and therefore re-implements full ring-buffer logic twice — `updatedHistory()` and `updatedExtendedHistory()` — which are functionally identical to `appendRingBuffer` in the base class. A future change to buffer size or ring semantics must be applied in three places.
- **Suggestion**: Extract `appendRingBuffer` to a free function or a `RingBuffer<T>` value type in `Shared/`, and consume it from both `MonitorViewModelBase` and `WirelessViewModel`.

---

#### [H2] `WirelessViewModel` — 10 `@ObservationIgnored` properties storing derived/redundant state
- **Smell**: Verbose & Inelegant
- **Files**:
  - `Sources/ViewModels/WirelessViewModel.swift` lines 18–38
- **Problem**: `wifiSSID`, `wifiRSSI`, `wifiOn`, `bluetoothConnectedCount`, `bluetoothOn`, `bluetoothPeripherals`, `history`, `extendedHistory`, `gaugeValue`, `signalLabel`, and `bluetoothLabel` are all stored + reassigned in `receive*` callbacks. Most are only read inside `detailModel` or `tileModel` builders — they are snapshot echoes, not independently meaningful reactive state. The view never directly observes them.
- **Suggestion**: Store only the last `WiFiSnapshot` and `BluetoothSnapshot`, and compute all labels/gauges on demand inside `tileModel` and `detailModel`. This cuts the property count from 10 to 2, removes two nearly-identical assignment blocks, and eliminates the bug surface where `signalLabel` and `tileModel` could temporarily disagree.

---

#### [H3] `if tileModel != newTileModel { tileModel = newTileModel }` guard repeated 13×
- **Smell**: Logic Duplication
- **Files**: All 11 `MonitorViewModelBase` subclasses and `WirelessViewModel` — e.g. `CPUViewModel.swift` line 31, `MemoryViewModel.swift` line 54, `NetworkViewModel.swift` lines 106/111, `WirelessViewModel.swift` lines 104/113.
- **Problem**: Three-line equality-guard pattern is copy-pasted into every `receive()` override with no variation. Any change (e.g. adding a transition animation on assignment) requires touching 13 files.
- **Suggestion**: Add `func updateTileModel(to newModel: MetricTileModel)` to `MonitorViewModelBase` that performs the guard; call it from each `receive()`.

---

#### [H4] `"%.1f%%"` format string repeated 8× across Services and ViewModels
- **Smell**: Constant & Literal Duplication
- **Files**:
  - `Sources/Services/CPU/CPUMonitorService.swift` line 8 (`percentLabel`)
  - `Sources/ViewModels/CPUViewModel.swift` line 48
  - `Sources/ViewModels/MemoryViewModel.swift` line 78
  - `Sources/ViewModels/GPUViewModel.swift` line 49
  - `Sources/ViewModels/DiskViewModel.swift` line 75
  - `Sources/ViewModels/BatteryViewModel.swift` lines 77, 100
  - `Sources/ViewModels/AcceleratorViewModel.swift` line 52
- **Problem**: The format string is scattered rather than centralised. `"%.1f°C"` (4× in `ThermalViewModel`) and `"%.0f RPM"` (2× in `FanViewModel`) are additional instances of the same smell.
- **Suggestion**: Add `extension Double` helpers: `func percentFormatted() -> String`, `func celsiusFormatted() -> String`, `func rpmFormatted() -> String` in `Shared/Extensions/Double+Formatting.swift`.

---

#### [H5] `PMPSamplerProtocol` — protocol with exactly one conformer
- **Smell**: Abstraction Smell — over-abstraction
- **Files**:
  - `Sources/Services/Accelerator/PMPSamplerProtocol.swift` lines 1–16
  - `Sources/Services/Accelerator/PMPSampler.swift` (sole conformer)
- **Problem**: The protocol exists in a one-to-one relationship with `PMPSampler`. It's injected into `AcceleratorMonitorService` and `MediaEngineMonitorService` for testability, but both services are already fully tested via mock `MetricMonitorProtocol` at the ViewModel level. The protocol adds an indirection layer that slows navigation and never benefits from substitution in practice.
- **Suggestion**: Delete `PMPSamplerProtocol`; use `PMPSampler` directly. If test-time injection is ever needed, a simple factory closure is sufficient.

---

#### [H6] `ByteCountFormatter` static setup duplicated in 3 ViewModels
- **Smell**: Structural Duplication / Constant Duplication
- **Files**:
  - `Sources/ViewModels/MemoryViewModel.swift` lines 7–11 (`.memory` style)
  - `Sources/ViewModels/DiskViewModel.swift` lines 7–11 (`.file` style)
  - `Sources/ViewModels/NetworkViewModel.swift` lines 9–13 (`.binary` style)
- **Problem**: Five-line boilerplate static initialiser is copy-pasted with only the `countStyle` differing. Adding any shared configuration (e.g. `includesUnit = true`) requires touching three files.
- **Suggestion**: Add `static func byteCountFormatter(style: ByteCountFormatter.CountStyle) -> ByteCountFormatter` to a shared `Formatters.swift` in `Shared/`, and call it from each ViewModel.

---

#### [H7] Tile `background {}` modifier block copy-pasted between `MetricTileView` and `NetworkTileView`
- **Smell**: Structural Duplication
- **Files**:
  - `Sources/Views/Components/MetricTileView.swift` lines 29–36
  - `Sources/Views/Dashboard/MetricTiles.swift` lines 72–79
- **Problem**: Byte-identical `background { RoundedRectangle(...).fill(Color.tileSurface).shadow(...); RoundedRectangle(...).strokeBorder(...) }` blocks. `NetworkTileView` was hand-crafted rather than reusing `MetricTileView`'s container — as a result the visual style can diverge.
- **Suggestion**: Extract a `tileBackground()` `ViewModifier` (or a `.tileCard()` extension on `View`) in `Shared/Extensions/` and apply it from both sites.

---

### Medium

#### [M1] Font size magic numbers scattered across 6+ view files
- **Smell**: Constant & Literal Duplication
- **Files**: `MetricTileView.swift` lines 44, 47; `MetricDetailView.swift` lines 24, 41; `MetricTiles.swift` lines 85, 88; `SettingsPanelView.swift` lines 50, 58; `MenuBarMetricsView.swift` lines 39, 42, 127 — sizes 10, 11, 12, 13, 14, 26 scattered throughout.
- **Problem**: No central font scale definition. Changing tile label size requires grepping every view file.
- **Suggestion**: Add `enum TileFont` or extend `Font` with semantic tile-specific cases (`tileTitleSize`, `tileValueSize`, `tileSubtitleSize`) in `Shared/Extensions/Font+Tile.swift`.

---

#### [M2] Padding/spacing magic numbers (10, 12, 14, 16) repeated 20+ times across view files
- **Smell**: Constant & Literal Duplication
- **Files**: `MetricDetailView.swift` (10×), `MenuBarMetricsView.swift` (6×), `SettingsPanelView.swift` (3×), `DashboardView.swift` (2×), `MetricTiles.swift` (3×).
- **Problem**: Most of these are consistent spacing rhythm values that belong in `MetricTileLayoutMetrics` or a `DesignTokens` enum. Currently making a global spacing adjustment requires a widespread grep.
- **Suggestion**: Extend `MetricTileLayoutMetrics` or add `DesignTokens.spacing` with named constants (`tileInner`, `sectionGap`, etc.).

---

#### [M3] `ThermalViewModel.receive()` computes CPU normalisation expression twice
- **Smell**: Logic Duplication / Verbose
- **Files**:
  - `Sources/ViewModels/ThermalViewModel.swift` lines 32–36
- **Problem**: `min(1.0, max(0.0, cpuCelsius / maxCelsius))` is written twice in the same function — once to produce `normalized` for `appendHistory`, once to assign `gaugeValue`.
- **Suggestion**: Compute once: `let normalized = snapshot.cpuCelsius.map { Self.normalize($0) } ?? 0`; reuse for both.

---

#### [M4] `DashboardUpdateBatcher` lane parameter is stringly-typed with no enforcement
- **Smell**: Abstraction Smell — leaky API
- **Files**:
  - `Sources/Shared/DashboardUpdateBatcher.swift` lines 1–40
  - `Sources/ViewModels/WirelessViewModel.swift` lines 69, 77 (magic strings `"wifi"`, `"bluetooth"`)
- **Problem**: All other ViewModels use the default lane; only `WirelessViewModel` passes `"wifi"` and `"bluetooth"`. A typo silently creates a new lane with its own coalescing queue. No enum or constant constrains valid lane names.
- **Suggestion**: Replace the `lane: String` parameter with `lane: UpdateLane = .default` where `UpdateLane` is an enum defined alongside `DashboardUpdateBatcher`.

---

#### [M5] `receive()` overrides in ViewModels store raw snapshot fields redundantly
- **Smell**: Verbose & Inelegant
- **Files**: `DiskViewModel.swift` lines 23–54, `MemoryViewModel.swift` lines 23–58, `FanViewModel.swift` lines 16–45, `ThermalViewModel.swift` lines 16–55, `PowerViewModel.swift` lines 16–43.
- **Problem**: Several ViewModels store 4–6 `@ObservationIgnored` properties that are plain echoes of snapshot fields (e.g. `usage`, `usedBytes`, `totalBytes`). These are only consumed inside `detailModel` — a computed property getter — yet they trigger assignment overhead on every poll tick.
- **Suggestion**: Store the last snapshot directly (`private var lastSnapshot: DiskSnapshot?`) and compute derived strings in `detailModel`'s getter. Reduces property count by 4–6 per ViewModel and eliminates stale-intermediate-value bugs.

---

#### [M6] `NetworkViewModel` maintains 5 separate history arrays
- **Smell**: Verbose & Inelegant
- **Files**:
  - `Sources/ViewModels/NetworkViewModel.swift` lines ~43–60
- **Problem**: `history`, `historyIn`, `historyOut`, `historyInGauge`, `historyOutGauge` are all updated in `receive()`. `historyInGauge` and `historyOutGauge` are normalised versions of `historyIn`/`historyOut` — they don't need independent storage, they can be computed with `map` at read time.
- **Suggestion**: Keep `historyIn` and `historyOut` as source of truth; replace the gauge-normalised histories with computed properties using `.map { normalize($0) }`.

---

#### [M7] Test `Task.sleep(for: .milliseconds(50))` repeated ~20 times across ViewModel tests
- **Smell**: Logic Duplication (tests)
- **Files**: `CPUViewModelTests.swift` (4×), `MemoryViewModelTests.swift` (4×), `GPUViewModelTests.swift` (3×), `DiskViewModelTests.swift` (3×), and 5 more files.
- **Problem**: The sleep duration is scattered as a magic literal. If the batcher coalescing window or polling rhythm changes, all ~20 sleep sites must be updated. One site using a too-short sleep causes a flaky test.
- **Suggestion**: Define `static let testSettleDelay: Duration = .milliseconds(50)` in a test helper file and replace all literals.

---

#### [M8] Opacity constants 0.07 (tile border), 0.45 (backdrop) each repeated 4–5 times
- **Smell**: Constant & Literal Duplication
- **Files**: `MetricTileView.swift` (2×), `MetricTiles.swift` (2×), `MenuBarMetricsView.swift` (1×) for `0.07`; `MetricDetailView.swift` + `DashboardView.swift` for `0.45`.
- **Problem**: These are semantic design tokens (tile chrome opacity, modal scrim opacity) presented as anonymous numbers.
- **Suggestion**: Add to `DesignTokens` or directly to a `Color` extension: `Color.tileBorder` (primary.opacity(0.07)), `Color.modalScrim` (black.opacity(0.45)).

---

### Low

#### [L1] `ServiceContainer` undocumented as composition root vs. DI container
- **Smell**: Abstraction Smell — misleading name
- **Files**:
  - `Sources/ViewModels/ServiceContainer.swift` lines 1–35
- **Problem**: The name implies lifecycle management and injection; the implementation is a flat list of `let` properties constructed eagerly. No lazy init, no protocol injection, no scope management. Adds mild cognitive confusion when reading new code.
- **Suggestion**: Rename to `AppEnvironment` or document with a clear comment: "Composition root — creates and wires all services at app launch."

---

#### [L2] Spring animation parameters duplicated in `DashboardView`
- **Smell**: Constant Duplication
- **Files**:
  - `Sources/Views/Dashboard/DashboardView.swift` lines 20, 110
- **Problem**: Two slightly different spring configs (`(0.32, 0.82)` and `(0.28, 0.85)`) both live inline. No semantic names distinguish "tile expand" from "tile dismiss."
- **Suggestion**: Pull into `Animation` extension constants: `Animation.tileReveal`, `Animation.tileDismiss`.

---

#### [L3] `34×34` ring gauge frame size hard-coded in two view files
- **Smell**: Constant & Literal Duplication
- **Files**:
  - `Sources/Views/Components/MetricTileView.swift` line 57
  - `Sources/Views/Dashboard/MetricTiles.swift` line 98
- **Problem**: Ring gauge size is part of tile layout metrics but escapes `MetricTileLayoutMetrics`. A resize requires two edits.
- **Suggestion**: Add `static let ringGaugeSize: CGFloat = 34` to `MetricTileLayoutMetrics`.

---

#### [L4] `"wifi"` / `"bluetooth"` lane strings undocumented and untested
- **Smell**: Constant & Literal Duplication (covered by M4 at system level; isolated occurrence worth noting)
- **Files**:
  - `Sources/ViewModels/WirelessViewModel.swift` lines 69, 77
- **Problem**: Same magic-string smell at the specific usage site. Addressed by M4's enum fix.
- **Suggestion**: Resolved if M4 implemented.

---

## Recommended Action Order

1. **[C2]** Collapse 5+ identical threshold structs into `LinearThreshold` — pure data, zero risk, removes ~80 lines immediately.
2. **[H7]** Extract `.tileCard()` ViewModifier — one-line fix at two sites, prevents visual divergence between `MetricTileView` and `NetworkTileView`.
3. **[H3]** Add `updateTileModel(to:)` to `MonitorViewModelBase` — touches 11 files but each change is a 3-line-to-1-line simplification with identical behaviour.
4. **[H4]** Add `Double+Formatting.swift` extension — removes ~15 scattered format strings, improves i18n posture.
5. **[H6]** Add shared `ByteCountFormatter` factory — trivial 5-line change, reduces 3 boilerplate statics.
6. **[H1] + [H2]** Refactor `WirelessViewModel` — extract ring-buffer util, store snapshots directly, drop 8 derived properties. Highest complexity but high elegance payoff.
7. **[H5]** Delete `PMPSamplerProtocol` — safe deletion, reduces file count.
8. **[C1]** Dissolve `MetricTilePresenting` / `DetailPresenting` empty conformance extensions — requires deciding on replacement pattern first; do after H2 is done and the tile-access idiom is clear.
9. **[M4]** Typed `UpdateLane` enum — small, safe, improves API robustness.
10. **[M1] + [M2] + [M8]** Design token consolidation — polish pass, do last.

---

## Out of Scope

- **`Views/`** rendering logic (sparkline CALayer, ring gauge layer) — CALayer APIs are inherently imperative; `map`/`flatMap` suggestions don't apply.
- **`App/`** entry point (`AppDelegate`, `PerformanceDashboardApp`) — single-use glue code, no DRY targets.
- **`MenuBarExtra`** views — out-of-scope UI surface; not part of the dashboard tile system being audited.
- **IOKit service wrappers** (`SMCBridge`, `IOReportBridge`) — low-level C-interop; idiomatic Swift patterns don't apply to unsafe memory sections.
