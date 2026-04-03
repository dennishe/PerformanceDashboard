import SwiftUI

/// Threshold levels for Media Engine combined load.
public struct MediaEngineThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

@MainActor
@Observable
public final class MediaEngineViewModel {
    public private(set) var encodeMilliwatts: Double?
    public private(set) var decodeMilliwatts: Double?
    public private(set) var history: [Double] = []

    private var adaptiveMax: Double = 100.0  // mW; grows with observed values

    public var gaugeValue: Double? {
        let combined = combinedMilliwatts
        guard combined != nil else { return nil }
        return min(1.0, max(0.0, (combined ?? 0) / adaptiveMax))
    }

    public var encodeLabel: String {
        encodeMilliwatts.map { String(format: "Enc: %.0f mW", $0) } ?? "Enc: —"
    }

    public var decodeLabel: String {
        decodeMilliwatts.map { String(format: "Dec: %.0f mW", $0) } ?? "Dec: —"
    }

    public var combinedLabel: String {
        guard let combined = combinedMilliwatts else { return "—" }
        return String(format: "%.0f mW", combined)
    }

    public var thresholdLevel: ThresholdLevel {
        MediaEngineThreshold().level(for: gaugeValue ?? 0)
    }

    private var combinedMilliwatts: Double? {
        switch (encodeMilliwatts, decodeMilliwatts) {
        case let (enc?, dec?): return enc + dec
        case let (enc?, nil): return enc
        case let (nil, dec): return dec
        }
    }

    private let monitor: any MetricMonitorProtocol<MediaEngineSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<MediaEngineSnapshot>) {
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

    private func update(_ snapshot: MediaEngineSnapshot) {
        encodeMilliwatts = snapshot.encodeMilliwatts
        decodeMilliwatts = snapshot.decodeMilliwatts
        if let combined = combinedMilliwatts, combined > adaptiveMax { adaptiveMax = combined }
        let normalized = combinedMilliwatts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        history.append(normalized)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
