---
name: improve-test-runtime
description: 'Profile the full test suite, identify slow tests and sleep hotspots, then optimize for faster execution. Use when test suite is slow, Task.sleep is overused, you want to eliminate timing waits, speed up CI, inject a Clock protocol, or find production code that can be made testable with a faster clock.'
argument-hint: 'Optional: target name or file path to focus on (e.g., PerformanceDashboardTests)'
---

# Improve Test Runtime

Profile the full test suite, surface the hottest files and individual tests, then eliminate the root causes of slowness — starting with `Task.sleep` and `Thread.sleep` calls, then shared setup inefficiencies, and finally production code that can be improved by injecting a `Clock` abstraction.

A fast test suite enables tighter feedback loops and confident refactoring. Every second shaved here is compounded on every CI run and every local iteration.

---

## When to Use

- Test suite wall-clock time is higher than expected  
- Individual tests are gated by `Task.sleep` or `Thread.sleep`  
- CI is slow and you want to identify the biggest wins  
- You want to replace polling/timer-based test waits with event-driven ones  
- A production type polls or waits on a real clock and tests can't mock it  

---

## Phase 1 — Generate the Runtime Profile

Run the test suite with timing output:

```bash
swift test 2>&1 | grep -E "Test run|seconds|PASSED|FAILED"
```

For a full per-test timing breakdown, use `--verbose`:
```bash
swift test --verbose 2>&1 | grep -E "seconds|sleep"
```

To scan for sleep hotspots without running tests:
```bash
grep -r "Task.sleep\|Thread.sleep" Tests/ Sources/ --include="*.swift" -n
```

Read the output and build a list of slow tests and sleep hotspots.

---

## Phase 2 — Read and Triage the Report

Open `test_profile.md`. Build a prioritized list of candidates across three categories:

### A. Slow individual tests
Look for tests with `time > 0.5s`. These are individually expensive.

### B. Sleep hotspot files
Sort by total sleep duration in the file. Files at the top are 
spending mandatory wall-clock time on sleeps that may be replaceable.

### C. Slow targets by wall-clock time
A target that takes >10× longer per test than the fastest target likely has expensive shared setup or sequential bottlenecks.

Publish a `manage_todo_list` with one item per candidate file, ordered by impact (highest sleep budget first). Mark each `not-started`.

## Phase 3 — Diagnose Each Hotspot

Spawn a **read-only Explore sub-agent** for each candidate file (or batch similar files together). Do NOT read the files yourself.

Ask the sub-agent to return for each file:

1. For each `Task.sleep` / `Thread.sleep`: What is it waiting for? Is there a callback, notification, or actor state change that could signal completion instead?
2. Is the test polling for a side-effect? If so, can the production code fire a callback or `AsyncStream` event instead of being polled?
3. Is the production type using a real `Clock` (e.g., `Task.sleep` in production code)? If so, is there an existing `ClockProtocol` or equivalent injection point? If not, flag it as a production improvement opportunity.
4. Is the test setup (`init()`, `setUp()`, `@Suite`) re-creating expensive state that could be shared?
5. Is the suite marked `.serialized` when tests are actually independent? (Unnecessary serialization blocks parallel execution.)

Classify each sleep on a fix difficulty scale:
- **Easy** — sleep after fire-and-forget async call that already has a handler or `AsyncStream`
- **Medium** — sleep before assertion; need to add a continuation or signal
- **Hard** — sleep because production code drives timing; requires `Clock` injection

---

## Phase 4 — Optimize

Work through candidates highest-impact first. Apply fixes in this order of preference:

### Fix A: Replace sleep with event-driven wait

Instead of:
```swift
try await Task.sleep(for: .milliseconds(100))
#expect(await sut.state == .ready)
```

Use a continuation that fires when the state changes:
```swift
await withCheckedContinuation { cont in
    sut.onStateChange = { state in
        if state == .ready { cont.resume() }
    }
}
#expect(await sut.state == .ready)
```

Or leverage an existing `AsyncStream`:
```swift
var iter = sut.stateStream.makeAsyncIterator()
let state = await iter.next()
#expect(state == .ready)
```

### Fix B: Replace Thread.sleep with Task.sleep

`Thread.sleep` blocks a thread entirely. Replace with:
```swift
try await Task.sleep(for: .milliseconds(20))
```

### Fix C: Inject a Clock to eliminate production waits

If production code does:
```swift
try await Task.sleep(for: .seconds(60)) // polling interval
```

Introduce a `ClockProtocol` (or use Swift's `any Clock` / `ContinuousClock`) and inject a fast-forwarding test clock:
```swift
protocol AppClock: Sendable {
    func sleep(for duration: Duration) async throws
}
struct ImmediateClock: AppClock {
    func sleep(for duration: Duration) async throws { /* no-op */ }
}
```

This is a double win: faster tests **and** more testable production code.

### Fix D: Share expensive setup

If every `@Test` in a suite recreates the same actor/service from scratch:
```swift
// Before: recreated per test
@Test func testA() async { let sut = await MyService(); ... }
@Test func testB() async { let sut = await MyService(); ... }
```

Hoist into a `@Suite` actor with shared state (use `.serialized` if state is mutated):
```swift
@Suite(.serialized) actor MyServiceTests {
    let sut: MyService
    init() async { sut = await MyService() }
    @Test func testA() async { ... }
    @Test func testB() async { ... }
}
```

Only use `.serialized` if tests share mutable state. Independent tests should not have it.

---

## Phase 5 — Validate

After applying optimizations, re-run the test suite to measure the delta:

```bash
swift test --verbose 2>&1 | grep -E "seconds|PASSED|FAILED"
```

Compare the new timing against the previous run. Then run the full suite to confirm nothing is broken:

```bash
swift test
```

If tests fail, diagnose before retrying.

Render a delta summary with a Mermaid chart:

```
xychart-beta
  title "Wall-Clock Time Before → After (seconds)"
  x-axis [PerformanceDashboardTests]
  y-axis "Seconds" 0 --> 30
  bar [before_total]
  bar [after_total]
```

Report:
- Total time before → after
- Seconds saved per target
- Number of `Task.sleep` / `Thread.sleep` calls eliminated
- Any production types that now accept a `Clock` injection

---

## Project-specific notes

- **Service tests** (`Tests/PerformanceDashboardTests/Services/`) — may contain sleeps waiting for `AsyncStream` values; replace with mock confirmation continuations.
- **ViewModel tests** (`Tests/PerformanceDashboardTests/ViewModels/`) — inject mock services that emit values immediately; no real system API calls should produce timing waits.
- **Shared tests** (`Tests/PerformanceDashboardTests/Shared/`) — protocol and extension tests; should be fast.
- Test target: `PerformanceDashboardTests` (single target).
- If a ViewModel or service polls with `Task.sleep(for: Constants.pollingInterval)`, inject a fast-forwarding clock via a `Clock` protocol to eliminate the wait.
- The xunit output flag (`--xunit-output`) only writes results if the target run exits cleanly with zero failures.
- Each target must pass independently before per-test timing data is available.

---

## Reference: Common Sleep Patterns and Their Replacements

See [./references/sleep-patterns.md](./references/sleep-patterns.md) for a pattern catalogue with before/after code for the most common cases found in this codebase.
