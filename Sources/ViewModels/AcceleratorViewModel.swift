import SwiftUI

/// Threshold configuration for ANE utilisation.
@MainActor
@Observable
public final class AcceleratorViewModel: MonitorViewModelBase<AcceleratorSnapshot> {
    private var lastSnapshot = AcceleratorSnapshot(aneUsage: nil)

    public var aneUsage: Double? { lastSnapshot.aneUsage }
    public var usageLabel: String { aneUsage.map { $0.percentFormatted() } ?? "N/A" }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.accelerator.level(for: aneUsage ?? 0) }

    override public func receive(_ snapshot: AcceleratorSnapshot) {
        lastSnapshot = snapshot
        if let value = snapshot.aneUsage {
            appendHistory(value)
        }
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "ANE",
            value: usageLabel,
            gaugeValue: aneUsage,
            history: history,
            thresholdLevel: MetricThresholds.accelerator.level(for: aneUsage ?? 0),
            systemImage: "brain"
        )
    }

    public var detailModel: DetailModel {
        DetailModel(
            title: "ANE",
            systemImage: "brain",
            primaryValue: usageLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: aneUsage != nil ? [.init(label: "Utilisation", value: usageLabel)] : []
        )
    }
}
