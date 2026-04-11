import Foundation

/// Reading for a single fan: current and maximum RPM.
public struct FanReading: Sendable, Equatable {
    public let current: Double
    public let max: Double

    /// Current speed as a fraction [0, 1] of its maximum.
    public var fraction: Double {
        max > 0 ? min(1.0, current / max) : 0
    }
}

/// Snapshot of all fans on the system.
public struct FanSnapshot: MetricSnapshot {
    /// One entry per fan. Empty on fanless Macs (e.g. MacBook Air M-series).
    public let fans: [FanReading]
}

/// Reads fan speeds and maxima from the SMC.
public final class FanMonitorService: PollingMonitorBase<FanSnapshot> {
    @MonitorActor private var smc: SMCBridge?

    @MonitorActor
    override public func setUp() {
        smc = SMCBridge()
    }

    @MonitorActor
    override public func tearDown() {
        smc?.close()
        smc = nil
    }

    @MonitorActor
    override public func sample() async -> FanSnapshot? {
        FanSnapshot(fans: FanMonitorService.sample(smc))
    }

    // MARK: - Private sampling

    nonisolated static func sample(_ reader: (any SMCReading)?) -> [FanReading] {
        guard let reader else { return [] }
        guard let countResult = reader.readBytes(key: "FNum"),
              let count = SMCBridge.ui8(countResult.bytes),
              count > 0 else { return [] }

        return (0..<min(count, 9)).compactMap { index in
            let suffix = String(index)
            guard let curResult = reader.readBytes(key: "F\(suffix)Ac"),
                  let maxResult = reader.readBytes(key: "F\(suffix)Mx"),
                  let current = SMCBridge.decodeFloat(curResult),
                  let maximum = SMCBridge.decodeFloat(maxResult),
                  maximum > 0 else { return nil }
            return FanReading(current: current, max: maximum)
        }
    }
}
