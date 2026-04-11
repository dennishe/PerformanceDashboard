import SwiftUI

@MainActor
@Observable
public final class NetworkViewModel: MonitorViewModelBase<NetworkSnapshot> {
    /// Normalisation ceiling for gauge display. Warn above 50 MB/s, critical above this value.
    static let ceilingBytesPerSecond: Double = 100_000_000

    private var lastSnapshot = NetworkSnapshot(bytesInPerSecond: 0, bytesOutPerSecond: 0)

    public private(set) var historyIn: [Double] = Constants.prefilledHistory
    public private(set) var historyOut: [Double] = Constants.prefilledHistory

    public var bytesInPerSecond: Double { lastSnapshot.bytesInPerSecond }
    public var bytesOutPerSecond: Double { lastSnapshot.bytesOutPerSecond }
    public var inLabel: String { bytesPerSecondLabel(bytesInPerSecond) }
    public var outLabel: String { bytesPerSecondLabel(bytesOutPerSecond) }
    public var inGauge: Double { min(bytesInPerSecond / Self.ceilingBytesPerSecond, 1) }
    public var outGauge: Double { min(bytesOutPerSecond / Self.ceilingBytesPerSecond, 1) }
    public var historyInGauge: [Double] { historyIn.map { min($0 / Self.ceilingBytesPerSecond, 1) } }
    public var historyOutGauge: [Double] { historyOut.map { min($0 / Self.ceilingBytesPerSecond, 1) } }
    public var inTileModel: MetricTileModel {
        Self.makeDirectionalTileModel(
            direction: .inbound,
            value: inLabel,
            gaugeValue: inGauge,
            history: historyInGauge,
            thresholdLevel: thresholdLevel
        )
    }
    public var outTileModel: MetricTileModel {
        Self.makeDirectionalTileModel(
            direction: .outbound,
            value: outLabel,
            gaugeValue: outGauge,
            history: historyOutGauge,
            thresholdLevel: thresholdLevel
        )
    }

    public var thresholdLevel: ThresholdLevel { MetricThresholds.network.level(for: bytesInPerSecond) }

    private func bytesPerSecondLabel(_ bytes: Double) -> String {
        guard bytes > 0 else { return "0 KB/s" }
        return AppFormatters.byteCountString(Int64(bytes), style: .binary) + "/s"
    }

    override public func receive(_ snapshot: NetworkSnapshot) {
        lastSnapshot = snapshot
        historyIn = ringBufferAppending(
            historyIn,
            value: snapshot.bytesInPerSecond,
            maxCount: Constants.historySamples
        )
        historyOut = ringBufferAppending(
            historyOut,
            value: snapshot.bytesOutPerSecond,
            maxCount: Constants.historySamples
        )
        // Base-class history tracks the dominant direction's normalized gauge (combined sparkline).
        appendHistory(max(inGauge, outGauge))
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "Network",
            value: bytesPerSecondLabel(bytesInPerSecond + bytesOutPerSecond),
            gaugeValue: max(inGauge, outGauge),
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: "↓ \(inLabel)  ↑ \(outLabel)",
            systemImage: "network"
        )
    }

    private enum TileDirection {
        case inbound
        case outbound

        var title: String {
            switch self {
            case .inbound: "Net In"
            case .outbound: "Net Out"
            }
        }

        var systemImage: String {
            switch self {
            case .inbound: "arrow.down.circle"
            case .outbound: "arrow.up.circle"
            }
        }
    }

    private static func makeDirectionalTileModel(
        direction: TileDirection,
        value: String,
        gaugeValue: Double,
        history: [Double],
        thresholdLevel: ThresholdLevel
    ) -> MetricTileModel {
        MetricTileModel(
            title: direction.title,
            value: value,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            systemImage: direction.systemImage
        )
    }

    public var detailModel: DetailModel {
        DetailModel(
            title: "Network",
            systemImage: "network",
            primaryValue: bytesPerSecondLabel(bytesInPerSecond + bytesOutPerSecond),
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: [
                .init(label: "Download ↓", value: inLabel),
                .init(label: "Upload ↑", value: outLabel)
            ]
        )
    }
}
