import SwiftUI

/// Threshold configuration for CPU utilisation.
@MainActor
@Observable
public final class CPUViewModel: MonitorViewModelBase<CPUSnapshot> {
    private var lastSnapshot = CPUSnapshot(usage: 0)

    public var usage: Double { lastSnapshot.usage }
    public var usageLabel: String { usage.percentFormatted() }
    public var topProcesses: [ProcessCPUStat] { lastSnapshot.topProcesses }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.cpu.level(for: usage) }

    override public func receive(_ snapshot: CPUSnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.usage)
        refreshTileModel()
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "CPU",
            value: usageLabel,
            gaugeValue: usage,
            gaugeColorProfile: .standard,
            history: history,
            thresholdLevel: MetricThresholds.cpu.level(for: usage),
            systemImage: "cpu"
        )
    }

    public var detailModel: DetailModel {
        let stats: [DetailModel.Stat] = topProcesses.isEmpty
            ? [.init(label: "Usage", value: usageLabel)]
            : topProcesses.map { .init(label: $0.name, value: $0.percentLabel) }
        return DetailModel(
            title: "CPU",
            systemImage: "cpu",
            primaryValue: usageLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }
}
