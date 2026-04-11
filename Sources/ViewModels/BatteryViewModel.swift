import SwiftUI

@MainActor
@Observable
public final class BatteryViewModel: MonitorViewModelBase<BatterySnapshot> {
    public private(set) var snapshot = BatterySnapshot(
        isPresent: false, chargeFraction: 0, isCharging: false,
        onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
    )

    public var gaugeValue: Double? { snapshot.isPresent ? snapshot.chargeFraction : nil }
    public var chargeLabel: String { Self.makeChargeLabel(from: snapshot) }
    public var statusLabel: String? { Self.makeStatusLabel(from: snapshot) }
    public var cycleLabel: String? { snapshot.cycleCount.map { "\($0) cycles" } }

    public var thresholdLevel: ThresholdLevel {
        guard snapshot.isPresent else { return .inactive }
        return MetricThresholds.battery.level(for: snapshot.chargeFraction)
    }

    override public func receive(_ newSnapshot: BatterySnapshot) {
        snapshot = newSnapshot
        appendHistory(newSnapshot.chargeFraction)
    }

    override public func makeTileModel() -> MetricTileModel {
        let thresholdLevel: ThresholdLevel = snapshot.isPresent
            ? MetricThresholds.battery.level(for: snapshot.chargeFraction)
            : .inactive
        return MetricTileModel(
            title: "Battery",
            value: chargeLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: statusLabel,
            unavailableReason: snapshot.isPresent ? nil : "No battery on this Mac",
            systemImage: "battery.100"
        )
    }

    private static func makeChargeLabel(from snapshot: BatterySnapshot) -> String {
        guard snapshot.isPresent else { return "AC Power" }
        return snapshot.chargeFraction.percentFormatted()
    }

    private static func makeStatusLabel(from snapshot: BatterySnapshot) -> String? {
        guard snapshot.isPresent else { return nil }
        if snapshot.isCharging { return "Charging" }
        if snapshot.onAC { return "Charged" }
        if let tte = snapshot.timeToEmptyMinutes {
            let hours = tte / 60
            let mins = tte % 60
            return hours > 0 ? "\(hours)h \(mins)m left" : "\(mins)m left"
        }
        return "On battery"
    }

    public var detailModel: DetailModel {
        var stats: [DetailModel.Stat] = []
        if snapshot.isPresent {
            stats.append(.init(label: "Charge", value: chargeLabel))
            if let cycles = snapshot.cycleCount {
                stats.append(.init(label: "Cycle count", value: "\(cycles)"))
            }
            if let health = snapshot.healthFraction {
                stats.append(.init(label: "Health", value: health.percentFormatted()))
            }
            if let status = statusLabel {
                stats.append(.init(label: "Status", value: status))
            }
        }
        return DetailModel(
            title: "Battery",
            systemImage: "battery.100",
            primaryValue: chargeLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }
}
