import Foundation

/// Snapshot of ANE accelerator load.
public struct AcceleratorSnapshot: Sendable {
    /// ANE utilisation as a fraction in [0, 1]. `nil` if not available (Intel or IOReport unavailable).
    public let aneUsage: Double?
}

/// Monitors Apple ANE load via the private IOReport framework.
/// Uses two-sample delta energy-model data; only meaningful on Apple Silicon.
public final class AcceleratorMonitorService: MetricMonitorProtocol {
    private var continuation: AsyncStream<AcceleratorSnapshot>.Continuation?
    private var task: Task<Void, Never>?

    public init() {}

    @MainActor
    public func stream() -> AsyncStream<AcceleratorSnapshot> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.task = Task {
                await self.poll(continuation: continuation)
            }
        }
    }

    @MainActor
    public func stop() {
        task?.cancel()
        continuation?.finish()
    }

    @MonitorActor
    private func poll(continuation: AsyncStream<AcceleratorSnapshot>.Continuation) async {
        // State is local to this actor-isolated function — no shared-mutable-state concerns.
        #if arch(arm64)
        PMPSampler.shared.setUp()
        var ane = ANEState()
        #endif
        while !Task.isCancelled {
            #if arch(arm64)
            continuation.yield(AcceleratorSnapshot(aneUsage: ane.nextUsage()))
            #else
            continuation.yield(AcceleratorSnapshot(aneUsage: nil))
            #endif
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }
}

// MARK: – IOReport state (ARM64 only)

#if arch(arm64)
/// Extracts ANE utilisation from the shared `PMPSampler` delta.
///
/// Energy-model delta values are normalised against a running maximum that starts
/// at `initialMaxDelta` (calibrated for M1) and grows if a higher value is observed.
/// This gives a reasonable approximation of relative ANE utilisation.
private struct ANEState {
    /// Starting normalisation ceiling. Grows if exceeded; fully adaptive.
    private static let initialMaxDelta: Double = 1

    private var maxDelta: Double = ANEState.initialMaxDelta

    // MARK: Sampling

    /// Reads the next delta from PMPSampler and returns ANE utilisation in [0, 1].
    @MonitorActor mutating func nextUsage() -> Double? {
        guard let delta = PMPSampler.shared.nextDelta() else { return nil }
        return extractANE(from: delta)
    }

    // MARK: – Private helpers

    private mutating func extractANE(from delta: CFDictionary) -> Double? {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else { return nil }

        var total: Int64 = 0
        var found = false
        for channel in array {
            // Use IOReportChannelGetChannelName — the name is NOT in a plain dict key.
            guard IOReport.channelName(channel as CFDictionary) == "ANE" else { continue }
            let raw = IOReport.integerValue(channel as CFDictionary)
            // INT64_MIN is the sentinel for "privileged / unavailable".
            guard raw != Int64.min, raw >= 0 else { continue }
            total += raw
            found = true
        }
        guard found else { return nil }
        let value = Double(total)
        if value > maxDelta { maxDelta = value }
        return maxDelta > 0 ? min(1.0, max(0.0, value / maxDelta)) : nil
    }
}
#endif
