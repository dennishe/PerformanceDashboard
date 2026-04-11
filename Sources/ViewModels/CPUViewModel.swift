import SwiftUI

/// Threshold configuration for CPU utilisation.
@MainActor
@Observable
public final class CPUViewModel: MonitorViewModelBase<CPUSnapshot> {
    private let processorCount: Int
    private var lastSnapshot = CPUSnapshot(usage: 0)

    public var usage: Double { lastSnapshot.usage }
    public var usageLabel: String { usage.percentFormatted() }
    public var cores: [CPUCoreStat] { lastSnapshot.cores }
    public var topProcesses: [ProcessCPUStat] { lastSnapshot.topProcesses }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.cpu.level(for: usage) }

    override public init(
        monitor: some MetricMonitorProtocol<CPUSnapshot>,
        batcher: any UpdateScheduling = DashboardUpdateBatcher.shared
    ) {
        processorCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        super.init(monitor: monitor, batcher: batcher)
    }

    public init(
        monitor: some MetricMonitorProtocol<CPUSnapshot>,
        batcher: any UpdateScheduling = DashboardUpdateBatcher.shared,
        processorCount: Int
    ) {
        self.processorCount = max(processorCount, 1)
        super.init(monitor: monitor, batcher: batcher)
    }

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
            : makeProcessStats()
        return DetailModel(
            title: "CPU",
            systemImage: "cpu",
            primaryValue: usageLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            supplementarySections: makeSupplementarySections(),
            stats: stats
        )
    }

    private func makeProcessStats() -> [DetailModel.Stat] {
        let normalizedProcesses = topProcesses.map { process in
            DetailModel.Stat(label: process.name, value: normalizedSystemShare(for: process).percentFormatted())
        }

        let normalizedProcessUsage = topProcesses.reduce(0.0) { partialResult, process in
            partialResult + normalizedSystemShare(for: process)
        }
        let otherUsage = max(0, usage - normalizedProcessUsage)

        guard otherUsage > 0.001 else { return normalizedProcesses }
        return normalizedProcesses + [.init(label: "Other / system", value: otherUsage.percentFormatted())]
    }

    private func normalizedSystemShare(for process: ProcessCPUStat) -> Double {
        process.fraction / Double(processorCount)
    }

    private func makeSupplementarySections() -> [DetailModel.SupplementarySection] {
        guard !cores.isEmpty else { return [] }

        let items = cores.map { core in
            DetailModel.SupplementaryItem(
                label: core.label,
                subtitle: core.kind,
                value: core.usage.percentFormatted(),
                gaugeValue: core.usage
            )
        }
        return [.init(title: "Per-core", items: items)]
    }
}
