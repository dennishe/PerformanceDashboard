import SwiftUI

/// Threshold configuration for ANE utilisation.
public struct AcceleratorThreshold: ThresholdEvaluating {
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
public final class AcceleratorViewModel {
    public private(set) var aneUsage: Double?
    public private(set) var history: [Double] = []
    public var thresholdLevel: ThresholdLevel { AcceleratorThreshold().level(for: aneUsage ?? 0) }
    public var usageLabel: String {
        guard let aneUsage else { return "N/A" }
        return String(format: "%.1f%%", aneUsage * 100)
    }

    private let monitor: any MetricMonitorProtocol<AcceleratorSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<AcceleratorSnapshot>) {
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

    private func update(_ snapshot: AcceleratorSnapshot) {
        aneUsage = snapshot.aneUsage
        if let value = snapshot.aneUsage {
            history.append(value)
            if history.count > Constants.historySamples {
                history.removeFirst()
            }
        }
    }
}
