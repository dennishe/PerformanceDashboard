import SwiftUI

/// Threshold configuration for disk usage.
public struct DiskThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.75: return .normal
        case ..<0.9:  return .warning
        default:      return .critical
        }
    }
}

@MainActor
@Observable
public final class DiskViewModel {
    public private(set) var usage: Double = 0
    public private(set) var totalBytes: Int64 = 0
    public private(set) var availableBytes: Int64 = 0
    public private(set) var history: [Double] = []
    public var thresholdLevel: ThresholdLevel { DiskThreshold().level(for: usage) }
    public var usageLabel: String { String(format: "%.1f%%", usage * 100) }
    public var availableLabel: String { ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file) }
    public var totalLabel: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }

    private let monitor: any MetricMonitorProtocol<DiskSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<DiskSnapshot>) {
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

    private func update(_ snapshot: DiskSnapshot) {
        usage          = snapshot.usage
        totalBytes     = snapshot.total
        availableBytes = snapshot.available
        history.append(snapshot.usage)
        if history.count > Constants.historySamples {
            history.removeFirst()
        }
    }
}
