import SwiftUI

/// Threshold configuration for disk usage.
@MainActor
@Observable
public final class DiskViewModel: MonitorViewModelBase<DiskSnapshot> {
    private var lastSnapshot = DiskSnapshot(usage: 0, total: 0, available: 0)

    public private(set) var tileModel = MetricTileModel(
        title: "Disk",
        value: 0.percentFormatted(),
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        subtitle: AppFormatters.byteCountString(0, style: .file) + " free",
        systemImage: "internaldrive"
    )

    public var usage: Double { lastSnapshot.usage }
    public var totalBytes: Int64 { lastSnapshot.total }
    public var availableBytes: Int64 { lastSnapshot.available }
    public var usageLabel: String { usage.percentFormatted() }
    public var availableLabel: String { AppFormatters.byteCountString(availableBytes, style: .file) }
    public var totalLabel: String { AppFormatters.byteCountString(totalBytes, style: .file) }

    public var thresholdLevel: ThresholdLevel { DiskThreshold().level(for: usage) }

    override public func receive(_ snapshot: DiskSnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.usage)
        assignIfChanged(
            &tileModel,
            to: Self.makeTileModel(
                usage: usage,
                usageLabel: usageLabel,
                availableLabel: availableLabel,
                history: history
            )
        )
    }

    private static func makeTileModel(
        usage: Double,
        usageLabel: String,
        availableLabel: String,
        history: [Double]
    ) -> MetricTileModel {
        MetricTileModel(
            title: "Disk",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: DiskThreshold().level(for: usage),
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
