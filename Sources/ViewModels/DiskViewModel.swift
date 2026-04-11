import SwiftUI

/// Threshold configuration for disk usage.
@MainActor
@Observable
public final class DiskViewModel: MonitorViewModelBase<DiskSnapshot> {
    private var lastSnapshot = DiskSnapshot(usage: 0, total: 0, available: 0)

    public var usage: Double { lastSnapshot.usage }
    public var totalBytes: Int64 { lastSnapshot.total }
    public var availableBytes: Int64 { lastSnapshot.available }
    public var usageLabel: String { usage.percentFormatted() }
    public var availableLabel: String { AppFormatters.byteCountString(availableBytes, style: .file) }
    public var totalLabel: String { AppFormatters.byteCountString(totalBytes, style: .file) }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.disk.level(for: usage) }

    override public func receive(_ snapshot: DiskSnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.usage)
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "Disk",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: MetricThresholds.disk.level(for: usage),
            subtitle: availableLabel + " free",
            systemImage: "internaldrive"
        )
    }

    public var detailModel: DetailModel {
        DetailModel(
            title: "Disk",
            systemImage: "internaldrive",
            primaryValue: usageLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: [
                .init(label: "Used", value: usageLabel),
                .init(label: "Free", value: availableLabel),
                .init(label: "Total", value: totalLabel)
            ]
        )
    }
}
