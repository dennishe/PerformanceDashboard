import SwiftUI

@MainActor
@Observable
public final class BatteryViewModel: MonitorViewModelBase<BatterySnapshot> {
    public private(set) var snapshot = BatterySnapshot(
        isPresent: false, chargeFraction: 0, isCharging: false,
        onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
    )

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

    override public func receive(_ newSnapshot: BatterySnapshot) {
        snapshot = newSnapshot
        appendHistory(newSnapshot.chargeFraction)
    }
}
