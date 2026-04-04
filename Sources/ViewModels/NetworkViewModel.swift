import SwiftUI

@MainActor
@Observable
public final class NetworkViewModel: MonitorViewModelBase<NetworkSnapshot> {
    /// Normalisation ceiling for gauge display. Warn above 50 MB/s, critical above this value.
    static let ceilingBytesPerSecond: Double = 100_000_000

    public private(set) var bytesInPerSecond: Double = 0
    public private(set) var bytesOutPerSecond: Double = 0
    public private(set) var historyIn: [Double] = []
    public private(set) var historyOut: [Double] = []

    public var thresholdLevel: ThresholdLevel { NetworkThreshold().level(for: bytesInPerSecond) }
    public var inLabel: String { bytesPerSecondLabel(bytesInPerSecond) }
    public var outLabel: String { bytesPerSecondLabel(bytesOutPerSecond) }

    /// Bytes-in normalised to [0, 1] against the 100 MB/s ceiling — for gauge display.
    public var inGauge: Double { min(bytesInPerSecond / Self.ceilingBytesPerSecond, 1) }
    /// Bytes-out normalised to [0, 1] against the 100 MB/s ceiling — for gauge display.
    public var outGauge: Double { min(bytesOutPerSecond / Self.ceilingBytesPerSecond, 1) }
    /// Normalised history for in-traffic sparkline display.
    public var historyInGauge: [Double] { historyIn.map { min($0 / Self.ceilingBytesPerSecond, 1) } }
    /// Normalised history for out-traffic sparkline display.
    public var historyOutGauge: [Double] { historyOut.map { min($0 / Self.ceilingBytesPerSecond, 1) } }

    private func bytesPerSecondLabel(_ bytes: Double) -> String {
        guard bytes > 0 else { return "0 KB/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary) + "/s"
    }

    override public func receive(_ snapshot: NetworkSnapshot) {
        bytesInPerSecond  = snapshot.bytesInPerSecond
        bytesOutPerSecond = snapshot.bytesOutPerSecond
        historyIn.append(snapshot.bytesInPerSecond)
        historyOut.append(snapshot.bytesOutPerSecond)
        if historyIn.count > Constants.historySamples { historyIn.removeFirst() }
        if historyOut.count > Constants.historySamples { historyOut.removeFirst() }
    }
}
