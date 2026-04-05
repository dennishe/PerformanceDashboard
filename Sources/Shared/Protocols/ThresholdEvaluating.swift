import Foundation

/// Threshold levels used for colour-coding metric tiles.
public enum ThresholdLevel: Equatable, Sendable {
    case normal
    case warning
    case critical
    /// The metric is unavailable or not applicable (e.g. disconnected, no sensor).
    case inactive
}

/// Maps a 0–1 normalised value to a `ThresholdLevel`.
public protocol ThresholdEvaluating {
    func level(for value: Double) -> ThresholdLevel
}
