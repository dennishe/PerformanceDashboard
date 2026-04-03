import Foundation

/// Reading for a single fan: current and maximum RPM.
public struct FanReading: Sendable {
    public let current: Double
    public let max: Double

    /// Current speed as a fraction [0, 1] of its maximum.
    public var fraction: Double {
        max > 0 ? min(1.0, current / max) : 0
    }
}

/// Snapshot of all fans on the system.
public struct FanSnapshot: Sendable {
    /// One entry per fan. Empty on fanless Macs (e.g. MacBook Air M-series).
    public let fans: [FanReading]
}

/// Reads fan speeds and maxima from the SMC.
public final class FanMonitorService: MetricMonitorProtocol {
    private var continuation: AsyncStream<FanSnapshot>.Continuation?
    private var task: Task<Void, Never>?

    public init() {}

    @MainActor
    public func stream() -> AsyncStream<FanSnapshot> {
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
    private func poll(continuation: AsyncStream<FanSnapshot>.Continuation) async {
        let smc = SMCBridge()
        defer { smc?.close() }
        while !Task.isCancelled {
            continuation.yield(FanSnapshot(fans: FanMonitorService.sample(smc)))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    // MARK: - Private sampling

    nonisolated static func sample(_ bridge: SMCBridge?) -> [FanReading] {
        guard let bridge else { return [] }
        guard let countResult = bridge.readBytes(key: "FNum"),
              let count = SMCBridge.ui8(countResult.bytes),
              count > 0 else { return [] }

        return (0..<min(count, 9)).compactMap { index in
            let suffix = String(index)
            guard let curResult = bridge.readBytes(key: "F\(suffix)Ac"),
                  let maxResult = bridge.readBytes(key: "F\(suffix)Mx"),
                  let current = SMCBridge.decodeFloat(curResult),
                  let maximum = SMCBridge.decodeFloat(maxResult),
                  maximum > 0 else { return nil }
            return FanReading(current: current, max: maximum)
        }
    }
}
