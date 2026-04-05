import Foundation

/// Shared constants for the application.
enum Constants {
    /// Default polling interval for all monitor services.
    static let pollingInterval: Duration = .seconds(1)

    /// Number of historical samples to retain for sparklines.
    static let historySamples: Int = 60

    /// Zero-prefilled history used so sparklines render at full width from launch.
    static let prefilledHistory: [Double] = Array(repeating: 0, count: historySamples)

    /// Short coalescing window for applying sampled values on the main actor.
    /// This keeps tiles visually in sync without adding a perceptible delay.
    static let updateCoalescingInterval: Duration = .milliseconds(25)

    /// Minimum width for the dashboard window content.
    static let dashboardMinimumWindowWidth: CGFloat = 900

    /// Lower bound for dynamically computed dashboard content height.
    static let dashboardMinimumContentHeight: CGFloat = 1

    /// Default size for the dashboard window.
    static let dashboardDefaultWindowWidth: CGFloat = 1200
    static let dashboardDefaultWindowHeight: CGFloat = 800
}
