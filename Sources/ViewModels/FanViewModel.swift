import SwiftUI

/// Threshold levels for fan speed usage.
@MainActor
@Observable
public final class FanViewModel: MonitorViewModelBase<FanSnapshot> {
    private var lastSnapshot = FanSnapshot(fans: [])

    public private(set) var tileModel = MetricTileModel(
        title: "Fans",
        value: "No fans",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        systemImage: "fan"
    )

    public var fans: [FanReading] { lastSnapshot.fans }
    public var gaugeValue: Double? { fans.map(\.fraction).max().map { max($0, 0) } }
    public var primaryLabel: String { Self.makePrimaryLabel(from: fans) }
    public var subtitle: String? { Self.makeSubtitle(from: fans) }

    public var thresholdLevel: ThresholdLevel {
        guard !fans.isEmpty else { return .inactive }
        return FanThreshold().level(for: gaugeValue ?? 0)
    }

    override public func receive(_ snapshot: FanSnapshot) {
        lastSnapshot = snapshot
        let fraction = fans.map(\.fraction).max() ?? 0
        appendHistory(fraction)
        assignIfChanged(
            &tileModel,
            to: Self.makeTileModel(
                primaryLabel: primaryLabel,
                gaugeValue: gaugeValue,
                history: history,
                subtitle: subtitle
            )
        )
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
