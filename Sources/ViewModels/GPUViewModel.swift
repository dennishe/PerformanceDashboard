import SwiftUI

/// Threshold configuration for GPU utilisation.
public struct GPUThreshold: ThresholdEvaluating {
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
public final class GPUViewModel {
    public private(set) var usage: Double?
    public private(set) var history: [Double] = []
    public var thresholdLevel: ThresholdLevel { GPUThreshold().level(for: usage ?? 0) }
    public var usageLabel: String {
        guard let usage else { return "N/A" }
        return String(format: "%.1f%%", usage * 100)
    }

    private let monitor: any MetricMonitorProtocol<GPUSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<GPUSnapshot>) {
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

    private func update(_ snapshot: GPUSnapshot) {
        usage = snapshot.usage
        if let value = snapshot.usage {
            history.append(value)
            if history.count > Constants.historySamples {
                history.removeFirst()
            }
        }
    }
}
