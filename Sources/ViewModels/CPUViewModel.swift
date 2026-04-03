import SwiftUI

/// Threshold configuration for CPU utilisation.
public struct CPUThreshold: ThresholdEvaluating {
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
public final class CPUViewModel {
    public private(set) var usage: Double = 0
    public private(set) var history: [Double] = []
    public var thresholdLevel: ThresholdLevel { CPUThreshold().level(for: usage) }
    public var usageLabel: String { String(format: "%.1f%%", usage * 100) }

    private let monitor: any MetricMonitorProtocol<CPUSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<CPUSnapshot>) {
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

    private func update(_ snapshot: CPUSnapshot) {
        usage = snapshot.usage
        history.append(snapshot.usage)
        if history.count > Constants.historySamples {
            history.removeFirst()
        }
    }
}
