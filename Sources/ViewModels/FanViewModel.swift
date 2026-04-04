import SwiftUI

/// Threshold levels for fan speed usage.
@MainActor
@Observable
public final class FanViewModel: MonitorViewModelBase<FanSnapshot> {
    public private(set) var fans: [FanReading] = []

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

    override public func receive(_ snapshot: FanSnapshot) {
        fans = snapshot.fans
        let fraction = fans.map(\.fraction).max() ?? 0
        appendHistory(fraction)
    }
}
