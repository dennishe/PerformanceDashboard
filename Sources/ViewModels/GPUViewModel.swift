import SwiftUI

/// Threshold configuration for GPU utilisation.
@MainActor
@Observable
public final class GPUViewModel: MonitorViewModelBase<GPUSnapshot> {
    private var lastSnapshot = GPUSnapshot(usage: nil)

    public private(set) var tileModel = MetricTileModel(
        title: "GPU",
        value: "N/A",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "display"
    )

    public var usage: Double? { lastSnapshot.usage }
    public var usageLabel: String { usage.map { $0.percentFormatted() } ?? "N/A" }

    public var thresholdLevel: ThresholdLevel { GPUThreshold().level(for: usage ?? 0) }

    override public func receive(_ snapshot: GPUSnapshot) {
        lastSnapshot = snapshot
        if let value = snapshot.usage {
            appendHistory(value)
        }
        assignIfChanged(&tileModel, to: Self.makeTileModel(usage: usage, usageLabel: usageLabel, history: history))
    }

    private static func makeTileModel(usage: Double?, usageLabel: String, history: [Double]) -> MetricTileModel {
        MetricTileModel(
            title: "GPU",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: GPUThreshold().level(for: usage ?? 0),
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
