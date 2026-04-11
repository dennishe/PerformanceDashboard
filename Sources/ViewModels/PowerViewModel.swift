import SwiftUI

/// Threshold levels for power draw.
@MainActor
@Observable
public final class PowerViewModel: MonitorViewModelBase<PowerSnapshot> {
    private var lastSnapshot = PowerSnapshot(watts: nil)

    public var watts: Double? { lastSnapshot.watts }
    public var gaugeValue: Double? { watts.map { min(1.0, max(0.0, $0 / adaptiveMax)) } }
    public var wattsLabel: String { watts.map { $0.wattsFormatted() } ?? "—" }

    private var adaptiveMax: Double = 20.0  // Start at 20 W; grows with observed values

    public var thresholdLevel: ThresholdLevel {
        MetricThresholds.power.level(for: gaugeValue ?? 0)
    }

    override public func receive(_ snapshot: PowerSnapshot) {
        lastSnapshot = snapshot
        if let newWatts = snapshot.watts, newWatts > adaptiveMax { adaptiveMax = newWatts }
        let normalized = snapshot.watts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        appendHistory(normalized)
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "Power",
            value: wattsLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: MetricThresholds.power.level(for: gaugeValue ?? 0),
            systemImage: "bolt"
        )
    }

    public var detailModel: DetailModel {
        DetailModel(
            title: "Power",
            systemImage: "bolt",
            primaryValue: wattsLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: watts.map { [.init(label: "Draw", value: $0.wattsFormatted(precision: 2))] } ?? []
        )
    }
}
