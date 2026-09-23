import Foundation

/// Snapshot of total system power draw.
public struct PowerSnapshot: MetricSnapshot {
    /// Total system power in watts, or `nil` when unavailable.
    public let watts: Double?
    public let components: [PowerComponent]

    public init(watts: Double?) {
        self.init(watts: watts, components: [])
    }

    public init(watts: Double?, components: [PowerComponent]) {
        self.watts = watts
        self.components = components
    }
}

public struct PowerComponent: Sendable, Equatable {
    public let name: String
    public let watts: Double

    public init(name: String, watts: Double) {
        self.name = name
        self.watts = watts
    }
}

/// Monitors system power draw via a platform-specific `PowerStrategy`.
/// The strategy is selected once when polling begins; adding a new platform requires
/// only a new `PowerStrategy` implementation — `sample` is never modified (OCP).
public final class PowerMonitorService: PollingMonitorBase<PowerSnapshot> {
    private let makeStrategy: @MonitorActor @Sendable () -> any PowerStrategy
    @MonitorActor private var strategy: (any PowerStrategy)?

    override public init() {
        makeStrategy = {
            PowerMonitorService.defaultStrategy()
        }
        super.init()
    }

    init(makeStrategy: @escaping @MonitorActor @Sendable () -> any PowerStrategy) {
        self.makeStrategy = makeStrategy
        super.init()
    }

    @MonitorActor
    override public func setUp() {
        strategy = makeStrategy()
    }

    @MonitorActor
    override public func sample() async -> PowerSnapshot? {
        guard var strategy else {
            return PowerSnapshot(watts: nil)
        }
        let snapshot = strategy.nextSnapshot()
        self.strategy = strategy
        return snapshot
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
