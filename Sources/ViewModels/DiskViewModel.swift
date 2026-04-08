import SwiftUI

/// Threshold configuration for disk usage.
@MainActor
@Observable
public final class DiskViewModel: MonitorViewModelBase<DiskSnapshot> {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    public private(set) var tileModel = MetricTileModel(
        title: "Disk",
        value: DiskViewModel.makeUsageLabel(for: 0),
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        subtitle: DiskViewModel.byteFormatter.string(fromByteCount: 0) + " free",
        systemImage: "internaldrive"
    )

    @ObservationIgnored
    public private(set) var usage: Double = 0
    @ObservationIgnored
    public private(set) var totalBytes: Int64 = 0
    @ObservationIgnored
    public private(set) var availableBytes: Int64 = 0
    @ObservationIgnored
    public private(set) var usageLabel: String = DiskViewModel.makeUsageLabel(for: 0)
    @ObservationIgnored
    public private(set) var availableLabel: String = DiskViewModel.byteFormatter.string(fromByteCount: 0)
    @ObservationIgnored
    public private(set) var totalLabel: String = DiskViewModel.byteFormatter.string(fromByteCount: 0)

    public var thresholdLevel: ThresholdLevel { DiskThreshold().level(for: usage) }

    override public func receive(_ snapshot: DiskSnapshot) {
        usage          = snapshot.usage
        totalBytes     = snapshot.total
        availableBytes = snapshot.available
        usageLabel = Self.makeUsageLabel(for: snapshot.usage)
        availableLabel = Self.byteFormatter.string(fromByteCount: snapshot.available)
        totalLabel = Self.byteFormatter.string(fromByteCount: snapshot.total)
        appendHistory(snapshot.usage)
        let newTileModel = Self.makeTileModel(
            usage: usage,
            usageLabel: usageLabel,
            availableLabel: availableLabel,
            history: history
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
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

    private static func makeUsageLabel(for usage: Double) -> String {
        String(format: "%.1f%%", usage * 100)
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
