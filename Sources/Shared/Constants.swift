import Foundation

/// Shared constants for the application.
enum Constants {
    /// Default polling interval for all monitor services.
    static let pollingInterval: Duration = .seconds(1)

    /// Number of historical samples to retain for sparklines.
    static let historySamples: Int = 60
}
