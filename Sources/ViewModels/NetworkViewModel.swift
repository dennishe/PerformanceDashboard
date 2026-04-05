import SwiftUI

@MainActor
@Observable
public final class NetworkViewModel: MonitorViewModelBase<NetworkSnapshot> {
    /// Normalisation ceiling for gauge display. Warn above 50 MB/s, critical above this value.
    static let ceilingBytesPerSecond: Double = 100_000_000

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter
    }()

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

    @ObservationIgnored
    public private(set) var bytesInPerSecond: Double = 0
    @ObservationIgnored
    public private(set) var bytesOutPerSecond: Double = 0
    @ObservationIgnored
    public private(set) var historyIn: [Double] = Constants.prefilledHistory
    @ObservationIgnored
    public private(set) var historyOut: [Double] = Constants.prefilledHistory
    @ObservationIgnored
    public private(set) var inLabel: String = "0 KB/s"
    @ObservationIgnored
    public private(set) var outLabel: String = "0 KB/s"
    @ObservationIgnored
    public private(set) var inGauge: Double = 0
    @ObservationIgnored
    public private(set) var outGauge: Double = 0
    @ObservationIgnored
    public private(set) var historyInGauge: [Double] = Constants.prefilledHistory
    @ObservationIgnored
    public private(set) var historyOutGauge: [Double] = Constants.prefilledHistory

    public var thresholdLevel: ThresholdLevel { NetworkThreshold().level(for: bytesInPerSecond) }

    private func bytesPerSecondLabel(_ bytes: Double) -> String {
        guard bytes > 0 else { return "0 KB/s" }
        return Self.byteFormatter.string(fromByteCount: Int64(bytes)) + "/s"
    }

    override public func receive(_ snapshot: NetworkSnapshot) {
        bytesInPerSecond  = snapshot.bytesInPerSecond
        bytesOutPerSecond = snapshot.bytesOutPerSecond
        inLabel = bytesPerSecondLabel(snapshot.bytesInPerSecond)
        outLabel = bytesPerSecondLabel(snapshot.bytesOutPerSecond)

        let normalizedIn = min(snapshot.bytesInPerSecond / Self.ceilingBytesPerSecond, 1)
        let normalizedOut = min(snapshot.bytesOutPerSecond / Self.ceilingBytesPerSecond, 1)

        inGauge = normalizedIn
        outGauge = normalizedOut
        historyIn = updatedHistory(from: historyIn, adding: snapshot.bytesInPerSecond)
        historyOut = updatedHistory(from: historyOut, adding: snapshot.bytesOutPerSecond)
        historyInGauge = updatedHistory(from: historyInGauge, adding: normalizedIn)
        historyOutGauge = updatedHistory(from: historyOutGauge, adding: normalizedOut)

        let thresholdLevel = self.thresholdLevel
        let newInTileModel = Self.makeTileModel(
            direction: .inbound,
            value: inLabel,
            gaugeValue: inGauge,
            history: historyInGauge,
            thresholdLevel: thresholdLevel
        )
        if inTileModel != newInTileModel {
            inTileModel = newInTileModel
        }

        let newOutTileModel = Self.makeTileModel(
            direction: .outbound,
            value: outLabel,
            gaugeValue: outGauge,
            history: historyOutGauge,
            thresholdLevel: thresholdLevel
        )
        if outTileModel != newOutTileModel {
            outTileModel = newOutTileModel
        }
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

    private func updatedHistory(from history: [Double], adding value: Double) -> [Double] {
        var updatedHistory = history
        updatedHistory.append(value)
        if updatedHistory.count > Constants.historySamples {
            updatedHistory.removeFirst(updatedHistory.count - Constants.historySamples)
        }
        return updatedHistory
    }
}
