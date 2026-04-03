import SwiftUI

/// Threshold configuration for memory pressure.
public struct MemoryThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.7:  return .normal
        case ..<0.9:  return .warning
        default:      return .critical
        }
    }
}

@MainActor
@Observable
public final class MemoryViewModel {
    public private(set) var usage: Double = 0
    public private(set) var usedBytes: UInt64 = 0
    public private(set) var totalBytes: UInt64 = 0
    public private(set) var history: [Double] = []
    public var thresholdLevel: ThresholdLevel { MemoryThreshold().level(for: usage) }
    public var usageLabel: String { String(format: "%.1f%%", usage * 100) }
    public var usedLabel: String { ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory) }
    public var totalLabel: String { ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory) }

    private let monitor: any MetricMonitorProtocol<MemorySnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<MemorySnapshot>) {
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

    private func update(_ snapshot: MemorySnapshot) {
        usage      = snapshot.usage
        usedBytes  = snapshot.used
        totalBytes = snapshot.total
        history.append(snapshot.usage)
        if history.count > Constants.historySamples {
            history.removeFirst()
        }
    }
}
