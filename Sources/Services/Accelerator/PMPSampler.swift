#if arch(arm64)
import Foundation

@MonitorActor
protocol PMPSampling: AnyObject {
    func setUp()
    func nextDelta() -> CFDictionary?
}

/// A single shared IOReport subscription to the `PMP / Energy Counters` group.
///
/// `AcceleratorMonitorService` and `MediaEngineMonitorService` both read from
/// the same PMP group. Sharing one subscription halves the
/// `IOReportCreateSamplesDelta` cost (a single channel-set iteration per tick
/// instead of two). Narrowing to the `Energy Counters` subgroup further reduces
/// the channel count to only the handful of energy channels (ANE, AVE, VDEC, …).
@MonitorActor
final class PMPSampler {
    static let shared = PMPSampler()
    private init() {}

    private var ref: IOReportSubscriptionRef?
    private var channels: CFMutableDictionary?
    private var prevSample: CFDictionary?
    private var cachedDelta: CFDictionary?
    private var lastSampleTime: ContinuousClock.Instant?

    // MARK: - Setup

    /// Must be called once before `nextDelta()` is used.
    /// Idempotent — safe to call from multiple consumers.
    func setUp() {
        guard ref == nil else { return }
        guard let ch = IOReport.copyChannels(group: "PMP", subgroup: "Energy Counters"),
              let sub = IOReport.subscribe(channels: ch) else { return }
        ref = sub.ref
        channels = sub.subscribedChannels
        prevSample = IOReport.takeSample(sub.ref, channels: sub.subscribedChannels)
    }

    // MARK: - Sampling

    /// Returns the delta dictionary for the current polling tick, or `nil` if unavailable.
    /// Multiple consumers calling within 500 ms of each other receive the **same** delta,
    /// so neither consumer gets a near-zero interval from back-to-back rapid sampling.
    ///
    /// `setUp()` is called lazily on every tick until it succeeds, so transient IOReport
    /// unavailability at launch (e.g. wake from sleep) recovers automatically.
    func nextDelta() -> CFDictionary? {
        setUp()   // idempotent; retries until ref is set
        guard let ref, let channels else { return nil }
        let now = PollingCadence.clock.now
        // Serve the cached delta to any consumer that calls within the same polling tick.
        if let lastTime = lastSampleTime,
           now < lastTime.advanced(by: .milliseconds(500)),
           let cached = cachedDelta {
            return cached
        }
        let curr = IOReport.takeSample(ref, channels: channels)
        let prev = prevSample
        prevSample = curr          // always advance baseline, even on first call
        lastSampleTime = now
        guard let prev, let curr else { return nil }
        cachedDelta = IOReport.sampleDelta(prev: prev, curr: curr)
        return cachedDelta
    }
}

extension PMPSampler: PMPSampling {}
#endif
