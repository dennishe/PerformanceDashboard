import SwiftUI

@MainActor
@Observable
public final class BatteryViewModel: MonitorViewModelBase<BatterySnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "Battery",
        value: "AC Power",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        systemImage: "battery.100"
    )

    @ObservationIgnored
    public private(set) var snapshot = BatterySnapshot(
        isPresent: false, chargeFraction: 0, isCharging: false,
        onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
    )
    @ObservationIgnored
    public private(set) var gaugeValue: Double?
    @ObservationIgnored
    public private(set) var chargeLabel: String = "AC Power"
    @ObservationIgnored
    public private(set) var statusLabel: String?
    @ObservationIgnored
    public private(set) var cycleLabel: String?

    public var thresholdLevel: ThresholdLevel {
        guard snapshot.isPresent else { return .inactive }
        return BatteryThreshold().level(for: snapshot.chargeFraction)
    }

    override public func receive(_ newSnapshot: BatterySnapshot) {
        snapshot = newSnapshot
        gaugeValue = newSnapshot.isPresent ? newSnapshot.chargeFraction : nil
        chargeLabel = Self.makeChargeLabel(from: newSnapshot)
        statusLabel = Self.makeStatusLabel(from: newSnapshot)
        cycleLabel = newSnapshot.cycleCount.map { "\($0) cycles" }
        appendHistory(newSnapshot.chargeFraction)
        let newTileModel = Self.makeTileModel(
            snapshot: snapshot,
            chargeLabel: chargeLabel,
            gaugeValue: gaugeValue,
            history: history,
            statusLabel: statusLabel
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        snapshot: BatterySnapshot,
        chargeLabel: String,
        gaugeValue: Double?,
        history: [Double],
        statusLabel: String?
    ) -> MetricTileModel {
        let thresholdLevel: ThresholdLevel = snapshot.isPresent
            ? BatteryThreshold().level(for: snapshot.chargeFraction)
            : .inactive
        return MetricTileModel(
            title: "Battery",
            value: chargeLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: statusLabel,
            systemImage: "battery.100"
        )
    }

    private static func makeChargeLabel(from snapshot: BatterySnapshot) -> String {
        guard snapshot.isPresent else { return "AC Power" }
        return String(format: "%.1f%%", snapshot.chargeFraction * 100)
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
}
