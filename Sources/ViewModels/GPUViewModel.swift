import SwiftUI

/// Threshold configuration for GPU utilisation.
@MainActor
@Observable
public final class GPUViewModel: MonitorViewModelBase<GPUSnapshot> {
    private var lastSnapshot = GPUSnapshot(usage: nil)

    public var usage: Double? { lastSnapshot.usage }
    public var usageLabel: String { usage.map { $0.percentFormatted() } ?? "N/A" }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.gpu.level(for: usage ?? 0) }

    override public func receive(_ snapshot: GPUSnapshot) {
        lastSnapshot = snapshot
        if let value = snapshot.usage {
            appendHistory(value)
        }
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "GPU",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: MetricThresholds.gpu.level(for: usage ?? 0),
            unavailableReason: usage == nil ? "GPU stats unavailable" : nil,
            systemImage: "display"
        )
    }

    public var detailModel: DetailModel {
        DetailModel(
            title: "GPU",
            systemImage: "display",
            primaryValue: usageLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: usage != nil ? [.init(label: "Utilisation", value: usageLabel)] : []
        )
    }
}
