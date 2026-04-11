import SwiftUI

/// Threshold configuration for memory pressure.
@MainActor
@Observable
public final class MemoryViewModel: MonitorViewModelBase<MemorySnapshot> {
    private var lastSnapshot = MemorySnapshot(usage: 0, total: 0, used: 0)

    public var usage: Double { lastSnapshot.usage }
    public var usedBytes: UInt64 { lastSnapshot.used }
    public var totalBytes: UInt64 { lastSnapshot.total }
    public var usageLabel: String { usage.percentFormatted() }
    public var usedLabel: String { AppFormatters.byteCountString(Int64(usedBytes), style: .memory) }
    public var totalLabel: String { AppFormatters.byteCountString(Int64(totalBytes), style: .memory) }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.memory.level(for: usage) }

    override public func receive(_ snapshot: MemorySnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.usage)
        refreshTileModel()
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "Memory",
            value: usageLabel,
            gaugeValue: usage,
            gaugeColorProfile: .relaxed,
            history: history,
            thresholdLevel: MetricThresholds.memory.level(for: usage),
            subtitle: usedLabel + " / " + totalLabel,
            systemImage: "memorychip"
        )
    }

    public var detailModel: DetailModel {
        DetailModel(
            title: "Memory",
            systemImage: "memorychip",
            primaryValue: usageLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: [
                .init(label: "Used", value: usedLabel),
                .init(label: "Total", value: totalLabel),
                .init(
                    label: "Free",
                    value: AppFormatters.byteCountString(Int64(totalBytes) - Int64(usedBytes), style: .memory)
                )
            ]
        )
    }
}
