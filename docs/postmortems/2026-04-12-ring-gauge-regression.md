# Ring Gauge Regression Postmortem

## Issue

The dashboard ring gauges could display stale load values after the ring animation driver optimization, causing tiles such as CPU to show a numeric value and sparkline that no longer matched the gauge.

## Evidence

- User-visible symptom: the CPU tile showed roughly 39% usage while the ring gauge remained near empty in a live dashboard screenshot.
- The affected animation boundary is split between `Sources/Views/Components/RingGaugeAnimationDriver.swift` and `Sources/Views/Components/AtlasRingGaugeHostingView.swift`.
- `AtlasRingGaugeHostingView.ringGaugeAnimationDidTick(at:)` can call `stopAnimation()`, which removes the hosting view from the shared driver during a tick callback.
- The fix restored mutation-safe listener delivery in `Sources/Views/Components/RingGaugeAnimationDriver.swift` by taking a listener snapshot before iterating callbacks.
- Current tests in `Tests/PerformanceDashboardTests/Shared/SharedTests.swift` cover timing constants and polling cadence, but there is no regression test for the ring animation driver or hosted gauge update boundary.

## Failure path

1. The CPU-reduction pass changed `RingGaugeAnimationDriver` from the earlier closure timer path to a selector-based timer and later tightened the tick loop implementation.
2. `RingGaugeAnimationDriver.tick()` delivers callbacks to `RingGaugeAnimationTicking` listeners, while `AtlasRingGaugeHostingView.ringGaugeAnimationDidTick(at:)` can end an animation and call `stopAnimation()`.
3. `stopAnimation()` removes the current listener from the shared `NSHashTable` during the same tick cycle.
4. When the driver iterated the live weak-listener collection instead of a stable snapshot, callback delivery became dependent on collection mutation during iteration.
5. Some gauges could miss later ticks or the final settling tick, leaving `displayedFrameIndex` stale even though the tile model and text had already advanced.
6. The system did not prevent or detect this earlier because no test exercises the real boundary where driver iteration, listener removal, and hosted gauge state updates interact.

## Classification

`structurally enabled defect` — `Test seam mismatch`

## Structural assessment

This bug was introduced by a local implementation mistake in `RingGaugeAnimationDriver.tick()`, but the design made that mistake easy to miss.

The animation correctness boundary spans two concrete types:

- `RingGaugeAnimationDriver`, which owns listener enumeration and timer delivery
- `AtlasRingGaugeHostingView`, which mutates shared driver membership from inside the callback path

That boundary has no regression test and no explicit invariant owner. The behavior that must remain true is: listener removal during a tick must not affect delivery to the remaining listeners or prevent the final frame from being applied. Today that rule exists only implicitly in the implementation. The existing test suite focuses on view-model, polling, and service behavior, so it never exercised the mutation-sensitive UI animation boundary where this regression lived.

## Prevention

Add a narrow regression seam around the ring animation boundary rather than a broad rewrite:

1. Expose a testable tick-delivery seam in `RingGaugeAnimationDriver` so tests can trigger one tick without relying on `Timer` or `RunLoop` scheduling.
2. Add a regression test that registers multiple listeners and verifies that one listener removing itself during callback does not starve the others.
3. Add a hosted-gauge behavior test, or at minimum a focused unit test around the driver, to verify that an animation can reach its target frame after mid-tick removal.

## Validation

- Fix applied in `Sources/Views/Components/RingGaugeAnimationDriver.swift` by restoring snapshot-based listener iteration before callback delivery.
- Repository validation after the fix:
  - `swift test` passed with 407 tests in 42 suites.
  - `swiftlint lint --strict` passed with 0 violations.
- Manual dashboard validation remains necessary until the targeted ring animation regression test is added.

## Artifacts created

- `docs/postmortems/2026-04-12-ring-gauge-regression.md`
- `TODO.md` follow-up item for ring gauge regression coverage

## Next actions

- Add a test seam in `Sources/Views/Components/RingGaugeAnimationDriver.swift` for deterministic tick delivery.
- Add a regression test near `Tests/PerformanceDashboardTests/` covering listener removal during tick and final frame delivery.
- If the test needs a higher-level boundary, thread an injectable ticker or test hook through `Sources/Views/Components/AtlasRingGaugeHostingView.swift` rather than relying on live `Timer` scheduling.