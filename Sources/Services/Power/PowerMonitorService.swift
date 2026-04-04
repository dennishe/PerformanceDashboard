import Foundation

/// Snapshot of total system power draw.
public struct PowerSnapshot: Sendable {
    /// Total system power in watts, or `nil` when unavailable.
    public let watts: Double?
}

/// Monitors system power draw via a platform-specific `PowerStrategy`.
/// The strategy is selected once when polling begins; adding a new platform requires
/// only a new `PowerStrategy` implementation — `poll` is never modified (OCP).
public final class PowerMonitorService: PollingMonitorBase<PowerSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<PowerSnapshot>.Continuation) async {
        var strategy = PowerMonitorService.defaultStrategy()
        while !Task.isCancelled {
            continuation.yield(PowerSnapshot(watts: strategy.nextWatts()))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
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
