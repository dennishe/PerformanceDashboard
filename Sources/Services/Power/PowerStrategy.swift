import Foundation

/// Platform-specific power reading strategy.
/// Conforming types hold any state needed between samples (IOReport subscriptions, SMC handles).
@MonitorActor
protocol PowerStrategy: Sendable {
    /// Returns the latest system power draw in watts, or `nil` when unavailable.
    mutating func nextWatts() -> Double?
}
