#if arch(arm64)
import Foundation

/// Reads total system power from the IOReport "Energy Model" group (Apple Silicon only).
struct AppleSiliconPowerStrategy: PowerStrategy {
    private let ref: IOReportSubscriptionRef
    private let channels: CFMutableDictionary
    private var prevSample: CFDictionary?

    init?() {
        guard let ch = IOReport.copyChannels(group: "Energy Model"),
              let sub = IOReport.subscribe(channels: ch) else { return nil }
        ref = sub.ref
        channels = sub.subscribedChannels
        prevSample = IOReport.takeSample(sub.ref, channels: sub.subscribedChannels)
    }

    mutating func nextWatts() -> Double? {
        let curr = IOReport.takeSample(ref, channels: channels)
        defer { prevSample = curr }
        guard let prev = prevSample, let curr,
              let delta = IOReport.sampleDelta(prev: prev, curr: curr) else { return nil }
        return extractWatts(from: delta)
    }

    // MARK: - Private

    private func extractWatts(from delta: CFDictionary) -> Double? {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else { return nil }

        // "CPU Energy" is in millijoules; all other "*Energy" channels are in nanojoules.
        // Per-core channels are already covered by "CPU Energy" — skip to avoid double-counting.
        var watts: Double = 0
        var found = false
        for channel in array {
            let name = IOReport.channelName(channel as CFDictionary) ?? ""
            let val = IOReport.integerValue(channel as CFDictionary)
            guard val != Int64.min, val >= 0 else { continue }
            if name == "CPU Energy" {
                watts += Double(val) / 1_000.0
                found = true
            } else if name.hasSuffix("Energy") {
                watts += Double(val) / 1_000_000_000.0
                found = true
            }
        }
        return found ? watts : nil
    }
}
#endif

/// No-op strategy returned when the platform strategy cannot be initialised.
struct NullPowerStrategy: PowerStrategy {
    mutating func nextWatts() -> Double? { nil }
}
