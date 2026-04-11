# Architecture Friction RFC — PerformanceDashboard

**Date**: 2026-04-11  
**Status**: Mostly implemented  
**Scope**: All non-UI source files under `Sources/`

---

## Overview

This RFC documents eight architectural friction points found during a systematic codebase review.
They are ordered by severity: coupling blast radius, testability impact, and how much the pattern
recurs across the codebase.

Each item follows the same structure:

- **Problem** — the friction and its root cause
- **Proposed resolution** — the preferred interface/restructuring
- **Dependency category** — in-process / local-substitutable / ports & adapters / mock
- **Testing strategy** — what to add, delete, and rewrite
- **Rollout checklist** — concrete file-level steps

## Implementation Status — 2026-04-11

Completed in code:

- Issue 1 — injectable update scheduling, lane removal, and regression tests
- Issue 2 — `ServiceContainer` metric registration plus container lifecycle test coverage
- Issue 3 — `MetricThresholds` namespace, call-site migration, and shared threshold tests
- Issue 4 — `WirelessViewModel` now inherits from `MonitorViewModelBase` via `ZipMonitor`
- Issue 5 — `PollingMonitorBase` now owns the loop; services override `sample()` instead of `poll(continuation:)`
- Issue 6 — shared `MetricSnapshot` contract and conformance coverage
- Issue 7 — `SMCReading` abstraction with mock-backed hardware-path tests
- Issue 8 — `MetricTileModel` is now a computed view contract instead of stored parallel state

Validation:

- `swift test` passes: 383 tests in 40 suites
- `swiftlint lint --strict` passes

---

## Issue 1 — `DashboardUpdateBatcher` is a hardwired global singleton

**Final status**: Implemented.

### Problem

Every ViewModel—and `WirelessViewModel` in two separate places—calls
`DashboardUpdateBatcher.shared.enqueue(...)` directly.
`MonitorViewModelBase` embeds this call at its core and `WirelessViewModel`
calls it for both its `.wifi` and `.bluetooth` lanes.

Because `shared` is a `private init()` singleton with no injection point, it is
impossible to:

- Observe that coalescing actually fires (no hook into the flush cycle)
- Control timing in tests (flush interval is hardcoded at `Constants.updateCoalescingInterval`)
- Substitute a no-op batcher in unit tests that care only about `receive()` correctness

The `UpdateLane` enum (`default`, `wifi`, `bluetooth`) exists solely to serve
`WirelessViewModel`'s dual-stream topology—it is not a generally useful concept
and adds cognitive surface area to every reader of `DashboardUpdateBatcher`.

**Files involved**:
`Sources/Shared/DashboardUpdateBatcher.swift`,
`Sources/Shared/MonitorViewModelBase.swift`,
`Sources/ViewModels/WirelessViewModel.swift`

**Dependency category**: In-process (pure in-memory state, zero I/O)

### Proposed resolution

Make `DashboardUpdateBatcher` injectable through `MonitorViewModelBase.init`.
Keep the default `shared` instance for production; inject a pass-through or
synchronous batcher in tests.

```swift
// New protocol (or concrete replaceable type)
@MainActor
protocol UpdateScheduling: AnyObject {
    func enqueue(owner: AnyObject, update: @escaping () -> Void)
    func cancel(owner: AnyObject)
}

// MonitorViewModelBase gains an optional injected dependency
open class MonitorViewModelBase<Snapshot: Sendable> {
    public init(
        monitor: some MetricMonitorProtocol<Snapshot>,
        batcher: UpdateScheduling = DashboardUpdateBatcher.shared
    ) { … }
}
```

Remove `UpdateLane` entirely. `WirelessViewModel`'s two streams can share
one lane because the batcher already keys by `(ownerID, lane)` and collapsing
to a single lane makes the coalescing strictly simpler: the last WiFi or BT
update within the window wins—which is correct behaviour.

### Testing strategy

**New tests to add**:
- `DashboardUpdateBatcherTests` — verify that N rapid enqueues produce a single
  flush, and that `cancel()` prevents a pending update from firing
- `MonitorViewModelBaseTests` — inject a `SynchronousBatcher` (fires immediately,
  no `Task.sleep`) and assert that `receive()` is called synchronously after
  `enqueue()`

**Old tests to simplify**:
- All ViewModel tests can drop their `await waitForAsyncUpdates()` scaffolding
  once a synchronous batcher is injected—the async round-trip is no longer
  needed for correctness checks

**Relevant test file**:
`Tests/PerformanceDashboardTests/ViewModels/ViewModelTestSupport.swift`

### Rollout checklist

- [x] Add `UpdateScheduling` protocol to `Sources/Shared/DashboardUpdateBatcher.swift`
- [x] Add `SynchronousBatcher` test double to `Tests/…/ViewModels/ViewModelTestSupport.swift`
- [x] Thread `batcher:` parameter through `MonitorViewModelBase.init`
- [x] Remove `UpdateLane` enum; collapse `WirelessViewModel` to the default lane
- [x] Delete `lane:` parameter from `enqueue(owner:lane:update:)` and all call sites
- [x] Update `WirelessViewModel` to pass the injected batcher
- [x] Write `DashboardUpdateBatcherTests`
- [x] Run `swift test`

---

## Issue 2 — `ServiceContainer` repeats each metric in four places

**Final status**: Implemented.

### Problem

Adding a new metric to the dashboard requires edits in exactly four locations
inside `ServiceContainer.swift`, plus the service and ViewModel files themselves:

1. `let <name> = <Name>ViewModel(monitor: <Name>MonitorService())`
2. `<name>.start()` inside `startAll()`
3. `<name>.stop()` inside `stopAll()`
4. The call site in `DashboardView` that reads `container.<name>.tileModel`

There is no registration mechanism, so the compiler cannot tell you if you forgot
step 2 or 3. The current `startAll` / `stopAll` implementations are two lines
of semicolon-separated calls each—easy to add and easy to forget.

`ServiceContainer` is also the only entry path for the full graph, making it
impossible to write an integration test that verifies a single metric end-to-end
with mock services.

**Files involved**:
`Sources/ViewModels/ServiceContainer.swift`,
`Sources/Views/Dashboard/DashboardView.swift` (and all related tile views)

**Dependency category**: In-process

### Proposed resolution

Introduce a `MetricEntry` value type that bundles a `start` / `stop` closure pair
and collect them at initialisation time. `ServiceContainer` becomes a loop over
the array rather than a hand-enumerated list.

```swift
// Each metric registers itself as a pair of closures
private struct MetricEntry {
    let start: () -> Void
    let stop:  () -> Void
}

@MainActor
@Observable
final class ServiceContainer {
    let cpu        = CPUViewModel(monitor: CPUMonitorService())
    let gpu        = GPUViewModel(monitor: GPUMonitorService())
    // …

    private lazy var entries: [MetricEntry] = [
        .init(start: cpu.start,    stop: cpu.stop),
        .init(start: gpu.start,    stop: gpu.stop),
        // …
    ]

    func startAll() { entries.forEach { $0.start() } }
    func stopAll()  { entries.forEach { $0.stop() } }
}
```

This eliminates the manual semicolon lists and makes it structurally impossible
to forget `stop` when `start` is registered and vice-versa. The stored VMs remain
as named properties, so `DashboardView` access patterns (`container.cpu.tileModel`)
are unchanged.

### Testing strategy

**New tests to add**:
- `ServiceContainerTests` — construct a container with all-mock services; call
  `startAll()` then `stopAll()`; assert that each mock's `streamCallCount` and
  `stopCallCount` equal 1

**Old tests to keep**:
- Existing per-ViewModel tests remain unchanged; they test ViewModel logic in
  isolation and are not made redundant by this change

### Rollout checklist

- [x] Add `MetricEntry` private type inside `ServiceContainer.swift`
- [x] Replace `startAll()` / `stopAll()` bodies with `entries.forEach` loops
- [x] Build and confirm no functional change
- [x] Add `MockMonitor.streamCallCount` / `stopCallCount` counters to
  `Sources/Shared/Mocks/MockMonitors.swift`
- [x] Write `ServiceContainerTests` under `Tests/…/ViewModels/`
- [x] Run `swift test`

---

## Issue 3 — `MetricThresholds.swift` has 11 structs wrapping 2 numbers each

**Final status**: Implemented, with the existing per-ViewModel threshold assertions retained alongside the new shared suite.

### Problem

`MetricThresholds.swift` contains 12 public `ThresholdEvaluating` structs.
Eleven of them delegate to a private `linearThresholdLevel(_:normalUpperBound:warningUpperBound:)`
helper with only the two boundary constants varying:

```swift
// CPUThreshold, GPUThreshold, MediaEngineThreshold, PowerThreshold,
// AcceleratorThreshold all produce this identical method body:
public func level(for value: Double) -> ThresholdLevel {
    linearThresholdLevel(value, normalUpperBound: 0.6, warningUpperBound: 0.85)
}
```

The result: a 140-line file that carries almost no semantic weight. Changing a
threshold boundary requires knowing which of the 12 structs to edit—nothing in
the code signals which ones share the same values. Code review of threshold
changes is tedious because reviewers must compare 12 nearly-identical bodies.

`LinearThreshold` and `InverseThreshold` already exist as generic building
blocks—they are simply not used from the per-metric wrappers.

**Files involved**:
`Sources/Shared/Thresholds/MetricThresholds.swift`,
`Sources/Shared/Protocols/ThresholdEvaluating.swift`

**Dependency category**: In-process

### Proposed resolution

Replace the 12 single-method structs with a static factory namespace and
named `let` constants. Each metric gets one line; the shared boundaries are
visible as shared constants.

```swift
// MetricThresholds.swift — after
public enum MetricThresholds {
    private static let standard = LinearThreshold(normalUpperBound: 0.6, warningUpperBound: 0.85)
    private static let relaxed  = LinearThreshold(normalUpperBound: 0.7, warningUpperBound: 0.90)

    public static let cpu:         any ThresholdEvaluating = standard
    public static let gpu:         any ThresholdEvaluating = standard
    public static let accelerator: any ThresholdEvaluating = standard
    public static let power:       any ThresholdEvaluating = standard
    public static let mediaEngine: any ThresholdEvaluating = standard
    public static let memory:      any ThresholdEvaluating = relaxed
    public static let fan:         any ThresholdEvaluating = relaxed
    public static let thermal:     any ThresholdEvaluating = LinearThreshold(
                                       normalUpperBound: 0.70, warningUpperBound: 0.85)
    public static let disk:        any ThresholdEvaluating = LinearThreshold(
                                       normalUpperBound: 0.75, warningUpperBound: 0.90)
    public static let battery:     any ThresholdEvaluating = InverseThreshold(
                                       normalLowerBound: 0.20, warningLowerBound: 0.10)
    public static let network:     any ThresholdEvaluating = NetworkThreshold()
    // WirelessThreshold is directional (RSSI) — keep bespoke
    public static let wireless:    any ThresholdEvaluating = WirelessThreshold()
}
```

Call sites change from `CPUThreshold().level(for: usage)` to
`MetricThresholds.cpu.level(for: usage)`. The 12 empty structs and the
private helper function are deleted.

### Testing strategy

**New tests to add**:
- Replace per-struct threshold tests in `CPUViewModelTests`, etc. with a single
  parameterised `MetricThresholdsTests` suite that iterates all 12 entries and
  verifies the three boundary zones

**Old tests to delete**:
- Inline threshold assertions scattered across individual ViewModel test files
  (e.g., `cpuThreshold_normal_belowSixty` in `CPUViewModelTests.swift`) become
  redundant once `MetricThresholdsTests` covers the same boundaries

### Rollout checklist

- [x] Add `MetricThresholds` enum to `Sources/Shared/Thresholds/MetricThresholds.swift`
- [x] Delete the 12 per-metric structs and the private `linearThresholdLevel` helper
- [x] Update all ViewModel call sites to use `MetricThresholds.<metric>.level(for:)`
- [x] Run SwiftLint (`swiftlint lint --strict`) to catch any leftover type names
- [ ] Delete redundant inline threshold tests in ViewModel test files
- [x] Write `MetricThresholdsTests` with parameterised boundary checks
- [x] Run `swift test`

---

## Issue 4 — `WirelessViewModel` reimplements `MonitorViewModelBase` by hand

**Final status**: Implemented.

### Problem

All 11 other ViewModels extend `MonitorViewModelBase<Snapshot>` and inherit:

- Stream subscription lifecycle (`start`, `stop`, `monitorTask`)
- Ring-buffer history management (`appendHistory`, `history`, `extendedHistory`)
- Batcher integration (`DashboardUpdateBatcher.shared.enqueue`)

`WirelessViewModel` reproduces all of this by hand, plus duplicates the
ring-buffer calls for its WiFi path. Additionally:

- It introduces `UpdateLane.wifi` and `UpdateLane.bluetooth` into the shared
  `DashboardUpdateBatcher`, coupling the batcher's design to a single ViewModel's
  needs
- The `history` and `extendedHistory` arrays are managed with raw
  `ringBufferAppending` calls duplicated from the base class

This breaks the structural promise of the codebase ("all ViewModels follow one
pattern") and makes `WirelessViewModel` a credible source of bugs: it's the only
ViewModel where a service update could be silently swallowed by a racing
`Task.cancel` on the wrong task handle.

**Files involved**:
`Sources/ViewModels/WirelessViewModel.swift`,
`Sources/Shared/MonitorViewModelBase.swift`,
`Sources/Shared/DashboardUpdateBatcher.swift`

**Dependency category**: In-process

### Proposed resolution

Extend `MonitorViewModelBase` to support a merged snapshot from two independent
monitors. The general form is a `ZipMonitor` that merges two `AsyncStream`s into
a unified snapshot type.

```swift
// New utility in Sources/Shared/
@MonitorActor
public final class ZipMonitor<A: Sendable, B: Sendable, Merged: Sendable>
    : MetricMonitorProtocol {

    private let left:  any MetricMonitorProtocol<A>
    private let right: any MetricMonitorProtocol<B>
    private let merge: @Sendable (A, B) -> Merged
    // … AsyncStream that reissues the merged value whenever either side updates
}
```

`WirelessViewModel` then conforms to `MonitorViewModelBase` like every other VM:

```swift
typealias WirelessMonitorInput = (wifi: WiFiSnapshot, bt: BluetoothSnapshot)

public final class WirelessViewModel: MonitorViewModelBase<WirelessMonitorInput> {
    override public func receive(_ snapshot: WirelessMonitorInput) { … }
}

// ServiceContainer
WirelessViewModel(monitor: ZipMonitor(
    left: WiFiMonitorService(), right: BluetoothMonitorService()
) { (wifi: $0, bt: $1) })
```

Ring-buffer management, stream subscription, and batcher integration all collapse
back into the base class. `UpdateLane` is removed (see Issue 1).

If `ZipMonitor` is judged too large for a single cycle, an acceptable interim
is to have `WirelessViewModel` extend `MonitorViewModelBase<WiFiSnapshot>` and
subscribe to `BluetoothMonitorService` separately only for the BT side-channel—
the WiFi history drive is the dominant path.

### Testing strategy

**New tests to add**:
- `ZipMonitorTests` — verify that both stream sides contribute to merged output;
  verify that slow side doesn't block fast side
- `WirelessViewModelTests` can then use the same `MockMonitor`-backed
  `ZipMonitor` test double and the same `waitForAsyncUpdates()` pattern as every
  other ViewModel test

**Old tests to simplify**:
- `WirelessViewModelLifecycleTests.swift` — remove bespoke task-cancel tests
  that duplicate what `MonitorViewModelBase` already guarantees

### Rollout checklist

- [ ] Create `Sources/Shared/ZipMonitor.swift`
- [ ] Add `MockZipMonitor` or two-mock construction helper to
  `Sources/Shared/Mocks/MockMonitors.swift`
- [x] Refactor `WirelessViewModel` to extend `MonitorViewModelBase<(WiFiSnapshot, BluetoothSnapshot)>`
- [x] Remove manual `history`, `extendedHistory`, `wifiTask`, `btTask` from `WirelessViewModel`
- [x] Remove `UpdateLane` (unblocked once Issue 1 lands)
- [x] Write `ZipMonitorTests`
- [x] Simplify `WirelessViewModelLifecycleTests`
- [x] Run `swift test`

---

## Issue 5 — `MetricMonitorProtocol` is too thin to describe the real service contract

**Final status**: Implemented.

### Problem

`MetricMonitorProtocol` declares only two methods:

```swift
func stream() -> AsyncStream<Value>
func stop()
```

The real contract—how polling works, what `poll(continuation:)` must do, the
sleep-and-cancel pattern, the `@MonitorActor` scheduling requirement—lives
entirely in `PollingMonitorBase`. The protocol is consulted only at injection
sites (ViewModel init and mock production), never at the point where the real
logic is authored.

The result is a misleading two-file split: a developer adding a new service must
understand `PollingMonitorBase` to know what to override, but the protocol gives
no guidance. The protocol exists only to enable mock injection—a use it shares
with the concrete base class's `init`-injectable constructor.

Additionally, `PollingMonitorBase.stream()` is `@MainActor` but the protocol
annotates the same method `@MainActor` — so the protocol already bakes in the
actor requirement. This means the split buys nothing over requiring conformance
directly to `PollingMonitorBase`.

**Files involved**:
`Sources/Shared/Protocols/MetricMonitorProtocol.swift`,
`Sources/Shared/PollingMonitorBase.swift`,
`Sources/Shared/Mocks/MockMonitors.swift`

**Dependency category**: In-process

### Proposed resolution

Make `PollingMonitorBase` the public-facing type for all real services, and keep
`MetricMonitorProtocol` as a narrow **injection protocol** used only in ViewModel
inits (its current only use). Add a doc comment making this split explicit:

```swift
/// Injection protocol.
/// Conform only to enable mock injection in tests or previews.
/// Production services extend `PollingMonitorBase` instead.
@MainActor
public protocol MetricMonitorProtocol<Value>: AnyObject {
    associatedtype Value: Sendable
    func stream() -> AsyncStream<Value>
    func stop()
}
```

Then add a doc comment to `PollingMonitorBase`:

```swift
/// Base class for all production monitor services.
///
/// Override `poll(continuation:)` to provide metric-specific sampling.
/// The async loop, sleep scheduling, and cancellation are handled here.
/// Conforms to `MetricMonitorProtocol`; inject as `any MetricMonitorProtocol`
/// in ViewModels.
open class PollingMonitorBase<Value: Sendable>: MetricMonitorProtocol { … }
```

The loop contract is now explicit in `PollingMonitorBase` itself. Production
services override `sample()` and optionally `setUp()`, `tearDown()`, or
`initialPollDeadline()` when they need resource lifecycle or a delayed first
emission. The async loop is no longer duplicated across all services.

### Implemented interface

```swift
open class PollingMonitorBase<Value: Sendable>: MetricMonitorProtocol {
    /// Override to synchronously produce one snapshot.
    /// Called every `Constants.pollingInterval` on `@MonitorActor`.
  @MonitorActor open func sample() async -> Value? {
        preconditionFailure("Override sample() in \(type(of: self))")
    }
  // The loop is final — drives sample() in the base class.
}
```

This makes the service API a single snapshot-producing entry point rather than an
async loop override, which is far easier to reason about and test. It mirrors the
existing helper pattern in `FanMonitorService.sample(_:)` and
`ThermalMonitorService.sample(_:)`, while still allowing async sampling for the
Bluetooth service.

### Testing strategy

**New tests added**:
- `PollingMonitorBaseTests` verifies the shared loop emits, stops cleanly, and
  calls `sample()` through the final base implementation

**Old tests to simplify**:
- `*MonitorServiceTests` stream lifecycle tests (`stream_canBeStartedAndStopped`,
  `service_conformsToProtocol`) can be reduced to one shared generic test helper

### Rollout checklist

- [x] Add clarifying doc comments to both `MetricMonitorProtocol.swift` and
  `PollingMonitorBase.swift`
- [x] Rename `poll(continuation:)` → `sample()` returning `Value?`;
  make the loop final in `PollingMonitorBase`, driving `sample()`
- [x] Update all 12 service `poll` overrides to `sample` overrides
- [x] Write a shared `PollingMonitorBaseTests` that verifies the loop emits,
  cancels cleanly, and calls `sample()` at least once
- [x] Run `swift test`

---

## Issue 6 — Snapshot structs have no shared contract

**Final status**: Implemented.

### Problem

Each of the 12 metric services defines its own ad-hoc snapshot struct. There is no
protocol or type constraint that governs what a snapshot must provide. As a result:

- `GPUSnapshot(usage: Double?)` uses an optional for hardware-unavailable paths;
  `MemorySnapshot` uses non-optional fields; `ThermalSnapshot` uses two separate
  optionals for CPU and GPU temperatures — no convention is enforced
- No `Snapshot` protocol means test helpers cannot be generic; each test creates
  hard-coded instances
- Adding a new metric requires inventing the struct from scratch without a
  checklist of conformances (`Sendable`, `Equatable`, etc.)
- There is no documentation contract for what `nil` values mean in display contexts

**Files involved**:
All 12 service files plus `Sources/Shared/MetricTileModel.swift`

**Dependency category**: In-process

### Proposed resolution

Introduce a `MetricSnapshot` protocol and enforce it at the protocol level:

```swift
public protocol MetricSnapshot: Sendable, Equatable {}
```

All 12 snapshot structs gain `: MetricSnapshot`. The constraint on
`MetricMonitorProtocol.Value` tightens from `Sendable` to `MetricSnapshot`:

```swift
public protocol MetricMonitorProtocol<Value>: AnyObject {
    associatedtype Value: MetricSnapshot
    …
}
```

This removes `MetricMonitorProtocol`'s only role outside injection (ensuring
`Sendable`), and adds `Equatable` — which `assignIfChanged` in ViewModels
already requires implicitly.

Additionally, adopt a **documentation convention** for optional fields:
- A `nil` field means "metric unavailable on this hardware" (e.g. GPU on
  Apple Silicon Intel-less path)
- A zero value means "hardware present but reading is zero"
- Codify this in a code comment on `MetricSnapshot`

### Testing strategy

**New tests to add**:
- A compile-time check test: `MetricSnapshotConformanceTests` that creates each
  snapshot and assigns it to `any MetricSnapshot` variable — ensures all 12
  conform

**Old tests unchanged**: No behaviour changes; this is additive protocol conformance

### Rollout checklist

- [x] Add `MetricSnapshot` protocol to
  `Sources/Shared/Protocols/MetricMonitorProtocol.swift` (or a new `MetricSnapshot.swift`)
- [x] Add `: MetricSnapshot` to all 12 snapshot structs
- [x] Tighten `Value: MetricSnapshot` in `MetricMonitorProtocol`
- [x] Add `Equatable` conformance where missing (verify with `swift build`)
- [x] Update `MockMonitor<T>` constraint from `Sendable` to `MetricSnapshot`
- [x] Write `MetricSnapshotConformanceTests`
- [x] Run `swift test`

---

## Issue 7 — `SMCBridge` is opened and closed per poll; no injection point

**Final status**: Implemented.

### Problem

Both `FanMonitorService` and `ThermalMonitorService` follow this pattern:

```swift
override public func poll(continuation: …) async {
    let smc = SMCBridge()       // opens IOKit connection
    defer { smc?.close() }      // closes it immediately after first yield
    var nextPoll = …
    while !Task.isCancelled {
        continuation.yield(…sample(smc)…)
        …sleep…
    }
}
```

The `SMCBridge` is opened once and kept alive for the lifetime of the polling
loop (the `defer` only triggers on function exit, not per iteration)—but this
is non-obvious. Reviewers must trace the async control flow to see that `smc` is
reused across loop iterations, not re-opened.

More critically, `SMCBridge` has no protocol and is constructed directly by
both services. There is no way to inject a fake bridge in tests:

- `FanMonitorService.sample(nil)` is tested (the nil path), but the non-nil
  path (real hardware reads) cannot be unit-tested
- Any future SMC-based metric would copy this pattern without guidance

**Files involved**:
`Sources/Shared/SMCBridge.swift`,
`Sources/Services/Fan/FanMonitorService.swift`,
`Sources/Services/Thermal/ThermalMonitorService.swift`

**Dependency category**: True external (hardware IOKit driver — mock at boundary)

### Proposed resolution

Extract an `SMCReading` protocol that exposes only the reading surface; make
`SMCBridge` conform to it; provide a `MockSMCReader` in the test target.

```swift
// New protocol in Sources/Shared/
public protocol SMCReading: AnyObject, Sendable {
    func readBytes(key: String) -> (dataType: UInt32, bytes: [UInt8])?
}

// SMCBridge conforms
extension SMCBridge: SMCReading {}
```

Then both `FanMonitorService` and `ThermalMonitorService` accept an injected
reader in their `sample(_:)` static methods — which they already do (`sample` is
`nonisolated static func sample(_ bridge: SMCBridge?) -> …`). The change is
to widen the parameter type:

```swift
// FanMonitorService — before
nonisolated static func sample(_ bridge: SMCBridge?) -> [FanReading]

// After
nonisolated static func sample(_ reader: (any SMCReading)?) -> [FanReading]
```

In tests, inject a `MockSMCReader` that returns canned byte sequences. This makes
the full fan/thermal sampling paths testable without hardware.

### Testing strategy

**New tests to add**:
- `FanMonitorServiceTests` — inject a `MockSMCReader` returning a known FNum + RPM
  pair; assert correct `FanReading(current:max:)` construction
- `ThermalMonitorServiceTests` — inject a reader returning `Tp2b` key bytes;
  assert correct `ThermalSnapshot.cpuCelsius` value

**Old tests to keep**:
- `sample_returnsEmpty_whenBridgeIsNil` remains valid

**`MockSMCReader` location**: `Tests/PerformanceDashboardTests/Services/`
(used only in tests, not production)

### Rollout checklist

- [x] Add `SMCReading` protocol to `Sources/Shared/SMCBridge.swift`
- [x] Conform `SMCBridge` to `SMCReading`
- [x] Widen `sample(_:)` parameter in `FanMonitorService` and `ThermalMonitorService`
- [x] Create `MockSMCReader` in the test target with a `[String: (UInt32, [UInt8])]`
  dictionary backing
- [x] Write hardware-path tests for `FanMonitorService.sample` and
  `ThermalMonitorService.sample` using `MockSMCReader`
- [x] Run `swift test` and confirm no regressions

---

## Issue 8 — `MetricTileModel` is a redundant parallel state tree

**Final status**: Implemented.

### Problem

Every ViewModel maintains two parallel state representations:

1. Its own `@Observable` properties (`usage`, `usageLabel`, `thresholdLevel`, …)
2. A `MetricTileModel` rebuilt from those same properties after every update

```swift
// CPUViewModel.receive(_:)
override public func receive(_ snapshot: CPUSnapshot) {
    lastSnapshot = snapshot
    appendHistory(snapshot.usage)
    assignIfChanged(&tileModel, to: Self.makeTileModel(usage: usage, …, history: history))
}
```

`MetricTileView` only reads `tileModel`, never the raw ViewModel properties.
The result is that every field added to a metric tile must be written twice—
once into the ViewModel's observable state and once into the tile model
construction—and every ViewModel test should assert both.

`assignIfChanged` exists precisely because SwiftUI's diffing on `@Observable`
already provides this; the outer equality check is defensive duplication. The
`displayTitle`, `accessibilityLabel`, `gaugeAccessibilityLabel`, and
`sparklineAccessibilityLabel` fields derived inside `MetricTileModel.init` are
also computable from the title at the view layer.

**Files involved**:
`Sources/Shared/MetricTileModel.swift`,
`Sources/Shared/StateUpdate.swift`,
all 12 ViewModel files,
`Sources/Views/Components/MetricTileView.swift`

**Dependency category**: In-process

### Proposed resolution

**Option A (recommended)**: Keep `MetricTileModel` as the view contract but
eliminate the per-ViewModel `tileModel` property by computing it lazily from the
ViewModel's `@Observable` state. This makes it a computed property rather than
a stored one:

```swift
// MonitorViewModelBase gains a default tileModel builder
public var tileModel: MetricTileModel { makeTileModel() }

// Subclasses override makeTileModel() → MetricTileModel
// No stored tileModel; SwiftUI recomputes on access when Observable state changes
```

This deletes all `assignIfChanged(&tileModel, …)` calls and the `makeTileModel`
static factories, replacing them with a single `override func makeTileModel()`.
`assignIfChanged` itself can be kept for other potential uses but no longer drives
the tile model.

**Option B**: Flatten the tile model into the ViewModel entirely, leaving
`MetricTileView` to read individual ViewModel properties. This reduces
indirection further but couples the view directly to ViewModel types.

Option A is preferred because it preserves the tile model as a value-type
snapshot that the view can hold (useful for animations and diffing), while
eliminating the manual synchronisation step.

### Testing strategy

**New tests to add**:
- Verify `tileModel` reflects ViewModel state without requiring an explicit
  `assignIfChanged` call — i.e., assert `tileModel.value` immediately after
  `receive()` without `await waitForAsyncUpdates()`

**Old tests to delete**:
- Any ViewModel test asserting `tileModel.value == …` directly can be merged
  into the corresponding raw-value test (since `tileModel` is now computed from
  the same source)

**Files simplified**: `Sources/Shared/StateUpdate.swift` may be deleted if
`assignIfChanged` has no other usages after this change.

### Rollout checklist

- [x] Add abstract `makeTileModel() -> MetricTileModel` to `MonitorViewModelBase`
- [x] Change `tileModel` in the base to a computed property calling `makeTileModel()`
- [x] Rename all `static func makeTileModel(…)` in subclasses to
  `override func makeTileModel() -> MetricTileModel`
- [x] Remove all `assignIfChanged(&tileModel, to: …)` calls and the stored
  `var tileModel` from each ViewModel
- [x] Handle `WirelessViewModel` (currently doesn't extend the base) after Issue 4 lands
- [x] Verify `StateUpdate.swift` has no remaining usages; delete if empty
- [x] Run SwiftLint and `swift test`

---

## Summary table

| # | Title | Category | Blast radius | Test impact |
|---|-------|----------|--------------|-------------|
| 1 | `DashboardUpdateBatcher` singleton | In-process | All 12 VMs | Enables synchronous ViewModel tests |
| 2 | `ServiceContainer` manual wiring | In-process | All 12 pairs | Enables container-level integration test |
| 3 | `MetricThresholds` 11 empty structs | In-process | 12 VMs | Reduces 12 per-VM threshold tests to 1 suite |
| 4 | `WirelessViewModel` out-of-hierarchy | In-process | 1 VM + batcher | Normalises test harness for Wireless |
| 5 | `MetricMonitorProtocol` shallow | In-process | All services | Per-service `sample()` tests become trivial |
| 6 | Snapshot struct heterogeneity | In-process | All 12 services | Generic test helpers become possible |
| 7 | `SMCBridge` no injection | True external | Fan, Thermal | Hardware-path tests unlocked |
| 8 | `MetricTileModel` parallel state | In-process | All 12 VMs | Halves ViewModel test assertion count |

## Recommended implementation order

1. **Issue 3** (thresholds) — entirely self-contained, highest LOC-reduction per effort
2. **Issue 6** (snapshot protocol) — additive, no logic change, unlocks generic helpers
3. **Issue 7** (SMCBridge injection) — closes the last hardware-untestable seam
4. **Issue 1** (batcher injection) — prerequisite for Issues 4 and 8
5. **Issue 4** (WirelessViewModel normalisation) — requires Issue 1 (lane removal)
6. **Issue 8** (tile model computed property) — requires Issue 4 (WirelessViewModel in hierarchy)
7. **Issue 5** (PollingMonitorBase `sample()`) — optional rename; de-risks last
8. **Issue 2** (ServiceContainer registration) — lowest risk, do last to avoid merge conflicts
