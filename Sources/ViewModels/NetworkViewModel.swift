import SwiftUI

/// Threshold configuration for network throughput (based on inbound).
public struct NetworkThreshold: ThresholdEvaluating {
    /// Warn above 50 MB/s, critical above 100 MB/s.
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<50_000_000:  return .normal
        case ..<100_000_000: return .warning
        default:             return .critical
        }
    }
}

@MainActor
@Observable
public final class NetworkViewModel {
    public private(set) var bytesInPerSecond: Double = 0
    public private(set) var bytesOutPerSecond: Double = 0
    public private(set) var historyIn: [Double] = []
    public private(set) var historyOut: [Double] = []
    public var thresholdLevel: ThresholdLevel { NetworkThreshold().level(for: bytesInPerSecond) }
    public var inLabel: String { bytesPerSecondLabel(bytesInPerSecond) }
    public var outLabel: String { bytesPerSecondLabel(bytesOutPerSecond) }

    private func bytesPerSecondLabel(_ bytes: Double) -> String {
        guard bytes > 0 else { return "0 KB/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary) + "/s"
    }
    /// Bytes-in normalised to [0, 1] against a 100 MB/s ceiling — for gauge display.
    public var inGauge: Double { min(bytesInPerSecond / 100_000_000, 1) }
    /// Bytes-out normalised to [0, 1] against a 100 MB/s ceiling — for gauge display.
    public var outGauge: Double { min(bytesOutPerSecond / 100_000_000, 1) }
    /// Normalised history for in-traffic sparkline display.
    public var historyInGauge: [Double] { historyIn.map { min($0 / 100_000_000, 1) } }
    /// Normalised history for out-traffic sparkline display.
    public var historyOutGauge: [Double] { historyOut.map { min($0 / 100_000_000, 1) } }

    private let monitor: any MetricMonitorProtocol<NetworkSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<NetworkSnapshot>) {
        self.monitor = monitor
    }

    public func start() {
        task = Task {
            for await snapshot in monitor.stream() {
                update(snapshot)
            }
        }
    }

    public func stop() {
        task?.cancel()
        monitor.stop()
    }

    private func update(_ snapshot: NetworkSnapshot) {
        bytesInPerSecond  = snapshot.bytesInPerSecond
        bytesOutPerSecond = snapshot.bytesOutPerSecond
        historyIn.append(snapshot.bytesInPerSecond)
        historyOut.append(snapshot.bytesOutPerSecond)
        if historyIn.count > Constants.historySamples { historyIn.removeFirst() }
        if historyOut.count > Constants.historySamples { historyOut.removeFirst() }
    }
}
