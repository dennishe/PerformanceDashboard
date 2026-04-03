# PerformanceDashboard – Project Guidelines

A macOS performance dashboard written in Swift/SwiftUI, inspired by Activity Monitor. Displays real-time gauges and graphs for CPU, GPU, Memory, Network, Disk, and (where accessible) Apple AMX/ANE accelerator load — all on a single view.

## Architecture

**Pattern**: MVVM + Service layer  
**Platform**: macOS 26.4+ (Tahoe), Swift 6, SwiftUI

```
PerformanceDashboard/
├── App/                        # AppEntry (no logic here)
├── Services/                   # Data sources (system APIs, no UI)
│   ├── CPU/
│   ├── GPU/
│   ├── Memory/
│   ├── Network/
│   ├── Disk/
│   └── Accelerator/            # AMX / ANE via IOKit
├── ViewModels/                 # @Observable per metric, owns a Service
├── Views/
│   ├── Dashboard/              # Root single-view layout
│   └── Components/             # Reusable gauges, sparklines, meters
└── Shared/
    ├── Protocols/              # MonitorProtocol, MetricProtocol, etc.
    └── Extensions/
```

## SOLID Principles — Concrete Application

### Single Responsibility
- Each `*MonitorService` reads **one** resource only (e.g., `CPUMonitorService` uses only `host_processor_info`).
- ViewModels transform raw values to display strings/colors; they never call system APIs directly.

### Open/Closed
- Add new metrics by conforming to `MetricMonitorProtocol`. Never modify existing monitors.

### Liskov Substitution
- All monitor services conform to `MetricMonitorProtocol`. Mock implementations must be drop-in replacements for previews and tests.

### Interface Segregation
- Keep protocols focused: `MetricMonitorProtocol` covers a single metric. Don't add unrelated capabilities to an existing protocol.
- Prefer `Readable` / `Pollable` split protocols if a type only needs one side.

### Dependency Inversion
- ViewModels accept a `some MetricMonitorProtocol` (or the protocol type) via `init` — never instantiate services internally.
- Use `@Observable` view models injected via `.environment` or direct `init` — not singletons.

## File sizes etc.
- Aim for at most ~200 lines per file. If a file exceeds this, consider splitting it.
- Code should be beautiful and elegant. Don't duplicate logic that can be shared, and avoid clunky solutions.

## System API Cheat Sheet

| Metric | API |
|--------|-----|
| CPU usage | `host_processor_info` / `mach_host_info` (kernel framework) |
| Memory | `host_statistics64` → `vm_statistics64` |
| Disk usage | `URLResourceValues` (`.volumeAvailableCapacityKey`) |
| Network throughput | `getifaddrs` (delta bytes/s per interface) |
| GPU utilisation | `IOServiceGetMatchingService` → `IOKit` (`PerformanceStatistics` dict) |
| AMX / ANE load | `IOKit` — match `"AppleH11ANEInterface"` or `"ANE0"`; read `"ane_power"` / utilisation keys. Only available on Apple Silicon; gate with `#if arch(arm64)`. |

> AMX/ANE IOKit keys are undocumented. Use `ioreg -l -n ANE0` to inspect available keys on the target machine. Gracefully degrade if the service or key is absent.

## Build & Run

This project is built and run from **VS Code** using Swift Package Manager. There is no `.xcodeproj`.

Required entitlements (in `Package.swift` or a separate `.entitlements` file linked via SPM):
- Disable sandbox for IOKit GPU/ANE access: `com.apple.security.app-sandbox` → `false`.

```bash
# Build
swift build

# Run
swift run

# Run tests (always use this — see Pitfalls below)
swift test

# Test coverage
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/PerformanceDashboardPackageTests.xctest/Contents/MacOS/PerformanceDashboardPackageTests \
  -instr-profile .build/debug/codecov/default.profdata

# Lint
swiftlint lint --strict
```

**Coverage target**: ≥ 80% across all non-UI source files.

## Testing

- Use the **Swift Testing** framework (`import Testing`) — not XCTest.
- Test files live in `Tests/PerformanceDashboardTests/`, mirroring the source tree.
- Name test functions descriptively: `@Test func cpuUsage_returnsDeltaBetweenSamples()`.
- Use mock services (conforming to `MetricMonitorProtocol`) for all ViewModel tests — never hit real system APIs in tests.
- **Target ≥ 80% code coverage** on Services and ViewModels; UI/View files are excluded.
- If the VS Code test runner reports **0/0 tests**, this is a compilation error in the test target. Run `swift test` in the terminal to see the real error — do not interpret 0/0 as passing.

## Linting

- **SwiftLint** is the linter. Config lives at `.swiftlint.yml` in the project root.
- Run `swiftlint lint --strict` before considering any task done. Fix all warnings and errors.
- Strict rules include: `force_unwrapping`, `force_cast`, `force_try`, `cyclomatic_complexity`, `file_length` (warn: 200, error: 300), `function_body_length`.
- Disable rules inline only as a last resort — prefer fixing the code. Document the reason with a comment.

## Conventions

- **Polling interval**: 1 second default; expose as a `Duration` constant in `Constants.swift`.
- **Threading**: All system API calls run on a background actor (`MonitorActor`). Published values are delivered on `@MainActor`.
- **No Combine**: Use Swift Concurrency (`async/await`, `AsyncStream`, `@Observable`) exclusively.
- **Previews**: Every view must have a `#Preview` using a mock service conforming to `MetricMonitorProtocol`.
- **Colors**: Use semantic colors (`Color.red`, `.orange`, `.green`) for thresholds; define thresholds in a `Threshold` enum per metric.
- **Units**: Always format bytes with `ByteCountFormatter`; percentages to one decimal place.
- **No force-unwrap**: Use `guard let` or `if let`; IOKit calls are inherently failable — handle all `nil` and error codes explicitly.
- **Accessibility**: Every gauge/graph must have an `.accessibilityLabel` and `.accessibilityValue`.

## Dashboard Layout Goal

All metrics visible without scrolling on a standard 13" display. Use `Grid` or `LazyVGrid` with adaptive columns. Each metric tile contains:
1. Title + current value (large)
2. Spark-line or ring gauge (past ~60 s)
3. Threshold color coding

## Key Files (once scaffolded)

| File | Purpose |
|------|---------|
| `Shared/Protocols/MetricMonitorProtocol.swift` | The root protocol every service conforms to |
| `Services/CPU/CPUMonitorService.swift` | Reference implementation |
| `Views/Dashboard/DashboardView.swift` | Root layout, entry point for UI |
| `Views/Components/MetricTileView.swift` | Reusable tile — shows any metric |

## Common Pitfalls

- `host_processor_info` returns ticks, not percentages — must compute delta between two samples.
- `getifaddrs` includes loopback (`lo0`); filter it out and sum only `en*`/`utun*` interfaces.
- IOKit `CFDictionary` values arrive as `CFTypeRef`; cast to `CFNumber` before reading.
- SwiftUI `Canvas` is preferred over `Path` in a loop for sparklines (better performance).
- Building with the macOS sandbox **will** block IOKit GPU/ANE access — disable in debug or sign with correct entitlements.
- **0/0 tests in VS Code** means a compilation error in the test target — always run `swift test` in the terminal to get the real diagnostic output.
