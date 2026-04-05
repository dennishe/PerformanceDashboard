import Foundation

/// Immutable UI-facing state for a single dashboard tile.
public struct MetricTileModel: Equatable, Sendable {
    public let title: String
    public let displayTitle: String
    public let value: String
    public let gaugeValue: Double?
    public let history: [Double]
    public let thresholdLevel: ThresholdLevel
    public let subtitle: String?
    public let systemImage: String
    public let accessibilityLabel: String
    public let gaugeAccessibilityLabel: String
    public let sparklineAccessibilityLabel: String

    public init(
        title: String,
        value: String,
        gaugeValue: Double?,
        history: [Double],
        thresholdLevel: ThresholdLevel,
        subtitle: String? = nil,
        systemImage: String,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.displayTitle = title.uppercased()
        self.value = value
        self.gaugeValue = gaugeValue
        self.history = history
        self.thresholdLevel = thresholdLevel
        self.subtitle = subtitle
        self.systemImage = systemImage
        let accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityLabel = accessibilityLabel
        self.gaugeAccessibilityLabel = accessibilityLabel + " gauge"
        self.sparklineAccessibilityLabel = accessibilityLabel + " history"
    }
}
