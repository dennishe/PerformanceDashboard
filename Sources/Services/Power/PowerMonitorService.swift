import Foundation

/// Snapshot of total system power draw.
public struct PowerSnapshot: Sendable {
    /// Total system power in watts, or `nil` when unavailable.
    public let watts: Double?
}

/// Monitors system power draw.
/// On Intel: reads the `PSTR` SMC key (sp78 type, watts).
/// On Apple Silicon: sums all IOReport "Energy Model" channels (mJ/s → W).
public final class PowerMonitorService: MetricMonitorProtocol {
    private var continuation: AsyncStream<PowerSnapshot>.Continuation?
    private var task: Task<Void, Never>?

    public init() {}

    @MainActor
    public func stream() -> AsyncStream<PowerSnapshot> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.task = Task { await self.poll(continuation: continuation) }
        }
    }

    @MainActor
    public func stop() {
        task?.cancel()
        continuation?.finish()
    }

    @MonitorActor
    private func poll(continuation: AsyncStream<PowerSnapshot>.Continuation) async {
        #if arch(arm64)
        var state = PowerIOReportState.setUp()
        #else
        let smc = SMCBridge()
        defer { smc?.close() }
        #endif
        while !Task.isCancelled {
            #if arch(arm64)
            let watts = state?.nextWatts()
            #else
            let watts: Double? = smcPower(smc)
            #endif
            continuation.yield(PowerSnapshot(watts: watts))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    #if !arch(arm64)
    nonisolated private func smcPower(_ bridge: SMCBridge?) -> Double? {
        guard let result = bridge?.readBytes(key: "PSTR") else { return nil }
        guard let watts = SMCBridge.sp78(result.bytes), watts > 0 else { return nil }
        return watts
    }
    #endif
}

// MARK: - IOReport power state (Apple Silicon only)

#if arch(arm64)
private struct PowerIOReportState {
    private let ref: IOReportSubscriptionRef
    private let channels: CFMutableDictionary
    private var prevSample: CFDictionary?

    static func setUp() -> PowerIOReportState? {
        guard let ch = IOReport.copyChannels(group: "Energy Model"),
              let sub = IOReport.subscribe(channels: ch) else { return nil }
        var state = PowerIOReportState(ref: sub.ref, channels: sub.subscribedChannels)
        state.prevSample = IOReport.takeSample(sub.ref, channels: sub.subscribedChannels)
        return state
    }

    private init(ref: IOReportSubscriptionRef, channels: CFMutableDictionary) {
        self.ref = ref
        self.channels = channels
    }

    mutating func nextWatts() -> Double? {
        let curr = IOReport.takeSample(ref, channels: channels)
        defer { prevSample = curr }
        guard let prev = prevSample, let curr,
              let delta = IOReport.sampleDelta(prev: prev, curr: curr) else { return nil }
        return extractWatts(from: delta)
    }

    private func extractWatts(from delta: CFDictionary) -> Double? {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else { return nil }
        // IOReport "Energy Model" channels use inconsistent units across channel types:
        //
        //   - "CPU Energy" (millijoules): the authoritative CPU aggregate.
        //     W = mJ_delta / 1_000
        //
        //   - "GPU Energy" and all other "*Energy" aggregates (nanojoules).
        //     W = nJ_delta / 1_000_000_000
        //
        //   - Per-core/per-state channels (ECPU*, PCPU*, DTL*, …): also millijoules,
        //     but already covered by "CPU Energy" — skipped to avoid double-counting.
        //
        //   - PCIe / apciec* channels: zero at idle, also nanojoules.

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
        guard found else { return nil }
        return watts
    }
}
#endif
