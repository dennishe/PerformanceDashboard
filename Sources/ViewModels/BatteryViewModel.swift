import SwiftUI

/// Threshold levels for battery charge (inverted — low charge is critical).
public struct BatteryThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case 0.2...: return .normal
        case 0.1...: return .warning
        default:     return .critical
        }
    }
}

@MainActor
@Observable
public final class BatteryViewModel {
    public private(set) var snapshot = BatterySnapshot(
        isPresent: false, chargeFraction: 0, isCharging: false,
        onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
    )
    public private(set) var history: [Double] = []

    public var gaugeValue: Double? { snapshot.isPresent ? snapshot.chargeFraction : nil }

    public var chargeLabel: String {
        guard snapshot.isPresent else { return "AC Power" }
        return String(format: "%.1f%%", snapshot.chargeFraction * 100)
    }

    public var statusLabel: String? {
        guard snapshot.isPresent else { return nil }
        if snapshot.isCharging { return "Charging" }
        if snapshot.onAC { return "Charged" }
        if let tte = snapshot.timeToEmptyMinutes {
            let hours = tte / 60, mins = tte % 60
            return hours > 0 ? "\(hours)h \(mins)m left" : "\(mins)m left"
        }
        return "On battery"
    }

    public var cycleLabel: String? {
        snapshot.cycleCount.map { "\($0) cycles" }
    }

    public var thresholdLevel: ThresholdLevel {
        guard snapshot.isPresent else { return .inactive }
        return BatteryThreshold().level(for: snapshot.chargeFraction)
    }

    private let monitor: any MetricMonitorProtocol<BatterySnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<BatterySnapshot>) {
        self.monitor = monitor
    }

    public func start() {
        task = Task {
            for await newSnapshot in monitor.stream() {
                update(newSnapshot)
            }
        }
    }

    public func stop() {
        task?.cancel()
        monitor.stop()
    }

    private func update(_ newSnapshot: BatterySnapshot) {
        snapshot = newSnapshot
        history.append(newSnapshot.chargeFraction)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
