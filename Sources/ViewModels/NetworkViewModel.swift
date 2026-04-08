import SwiftUI

@MainActor
@Observable
public final class NetworkViewModel: MonitorViewModelBase<NetworkSnapshot> {
    /// Normalisation ceiling for gauge display. Warn above 50 MB/s, critical above this value.
    static let ceilingBytesPerSecond: Double = 100_000_000

    private var lastSnapshot = NetworkSnapshot(bytesInPerSecond: 0, bytesOutPerSecond: 0)

    // MARK: - Combined tile (MetricTilePresenting)

    public private(set) var tileModel = MetricTileModel(
        title: "Network",
        value: "0 KB/s",
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        subtitle: "↓ 0 KB/s  ↑ 0 KB/s",
        systemImage: "network"
    )

    // MARK: - Per-direction models (used by NetworkTileView detail rows)

    public private(set) var inTileModel = MetricTileModel(
        title: "Net In",
        value: "0 KB/s",
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "arrow.down.circle"
    )
    public private(set) var outTileModel = MetricTileModel(
        title: "Net Out",
        value: "0 KB/s",
        gaugeValue: 0,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        systemImage: "arrow.up.circle"
    )

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

    public var thresholdLevel: ThresholdLevel { NetworkThreshold().level(for: bytesInPerSecond) }

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

        updateAllTileModels(
            totalLabel: bytesPerSecondLabel(bytesInPerSecond + bytesOutPerSecond),
            combinedGauge: max(inGauge, outGauge),
            thresholdLevel: thresholdLevel
        )
    }

    private func updateAllTileModels(
        totalLabel: String, combinedGauge: Double, thresholdLevel: ThresholdLevel
    ) {
        let newTile = MetricTileModel(
            title: "Network", value: totalLabel, gaugeValue: combinedGauge,
            history: history, thresholdLevel: thresholdLevel,
            subtitle: "↓ \(inLabel)  ↑ \(outLabel)", systemImage: "network"
        )
        assignIfChanged(&tileModel, to: newTile)

        let newIn = Self.makeTileModel(direction: .inbound, value: inLabel,
                                       gaugeValue: inGauge, history: historyInGauge,
                                       thresholdLevel: thresholdLevel)
        assignIfChanged(&inTileModel, to: newIn)

        let newOut = Self.makeTileModel(direction: .outbound, value: outLabel,
                                        gaugeValue: outGauge, history: historyOutGauge,
                                        thresholdLevel: thresholdLevel)
        assignIfChanged(&outTileModel, to: newOut)
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

    private static func makeTileModel(
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
