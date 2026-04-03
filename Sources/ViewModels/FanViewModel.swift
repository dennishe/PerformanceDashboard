import SwiftUI

/// Threshold levels for fan speed usage.
public struct FanThreshold: ThresholdEvaluating {
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
public final class FanViewModel {
    public private(set) var fans: [FanReading] = []
    public private(set) var history: [Double] = []

    public var gaugeValue: Double? {
        let max = fans.map(\.fraction).max()
        return max.map { $0 > 0 ? $0 : 0 }
    }

    public var primaryLabel: String {
        guard let fastest = fans.max(by: { $0.current < $1.current }) else {
            return "No fans"
        }
        return String(format: "%.0f RPM", fastest.current)
    }

    public var subtitle: String? {
        guard !fans.isEmpty else { return nil }
        return fans.enumerated()
            .map { index, fan in "F\(index): \(Int(fan.current)) / \(Int(fan.max))" }
            .joined(separator: " · ")
    }

    public var thresholdLevel: ThresholdLevel {
        guard !fans.isEmpty else { return .inactive }
        return FanThreshold().level(for: gaugeValue ?? 0)
    }

    private let monitor: any MetricMonitorProtocol<FanSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<FanSnapshot>) {
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

    private func update(_ snapshot: FanSnapshot) {
        fans = snapshot.fans
        let fraction = fans.map(\.fraction).max() ?? 0
        history.append(fraction)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
