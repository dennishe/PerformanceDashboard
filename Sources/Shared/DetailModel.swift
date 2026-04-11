import Foundation

/// Snapshot of metric data for rendering the detail sheet.
public struct DetailModel: Sendable {
    public struct SupplementaryItem: Sendable, Identifiable {
        public let id: String
        public let label: String
        public let subtitle: String?
        public let value: String
        public let gaugeValue: Double

        public init(label: String, subtitle: String? = nil, value: String, gaugeValue: Double) {
            id = label + (subtitle.map { "-\($0)" } ?? "")
            self.label = label
            self.subtitle = subtitle
            self.value = value
            self.gaugeValue = gaugeValue
        }
    }

    public struct SupplementarySection: Sendable, Identifiable {
        public let id: String
        public let title: String
        public let items: [SupplementaryItem]

        public init(title: String, items: [SupplementaryItem]) {
            id = title
            self.title = title
            self.items = items
        }
    }

    /// A single secondary stat row (label + formatted value).
    public struct Stat: Sendable, Identifiable {
        public let id: String
        public let label: String
        public let value: String

        public init(label: String, value: String) {
            self.id = label
            self.label = label
            self.value = value
        }
    }

    public let title: String
    public let systemImage: String
    public let primaryValue: String
    public let thresholdLevel: ThresholdLevel
    /// Up to 900 samples (≈ 15 min at 1 Hz). The detail view slices this per-range.
    public let history: [Double]
    public let supplementarySections: [SupplementarySection]
    /// Secondary stat rows displayed below the chart.
    public let stats: [Stat]

    public init(
        title: String,
        systemImage: String,
        primaryValue: String,
        thresholdLevel: ThresholdLevel,
        history: [Double],
        supplementarySections: [SupplementarySection] = [],
        stats: [Stat]
    ) {
        self.title = title
        self.systemImage = systemImage
        self.primaryValue = primaryValue
        self.thresholdLevel = thresholdLevel
        self.history = history
        self.supplementarySections = supplementarySections
        self.stats = stats
    }
}
