import Foundation

/// Snapshot of total system power draw.
public struct PowerSnapshot: MetricSnapshot {
    /// Total system power in watts, or `nil` when unavailable.
    public let watts: Double?
}

/// Monitors system power draw via a platform-specific `PowerStrategy`.
/// The strategy is selected once when polling begins; adding a new platform requires
/// only a new `PowerStrategy` implementation — `sample` is never modified (OCP).
public final class PowerMonitorService: PollingMonitorBase<PowerSnapshot> {
    @MonitorActor private var strategy: (any PowerStrategy)?

    @MonitorActor
    override public func setUp() {
        strategy = PowerMonitorService.defaultStrategy()
    }

    @MonitorActor
    override public func sample() async -> PowerSnapshot? {
        guard var strategy else {
            return PowerSnapshot(watts: nil)
        }
        let watts = strategy.nextWatts()
        self.strategy = strategy
        return PowerSnapshot(watts: watts)
    }

    @MonitorActor
    private static func defaultStrategy() -> any PowerStrategy {
        #if arch(arm64)
        return AppleSiliconPowerStrategy() ?? NullPowerStrategy()
        #else
        return IntelSMCPowerStrategy()
        #endif
    }
}
