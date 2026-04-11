import Foundation

public enum GaugeColorProfile: Equatable, Sendable {
    case standard
    case relaxed
    case thermal
    case disk
    case battery
    case network
    case wireless
    case inactive

    public func level(for gaugeValue: Double) -> ThresholdLevel {
        let clampedValue = min(max(gaugeValue, 0), 1)

        switch self {
        case .standard:
            return linearLevel(for: clampedValue, normalUpperBound: 0.6, warningUpperBound: 0.85)
        case .relaxed:
            return linearLevel(for: clampedValue, normalUpperBound: 0.7, warningUpperBound: 0.9)
        case .thermal:
            return linearLevel(for: clampedValue, normalUpperBound: 0.7, warningUpperBound: 0.85)
        case .disk:
            return linearLevel(for: clampedValue, normalUpperBound: 0.75, warningUpperBound: 0.9)
        case .battery:
            return inverseLevel(for: clampedValue, normalLowerBound: 0.2, warningLowerBound: 0.1)
        case .network:
            return linearLevel(for: clampedValue, normalUpperBound: 0.5, warningUpperBound: 1)
        case .wireless:
            return inverseLevel(for: clampedValue, normalLowerBound: 0.5, warningLowerBound: 0.36)
        case .inactive:
            return .inactive
        }
    }
}

private func linearLevel(
    for gaugeValue: Double,
    normalUpperBound: Double,
    warningUpperBound: Double
) -> ThresholdLevel {
    switch gaugeValue {
    case ..<normalUpperBound: return .normal
    case ..<warningUpperBound: return .warning
    default: return .critical
    }
}

private func inverseLevel(
    for gaugeValue: Double,
    normalLowerBound: Double,
    warningLowerBound: Double
) -> ThresholdLevel {
    switch gaugeValue {
    case normalLowerBound...: return .normal
    case warningLowerBound...: return .warning
    default: return .critical
    }
}

/// Immutable UI-facing state for a single dashboard tile.
public struct MetricTileModel: Equatable, Sendable {
    public let title: String
    public let displayTitle: String
    public let value: String
    public let gaugeValue: Double?
    public let gaugeColorProfile: GaugeColorProfile
    public let history: [Double]
    public let thresholdLevel: ThresholdLevel
    public let subtitle: String?
    /// Short explanation shown when `gaugeValue` is `nil` (metric unavailable on this device).
    public let unavailableReason: String?
    public let systemImage: String
    public let accessibilityLabel: String
    public let gaugeAccessibilityLabel: String
    public let sparklineAccessibilityLabel: String

    public init(
        title: String,
        value: String,
        gaugeValue: Double?,
        gaugeColorProfile: GaugeColorProfile = .standard,
        history: [Double],
        thresholdLevel: ThresholdLevel,
        subtitle: String? = nil,
        unavailableReason: String? = nil,
        systemImage: String,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.displayTitle = title.uppercased()
        self.value = value
        self.gaugeValue = gaugeValue
        self.gaugeColorProfile = gaugeColorProfile
        self.history = history
        self.thresholdLevel = thresholdLevel
        self.subtitle = subtitle
        self.unavailableReason = unavailableReason
        self.systemImage = systemImage
        let accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityLabel = accessibilityLabel
        self.gaugeAccessibilityLabel = accessibilityLabel + " gauge"
        self.sparklineAccessibilityLabel = accessibilityLabel + " history"
    }
}
