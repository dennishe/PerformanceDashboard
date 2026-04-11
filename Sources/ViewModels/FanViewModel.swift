import SwiftUI

/// Threshold levels for fan speed usage.
@MainActor
@Observable
public final class FanViewModel: MonitorViewModelBase<FanSnapshot> {
    private var lastSnapshot = FanSnapshot(fans: [])

    public var fans: [FanReading] { lastSnapshot.fans }
    public var gaugeValue: Double? { fans.map(\.fraction).max().map { max($0, 0) } }
    public var primaryLabel: String { Self.makePrimaryLabel(from: fans) }
    public var subtitle: String? { Self.makeSubtitle(from: fans) }

    public var thresholdLevel: ThresholdLevel {
        guard !fans.isEmpty else { return .inactive }
        return MetricThresholds.fan.level(for: gaugeValue ?? 0)
    }

    override public func receive(_ snapshot: FanSnapshot) {
        lastSnapshot = snapshot
        let fraction = fans.map(\.fraction).max() ?? 0
        appendHistory(fraction)
        refreshTileModel()
    }

    override public func makeTileModel() -> MetricTileModel {
        let thresholdLevel = gaugeValue.map(MetricThresholds.fan.level(for:)) ?? .inactive
        return MetricTileModel(
            title: "Fans",
            value: primaryLabel,
            gaugeValue: gaugeValue,
            gaugeColorProfile: gaugeValue == nil ? .inactive : .relaxed,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: subtitle,
            unavailableReason: gaugeValue == nil ? "No fans detected" : nil,
            systemImage: "fan"
        )
    }

    private static func makePrimaryLabel(from fans: [FanReading]) -> String {
        guard let fastest = fans.max(by: { $0.current < $1.current }) else {
            return "No fans"
        }
        return fastest.current.rpmFormatted()
    }

    private static func makeSubtitle(from fans: [FanReading]) -> String? {
        guard !fans.isEmpty else { return nil }
        return fans.enumerated()
            .map { index, fan in "F\(index): \(Int(fan.current)) / \(Int(fan.max))" }
            .joined(separator: " · ")
    }

    public var detailModel: DetailModel {
        let stats = fans.enumerated().map { index, fan in
            let currentRPM = fan.current.rpmFormatted().replacingOccurrences(of: " RPM", with: "")
            return DetailModel.Stat(
                label: "Fan \(index + 1)",
                value: "\(currentRPM) / \(fan.max.rpmFormatted())"
            )
        }
        return DetailModel(
            title: "Fans",
            systemImage: "fan",
            primaryValue: primaryLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }
}
