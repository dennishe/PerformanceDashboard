import SwiftUI

/// Threshold configuration for CPU utilisation.
@MainActor
@Observable
public final class CPUViewModel: MonitorViewModelBase<CPUSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "CPU",
        value: CPUViewModel.makeUsageLabel(for: 0),
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "cpu"
    )

    @ObservationIgnored
    public private(set) var usage: Double = 0
    @ObservationIgnored
    public private(set) var usageLabel: String = CPUViewModel.makeUsageLabel(for: 0)
    @ObservationIgnored
    public private(set) var topProcesses: [ProcessCPUStat] = []

    public var thresholdLevel: ThresholdLevel { CPUThreshold().level(for: usage) }

    override public func receive(_ snapshot: CPUSnapshot) {
        usage = snapshot.usage
        topProcesses = snapshot.topProcesses
        usageLabel = Self.makeUsageLabel(for: snapshot.usage)
        appendHistory(snapshot.usage)
        let newTileModel = Self.makeTileModel(usage: usage, usageLabel: usageLabel, history: history)
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
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

    private static func makeUsageLabel(for usage: Double) -> String {
        String(format: "%.1f%%", usage * 100)
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
