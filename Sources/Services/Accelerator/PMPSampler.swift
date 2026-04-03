#if arch(arm64)
import Foundation

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

    /// Takes a new sample and returns the delta dictionary, or `nil` if unavailable.
    /// Callers should extract their own channels from the returned dictionary.
    func nextDelta() -> CFDictionary? {
        guard let ref, let channels else { return nil }
        let curr = IOReport.takeSample(ref, channels: channels)
        defer { prevSample = curr }
        guard let prev = prevSample, let curr else { return nil }
        return IOReport.sampleDelta(prev: prev, curr: curr)
    }
}
#endif
