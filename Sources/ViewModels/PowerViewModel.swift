import SwiftUI

/// Threshold levels for power draw.
public struct PowerThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

@MainActor
@Observable
public final class PowerViewModel {
    public private(set) var watts: Double?
    public private(set) var history: [Double] = []

    private var adaptiveMax: Double = 20.0  // Start at 20 W; grows with observed values

    public var gaugeValue: Double? {
        guard let watts else { return nil }
        return min(1.0, max(0.0, watts / adaptiveMax))
    }

    public var wattsLabel: String {
        guard let watts else { return "—" }
        return String(format: "%.1f W", watts)
    }

    public var thresholdLevel: ThresholdLevel {
        PowerThreshold().level(for: gaugeValue ?? 0)
    }

    private let monitor: any MetricMonitorProtocol<PowerSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<PowerSnapshot>) {
        self.monitor = monitor
    }

    public func start() {
        task = Task {
            for await snapshot in monitor.stream() {
                update(snapshot)
            }
        }
    }

    public func stop() {
        task?.cancel()
        monitor.stop()
    }

    private func update(_ snapshot: PowerSnapshot) {
        watts = snapshot.watts
        if let newWatts = snapshot.watts, newWatts > adaptiveMax { adaptiveMax = newWatts }
        let normalized = snapshot.watts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        history.append(normalized)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
