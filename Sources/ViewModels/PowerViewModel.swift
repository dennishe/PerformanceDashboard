import SwiftUI

/// Threshold levels for power draw.
@MainActor
@Observable
public final class PowerViewModel: MonitorViewModelBase<PowerSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "Power",
        value: "—",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "bolt"
    )

    @ObservationIgnored
    public private(set) var watts: Double?
    @ObservationIgnored
    public private(set) var gaugeValue: Double?
    @ObservationIgnored
    public private(set) var wattsLabel: String = "—"

    private var adaptiveMax: Double = 20.0  // Start at 20 W; grows with observed values

    public var thresholdLevel: ThresholdLevel {
        PowerThreshold().level(for: gaugeValue ?? 0)
    }

    override public func receive(_ snapshot: PowerSnapshot) {
        watts = snapshot.watts
        if let newWatts = snapshot.watts, newWatts > adaptiveMax { adaptiveMax = newWatts }
        let normalized = snapshot.watts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        gaugeValue = snapshot.watts.map { min(1.0, max(0.0, $0 / adaptiveMax)) }
        wattsLabel = snapshot.watts.map { String(format: "%.1f W", $0) } ?? "—"
        appendHistory(normalized)
        let newTileModel = Self.makeTileModel(
            wattsLabel: wattsLabel,
            gaugeValue: gaugeValue,
            history: history
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        wattsLabel: String,
        gaugeValue: Double?,
        history: [Double]
    ) -> MetricTileModel {
        MetricTileModel(
            title: "Power",
            value: wattsLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: PowerThreshold().level(for: gaugeValue ?? 0),
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
            stats: watts.map { [.init(label: "Draw", value: String(format: "%.2f W", $0))] } ?? []
        )
    }
}
