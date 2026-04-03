# PerformanceDashboard

A macOS performance dashboard. Displays real-time gauges and sparklines for resources.

The app lives in the menu bar and opens a compact dashboard window on click.

---

## Requirements

- macOS 26 (Tahoe) or later
- Swift 6
- [SwiftLint](https://github.com/realm/SwiftLint) (for linting)

> Apple Silicon is required for Accelerator (ANE) and Media Engine tiles.

---

## Build & Run

```bash
# Build
swift build

# Run
swift run

# Test
swift test

# Test with coverage
swift test --enable-code-coverage
xcrun llvm-cov report \
  .build/debug/PerformanceDashboardPackageTests.xctest/Contents/MacOS/PerformanceDashboardPackageTests \
  -instr-profile .build/debug/codecov/default.profdata

# Lint
swiftlint lint --strict
```

> **Note**: The app sandbox must be disabled for IOKit GPU/ANE access. This is already configured in `PerformanceDashboard.entitlements`.

---

## Metrics

| Tile | System API |
|------|-----------|
| CPU | `host_processor_info` — tick delta → % |
| GPU | IOKit `PerformanceStatistics` dict |
| Memory | `host_statistics64` → `vm_statistics64` |
| Network In/Out | `getifaddrs` — bytes/s delta (loopback excluded) |
| Disk | `URLResourceValues.volumeAvailableCapacityKey` |
| Power | SMC keys `PSTR` / `PDTR` (watts) |
| Fan | SMC keys `F0Ac`, `F1Ac`, `F0Mx` (RPM) |
| Thermal | SMC CPU/GPU die temperatures (°C) |
| Battery | `IOPMPowerSource` — %, health, cycle count, time-to-empty |
| ANE/Accelerator | IOKit `AppleH11ANEInterface` / `ANE0` (arm64 only) |
| Media Engine | IOKit `AppleAVD` / `AppleVXD` — H.264/HEVC encode/decode (arm64 only) |
| Wireless | `CoreWLAN` (Wi-Fi RSSI/channel) + `IOBluetooth` (BT device count) |

Each tile shows: current value, a 60-second sparkline, and threshold colour coding (green → orange → red).

---

## Architecture

**Pattern**: MVVM + Service layer — pure Swift Concurrency, no Combine.

```
Sources/
├── App/                    # @main entry point, wires all ViewModels and scenes
├── Services/               # One service per metric; all system API calls here
├── ViewModels/             # @Observable, @MainActor; consume AsyncStream from services
├── Views/
│   ├── Dashboard/          # Root single-view layout (LazyVGrid)
│   ├── Components/         # MetricTileView, RingGaugeView, SparklineView
│   └── MenuBar/            # Compact MenuBarExtra view
└── Shared/
    ├── Protocols/          # MetricMonitorProtocol, ThresholdEvaluating
    ├── Mocks/              # Mock services for tests and SwiftUI previews
    ├── MonitorActor.swift  # @globalActor — all background polling runs here
    ├── SMCBridge.swift     # SMC key reading for Power/Fan/Thermal
    └── Constants.swift     # Polling interval (1 s), history length (60 samples)
```

**Key design decisions**:
- Every service conforms to `MetricMonitorProtocol<Value>`, exposing `stream() -> AsyncStream<Value>` and `stop()`.
- ViewModels accept `some MetricMonitorProtocol` via `init` — services are never instantiated internally (dependency inversion).
- All IOKit/SMC/`host_processor_info` calls run on `MonitorActor` (background); published values arrive on `@MainActor`.
- Mock services are drop-in replacements used in all ViewModel tests and `#Preview` blocks.
- Zero external Swift Package dependencies — only system frameworks (IOKit, CoreWLAN, IOBluetooth).

---

## Testing

Tests use **Swift Testing** (`import Testing`), mirroring the source tree under `Tests/PerformanceDashboardTests/`.

- ViewModel tests use mock services — no real system APIs are called.
- Coverage target: ≥ 80% across Services and ViewModels (UI files excluded).
- If VS Code reports **0/0 tests**, run `swift test` in the terminal — it always means a compilation error.
