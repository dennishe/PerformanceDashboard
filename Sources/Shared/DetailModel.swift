import Foundation

/// Snapshot of metric data for rendering the detail sheet.
public struct DetailModel: Sendable {
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
    /// Secondary stat rows displayed below the chart.
    public let stats: [Stat]
}
