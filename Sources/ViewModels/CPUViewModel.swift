import SwiftUI

/// Threshold configuration for CPU utilisation.
@MainActor
@Observable
public final class CPUViewModel: MonitorViewModelBase<CPUSnapshot> {
    private var lastSnapshot = CPUSnapshot(usage: 0)

    public private(set) var tileModel = MetricTileModel(
        title: "CPU",
        value: "0.0%",
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "cpu"
    )

    public var usage: Double { lastSnapshot.usage }
    public var usageLabel: String { usage.percentFormatted() }
    public var topProcesses: [ProcessCPUStat] { lastSnapshot.topProcesses }

    public var thresholdLevel: ThresholdLevel { CPUThreshold().level(for: usage) }

    override public func receive(_ snapshot: CPUSnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.usage)
        assignIfChanged(&tileModel, to: Self.makeTileModel(usage: usage, usageLabel: usageLabel, history: history))
    }

    private static func makeTileModel(usage: Double, usageLabel: String, history: [Double]) -> MetricTileModel {
        MetricTileModel(
            title: "CPU",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: CPUThreshold().level(for: usage),
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
