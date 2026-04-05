import SwiftUI

/// Threshold levels for fan speed usage.
@MainActor
@Observable
public final class FanViewModel: MonitorViewModelBase<FanSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "Fans",
        value: "No fans",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        systemImage: "fan"
    )

    @ObservationIgnored
    public private(set) var fans: [FanReading] = []
    @ObservationIgnored
    public private(set) var gaugeValue: Double?
    @ObservationIgnored
    public private(set) var primaryLabel: String = "No fans"
    @ObservationIgnored
    public private(set) var subtitle: String?

    public var thresholdLevel: ThresholdLevel {
        guard !fans.isEmpty else { return .inactive }
        return FanThreshold().level(for: gaugeValue ?? 0)
    }

    override public func receive(_ snapshot: FanSnapshot) {
        fans = snapshot.fans
        let fraction = fans.map(\.fraction).max() ?? 0
        gaugeValue = fans.map(\.fraction).max().map { max($0, 0) }
        primaryLabel = Self.makePrimaryLabel(from: fans)
        subtitle = Self.makeSubtitle(from: fans)
        appendHistory(fraction)
        let newTileModel = Self.makeTileModel(
            primaryLabel: primaryLabel,
            gaugeValue: gaugeValue,
            history: history,
            subtitle: subtitle
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        primaryLabel: String,
        gaugeValue: Double?,
        history: [Double],
        subtitle: String?
    ) -> MetricTileModel {
        let thresholdLevel = gaugeValue.map(FanThreshold().level(for:)) ?? .inactive
        return MetricTileModel(
            title: "Fans",
            value: primaryLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: subtitle,
            systemImage: "fan"
        )
    }

    private static func makePrimaryLabel(from fans: [FanReading]) -> String {
        guard let fastest = fans.max(by: { $0.current < $1.current }) else {
            return "No fans"
        }
        return String(format: "%.0f RPM", fastest.current)
    }

    private static func makeSubtitle(from fans: [FanReading]) -> String? {
        guard !fans.isEmpty else { return nil }
        return fans.enumerated()
            .map { index, fan in "F\(index): \(Int(fan.current)) / \(Int(fan.max))" }
            .joined(separator: " · ")
    }
}
