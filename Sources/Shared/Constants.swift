import Foundation

/// Shared constants for the application.
enum Constants {
    /// Default polling interval for all monitor services.
    static let pollingInterval: Duration = .seconds(1)

    /// Number of historical samples to retain for sparklines.
    static let historySamples: Int = 60

    /// Minimum width for the dashboard window content.
    static let dashboardMinimumWindowWidth: CGFloat = 900

    /// Lower bound for dynamically computed dashboard content height.
    static let dashboardMinimumContentHeight: CGFloat = 1

    /// Default size for the dashboard window.
    static let dashboardDefaultWindowWidth: CGFloat = 1200
    static let dashboardDefaultWindowHeight: CGFloat = 800
}
