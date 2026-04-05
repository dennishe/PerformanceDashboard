import SwiftUI

/// Threshold configuration for GPU utilisation.
@MainActor
@Observable
public final class GPUViewModel: MonitorViewModelBase<GPUSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "GPU",
        value: GPUViewModel.makeUsageLabel(for: nil),
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "display"
    )

    @ObservationIgnored
    public private(set) var usage: Double?
    @ObservationIgnored
    public private(set) var usageLabel: String = GPUViewModel.makeUsageLabel(for: nil)

    public var thresholdLevel: ThresholdLevel { GPUThreshold().level(for: usage ?? 0) }

    override public func receive(_ snapshot: GPUSnapshot) {
        usage = snapshot.usage
        usageLabel = Self.makeUsageLabel(for: snapshot.usage)
        if let value = snapshot.usage {
            appendHistory(value)
        }
        let newTileModel = Self.makeTileModel(usage: usage, usageLabel: usageLabel, history: history)
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(usage: Double?, usageLabel: String, history: [Double]) -> MetricTileModel {
        MetricTileModel(
            title: "GPU",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: GPUThreshold().level(for: usage ?? 0),
            systemImage: "display"
        )
    }

    private static func makeUsageLabel(for usage: Double?) -> String {
        guard let usage else { return "N/A" }
        return String(format: "%.1f%%", usage * 100)
    }
}
