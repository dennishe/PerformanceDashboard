import SwiftUI

/// Threshold configuration for memory pressure.
@MainActor
@Observable
public final class MemoryViewModel: MonitorViewModelBase<MemorySnapshot> {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    public private(set) var tileModel = MetricTileModel(
        title: "Memory",
        value: MemoryViewModel.makeUsageLabel(for: 0),
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        subtitle: MemoryViewModel.byteFormatter.string(fromByteCount: 0) + " / " +
            MemoryViewModel.byteFormatter.string(fromByteCount: 0),
        systemImage: "memorychip"
    )

    @ObservationIgnored
    public private(set) var usage: Double = 0
    @ObservationIgnored
    public private(set) var usedBytes: UInt64 = 0
    @ObservationIgnored
    public private(set) var totalBytes: UInt64 = 0
    @ObservationIgnored
    public private(set) var usageLabel: String = MemoryViewModel.makeUsageLabel(for: 0)
    @ObservationIgnored
    public private(set) var usedLabel: String = MemoryViewModel.byteFormatter.string(fromByteCount: 0)
    @ObservationIgnored
    public private(set) var totalLabel: String = MemoryViewModel.byteFormatter.string(fromByteCount: 0)

    public var thresholdLevel: ThresholdLevel { MemoryThreshold().level(for: usage) }

    override public func receive(_ snapshot: MemorySnapshot) {
        usage      = snapshot.usage
        usedBytes  = snapshot.used
        totalBytes = snapshot.total
        usageLabel = Self.makeUsageLabel(for: snapshot.usage)
        usedLabel = Self.byteFormatter.string(fromByteCount: Int64(snapshot.used))
        totalLabel = Self.byteFormatter.string(fromByteCount: Int64(snapshot.total))
        appendHistory(snapshot.usage)
        let newTileModel = Self.makeTileModel(
            usage: usage,
            usageLabel: usageLabel,
            usedLabel: usedLabel,
            totalLabel: totalLabel,
            history: history
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        usage: Double,
        usageLabel: String,
        usedLabel: String,
        totalLabel: String,
        history: [Double]
    ) -> MetricTileModel {
        MetricTileModel(
            title: "Memory",
            value: usageLabel,
            gaugeValue: usage,
            history: history,
            thresholdLevel: MemoryThreshold().level(for: usage),
            subtitle: usedLabel + " / " + totalLabel,
            systemImage: "memorychip"
        )
    }

    private static func makeUsageLabel(for usage: Double) -> String {
        String(format: "%.1f%%", usage * 100)
    }
}
