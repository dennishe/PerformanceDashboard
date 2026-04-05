import SwiftUI

/// Threshold configuration for ANE utilisation.
@MainActor
@Observable
public final class AcceleratorViewModel: MonitorViewModelBase<AcceleratorSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "ANE",
        value: AcceleratorViewModel.makeUsageLabel(for: nil),
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "brain"
    )

    @ObservationIgnored
    public private(set) var aneUsage: Double?
    @ObservationIgnored
    public private(set) var usageLabel: String = AcceleratorViewModel.makeUsageLabel(for: nil)

    public var thresholdLevel: ThresholdLevel { AcceleratorThreshold().level(for: aneUsage ?? 0) }

    override public func receive(_ snapshot: AcceleratorSnapshot) {
        aneUsage = snapshot.aneUsage
        usageLabel = Self.makeUsageLabel(for: snapshot.aneUsage)
        if let value = snapshot.aneUsage {
            appendHistory(value)
        }
        let newTileModel = Self.makeTileModel(aneUsage: aneUsage, usageLabel: usageLabel, history: history)
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        aneUsage: Double?,
        usageLabel: String,
        history: [Double]
    ) -> MetricTileModel {
        MetricTileModel(
            title: "ANE",
            value: usageLabel,
            gaugeValue: aneUsage,
            history: history,
            thresholdLevel: AcceleratorThreshold().level(for: aneUsage ?? 0),
            systemImage: "brain"
        )
    }

    private static func makeUsageLabel(for usage: Double?) -> String {
        guard let usage else { return "N/A" }
        return String(format: "%.1f%%", usage * 100)
    }
}
