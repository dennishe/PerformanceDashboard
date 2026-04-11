# Dashboard CPU Reduction RFC — PerformanceDashboard

**Date**: 2026-04-11  
**Status**: Proposed  
**Scope**: Dashboard sampling, view-model update flow, dashboard observation boundaries, sparkline rendering, and battery/peripheral detail ownership

---

## Summary

Time Profiler shows two dominant sources of CPU load during a 20-second dashboard run:

1. Expensive sampling work that does not match what the dashboard tile actually renders
2. Broad SwiftUI and AppKit invalidation around the dashboard grid and sparkline update path

The largest concrete offender in the current implementation is Bluetooth peripheral battery sampling. The dashboard polls full IOHID registry property dictionaries every second, even though the visible tile only needs Bluetooth power state and connected-device count. At the same time, the Battery tile detail does not show the connected Bluetooth device battery state a user would reasonably expect from a Battery detail surface.

This RFC proposes one unifying design change rather than a list of isolated optimizations:

- Keep the dashboard tile path fast, fixed-cost, and aligned to what is visible at a glance
- Move expensive, rich, secondary data to slower or on-demand detail providers
- Narrow the SwiftUI observation surface so one metric update does not force the whole dashboard graph to do unnecessary work
- Reduce history and sparkline churn so each visual update is incremental rather than full-buffer based

The result should reduce CPU load without lowering rendering quality, update cadence, or information density in the main dashboard.

---

## Profiling Context

The pruned call stack supplied for a 20-second run shows two clear clusters.

### Cluster 1 — Expensive monitor work

The hottest non-framework application path is:

- `PollingMonitorBase.runPollingLoop`
- `BluetoothMonitorService.sample()`
- `BluetoothMonitorService.samplePeripheralBatteries()`
- `IORegistryEntryCreateCFProperties`
- `IOCFUnserializeBinary`

This indicates the app is paying a high recurring cost to deserialize full IOKit property dictionaries on every poll.

### Cluster 2 — Broad UI invalidation

The dominant UI frames are:

- `DashboardView.body`
- `DashboardView.tileGrid`
- `MonitorViewModelBase.tileModel.getter`
- `SparklineRepresentable.updateNSView`
- `SparklineHostingView.updateLayersIfNeeded`
- `NSHostingView.layout`
- `CA::Transaction::commit`

This suggests that metric updates are propagating widely through the dashboard view graph, and that even when rendering stays visually correct, the update surface is larger than it needs to be.

---

## Problem Statement

The current architecture couples data richness, polling cadence, and UI ownership too tightly.

### Problem 1 — The sampling cost does not match the visible surface

Tiles render summary information, but some monitors compute detail-grade data every second anyway.

The clearest example is Bluetooth:

- The visible Wireless tile only needs Wi-Fi signal, Bluetooth on/off state, and connected count
- The monitor also scans all Bluetooth HID devices and deserializes full property dictionaries for battery percentages every poll
- Those peripheral battery values are not shown in the Battery detail at all

The system is therefore paying detail-level CPU cost for information that is both expensive and surfaced in the wrong place.

### Problem 2 — Metric updates are broader than the tile that changed

The dashboard composes tile models inline from the parent dashboard view. In the generic monitor path, `tileModel` is a computed getter rather than stored observable state. That means a metric update can force the dashboard view graph to revisit work across the grid, even if only one tile changed.

### Problem 3 — Polling is distributed across many independent tasks

Each monitor owns its own polling loop, wakeup, and main-actor handoff. Even though all monitors nominally sample at the same one-second cadence, the work is not coordinated into one dashboard tick.

### Problem 4 — History storage and sparkline invalidation are full-buffer based

History arrays are maintained by append-plus-remove-first copying. Sparkline invalidation hashes the entire history buffer and rebuilds full vector paths when a new point arrives. This is acceptable for a small number of tiles, but it is still needless per-sample churn.

### Problem 5 — Battery ownership is misaligned with user expectation

The current Battery detail models only the Mac's internal battery and power-source state. Bluetooth peripheral battery state is owned by Wireless detail instead. That creates a product mismatch:

- The user expectation for the Battery detail is "show me battery-related state"
- The implementation only shows host battery state
- Connected device battery state exists, but is surfaced elsewhere and gathered too aggressively

This is both a UX problem and a performance problem.

---

## Goals

- Reduce dashboard CPU load without lowering rendering quality or main tile cadence
- Keep tile rendering visually identical or better
- Preserve the current single-view dashboard layout and information density
- Move expensive secondary data off the hot path when it is not visible
- Make Battery detail show Bluetooth peripheral battery state in a way that matches user expectation
- Make performance improvements measurable with Time Profiler and repeatable profiling workflows

## Non-Goals

- Lowering the global polling interval below one second
- Removing sparklines, ring gauges, or detail charts
- Reducing the number of visible tiles by default
- Replacing SwiftUI with AppKit for the full dashboard
- Redesigning the product taxonomy beyond what is necessary to fix battery/peripheral ownership

---

## Proposed Architecture

The core proposal is to separate each metric into two possible surfaces:

1. A fast tile surface
2. A rich detail surface

The tile surface is sampled and updated at the dashboard cadence. The detail surface is sampled on demand or at a slower cadence only while visible.

### Proposed Data Flow

```text
Monitor services -> Dashboard sampler tick -> Stored tile models -> Tile views
                                     \
                                      -> On-demand detail providers -> Detail overlay
```

This is the design principle behind every recommendation below.

---

## Proposal A — Split Fast Tile Sampling From Rich Detail Sampling

### Current issue

Monitors often return a single snapshot type that tries to serve every UI surface at once. That encourages the service to gather more information than the tile needs.

### Proposed change

Introduce an explicit distinction between:

- `TileSnapshot`: the minimum data required for tile rendering
- `DetailPayload` or `DetailProvider`: secondary information required only by detail overlays

The exact protocol shape can vary, but the important rule is:

- no detail-only data is sampled on the hot tile path

### Concrete example

For Bluetooth and Battery:

- The Wireless tile path should sample only Bluetooth on/off and connected count
- Bluetooth peripheral battery percentages should be fetched only when a detail surface needs them
- Battery detail should compose internal battery state with connected-device battery state

### API sketch

```swift
protocol MetricTileMonitorProtocol<Snapshot>: Sendable {
    associatedtype Snapshot: MetricSnapshot
    func sampleTile() async -> Snapshot?
}

protocol MetricDetailProviding<Payload>: Sendable {
    associatedtype Payload: Sendable
    func detailPayload() async -> Payload
}
```

This does not require every metric to implement a separate detail provider. It only applies where the detail path is materially more expensive than the tile path.

### Expected impact

- Removes detail-only sampling work from the steady-state dashboard loop
- Makes CPU cost proportional to what is actually visible
- Clarifies ownership of expensive data surfaces

---

## Proposal B — Move Bluetooth Peripheral Batteries Out Of The Wireless Hot Path

### Current issue

The Bluetooth service walks `IOHIDDevice` services and deserializes full property dictionaries every poll. That is the single most obvious application-controlled hotspot in the supplied profile.

### Proposed change

Refactor Bluetooth into two responsibilities:

1. `BluetoothStateMonitorService`
   Returns only:
   - Bluetooth powered state
   - Connected device count

2. `BluetoothPeripheralBatteryProvider`
   Returns only:
   - Peripheral name
   - Battery percentage

The provider is invoked only when needed by a detail surface.

### Additional improvement

When feasible, the provider should avoid `IORegistryEntryCreateCFProperties` for the whole dictionary and instead:

- cache matching HID services
- read only the required keys
- refresh via notifications or a lower-frequency refresh path

### Ownership decision

Bluetooth peripheral battery state should no longer be considered part of the Wireless detail contract. It belongs in Battery detail.

Wireless detail may still show:

- Bluetooth on/off
- Connected count
- Wi-Fi SSID
- Wi-Fi RSSI

Battery detail should show:

- Internal battery charge, status, cycle count, health
- Connected device battery state for Bluetooth peripherals

### Why this is the right ownership split

- It matches user expectation: battery-related information lives under Battery
- It removes the strongest hotspot from the steady-state Wireless tile path
- It lets the Battery detail do richer work only when the user asks for it

### Expected impact

- Significant CPU reduction from removing per-second full IORegistry property walks
- Cleaner mental model for the dashboard
- Fixes the current Battery detail mismatch

---

## Proposal C — Add A Single Dashboard Sampling Tick

### Current issue

Every monitor maintains its own polling loop and produces independent main-thread update traffic.

### Proposed change

Introduce a `DashboardSampler` actor that owns the global one-second cadence. On each tick, it triggers the tile-surface sampling work and returns one composite update batch to the main actor.

Possible shapes:

- a single actor that directly samples all tile monitors
- a scheduler that coordinates existing monitors but batches delivery into one main-actor commit

The important property is that the dashboard does one coordinated update pass per tick, not many small loosely synchronized ones.

### Benefits

- Fewer task wakeups
- Fewer `AsyncStream` handoffs
- Fewer separate observation transactions
- Better alignment between "new data available" and "one dashboard frame update"

### Rollout note

This can be implemented incrementally. The first version can keep existing monitor services and only centralize delivery; a later version can flatten more of the polling machinery.

---

## Proposal D — Narrow The Observation Surface To Per-Tile Stored Models

### Current issue

The dashboard body reads tile models inline from the parent container. In the generic path, `tileModel` is computed on demand. This makes it easier for one metric update to pull more of the dashboard graph into recomputation than necessary.

### Proposed change

Each metric view model should own a stored `tileModel` property that is updated when fresh data arrives. The dashboard grid should pass those immutable models down to leaf tile views without recomputing them from the parent.

For example:

- View models update `tileModel` in `receive(_:)`
- `DashboardView` observes only visibility and selection state plus the already-built tile models
- Network and other multi-lane tiles follow the same rule for their specialized stored models

### Additional refinement

Where practical, split tile rendering into leaf views that depend on a single view model or stored model, rather than having the whole grid read from a large observable container.

### Expected impact

- Smaller SwiftUI invalidation blast radius
- Less repeated tile-model assembly work
- Less dashboard-wide layout churn per sample

---

## Proposal E — Replace Array-Based History Churn With Real Ring Buffers

### Current issue

History maintenance is currently append-plus-remove-first on arrays. This causes copying and element shifting each sample.

### Proposed change

Replace the helper with a fixed-capacity ring buffer that supports:

- O(1) append
- stable logical ordering when materializing for display
- a monotonically increasing revision counter

The revision counter can then be used by sparkline rendering instead of hashing the whole history array on every update.

### Expected impact

- Lower history maintenance overhead
- Cheaper sparkline dirty checking
- Better scaling if the dashboard adds more metrics later

---

## Proposal F — Make Sparkline Rendering Incremental

### Current issue

The current sparkline bridge already avoids many Core Animation costs, but it still rebuilds full paths from full history when a new sample arrives.

### Proposed change

Move to one of these incremental approaches:

1. Keep a fixed-capacity geometric model and only rebuild the trailing segment that changed
2. Keep an offscreen backing image or layer, scroll it left by one sample, and draw only the new right-edge data
3. Preserve the existing shape-layer design but drive invalidation with ring-buffer revision and width changes rather than full-history hashing

### Recommendation

Take option 3 first. It is the smallest change with the best risk-reward ratio.

Options 1 or 2 become attractive if Instruments still shows sparkline work as meaningful after the Bluetooth and observation fixes land.

### Expected impact

- Lower path rebuild cost
- Lower signature-comparison cost
- Less repeated layer work per sample

---

## Battery Detail Ownership Proposal

This section resolves the specific product issue raised during profiling review.

### Current behavior

- Battery detail shows only host battery information
- Wireless detail shows Bluetooth peripheral battery percentages when available
- Peripheral battery data is sampled continuously even when neither detail is open

### Proposed behavior

- Battery tile remains the host power-state summary tile
- Battery detail becomes the canonical surface for battery-related information across the device ecosystem visible to the Mac
- Connected Bluetooth devices appear in Battery detail under a `Connected Devices` section
- Wireless detail no longer owns peripheral battery percentages

### On desktop Macs

For Macs without an internal battery:

- Battery tile may continue to show `AC Power`
- Battery detail should still show connected device battery state if any is available
- If no internal or peripheral battery information exists, the detail should state that explicitly

### Why this matters

This change improves both UX and performance:

- UX: the Battery detail now answers the question users actually ask there
- Performance: the expensive Bluetooth peripheral battery scan becomes lazy instead of continuous

---

## Alternatives Considered

### Alternative 1 — Increase the global coalescing interval

Rejected as the primary fix.

This may smooth some main-thread churn, but it does not address the expensive Bluetooth sampling path and does not reduce the amount of work being done, only when it is committed.

### Alternative 2 — Lower the global polling frequency

Rejected.

It would reduce CPU, but it directly trades away dashboard freshness. The goal is to reduce wasted work, not lower fidelity.

### Alternative 3 — Keep peripheral batteries in Wireless detail and just cache more aggressively

Rejected.

Caching alone helps performance but does not solve the ownership mismatch. The detail would still be surprising to users, and the architecture would still mix connectivity and battery concerns.

### Alternative 4 — Rewrite the dashboard entirely in AppKit

Rejected.

The profile does not justify abandoning SwiftUI. The observed problems are primarily about observation boundaries, sampling scope, and hot-path ownership.

---

## Rollout Plan

### Phase 1 — Remove the largest hotspot

- Split Bluetooth state monitoring from peripheral battery detail collection
- Stop polling peripheral battery percentages on the tile path
- Add a Battery detail path that fetches connected-device batteries on demand

### Phase 2 — Narrow UI invalidation

- Convert generic computed `tileModel` access to stored per-view-model tile models
- Ensure the dashboard grid reads immutable tile state rather than recomputing models inline
- Re-profile to confirm reduced `DashboardView` and `NSHostingView` activity

### Phase 3 — Coordinate dashboard ticks

- Introduce a shared sampler or shared delivery batch for all tile updates
- Collapse many small update transactions into one dashboard tick

### Phase 4 — Reduce history and sparkline churn

- Introduce a real ring buffer type
- Replace full-history hashing with revision-aware invalidation
- Revisit incremental drawing only if profile data still justifies it

---

## Validation Plan

Each phase should be validated with the release-build profiling workflow already documented for the repository.

### Success metrics

- Lower total process CPU during an idle 20-second dashboard run
- Reduced samples in `BluetoothMonitorService.samplePeripheralBatteries()` and `IORegistryEntryCreateCFProperties`
- Reduced samples in `DashboardView.body`, tile-model getters, and `NSHostingView.layout`
- No visible loss in tile update cadence or rendering fidelity

### Required checks

- `swift test`
- `swiftlint lint --strict`
- Release-build Time Profiler comparison before and after each phase

### Suggested profiling scenarios

- Dashboard open with no detail overlay visible
- Battery detail opened on a Mac with Bluetooth peripherals connected
- Window resize and density change while metrics continue updating

---

## Risks

### Risk 1 — On-demand detail loading may feel stale on open

Mitigation:

- render immediately with the most recent cached detail payload if present
- refresh asynchronously after opening
- show a lightweight loading row if the detail payload has never been fetched

### Risk 2 — Shared dashboard sampling may over-centralize unrelated monitors

Mitigation:

- centralize cadence and delivery first, not all monitor implementation details
- keep monitor-specific services independent behind focused protocols

### Risk 3 — Battery ownership change may surprise existing users of Wireless detail

Mitigation:

- keep Wireless detail focused on signal and connection state
- optionally include a small note or icon cue in Wireless detail for a transition period

---

## Open Questions

1. Should Battery detail duplicate connected Bluetooth battery state in addition to Wireless detail during a transition period, or should ownership switch in one step?
2. Should on-demand detail providers cache their last successful payload while the dashboard remains open?
3. Do we want one unified `DashboardSampler` immediately, or should Phase 3 begin as a batched delivery layer over the existing monitor services?

---

## Recommendation

Implement Phase 1 first.

It is the highest-confidence performance win, it addresses the clearest hotspot in the supplied profile, and it fixes a real product issue at the same time: Battery detail should show connected Bluetooth battery state, but it currently does not.

After that lands, re-profile before doing deeper rendering work. If the Bluetooth split removes the dominant hotspot, the next most valuable work will likely be narrowing observation boundaries rather than rewriting rendering primitives.