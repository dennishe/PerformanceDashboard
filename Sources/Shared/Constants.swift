import Foundation

/// Shared constants for the application.
enum Constants {
    /// Default polling interval for all monitor services.
    static let pollingInterval: Duration = .seconds(1)

    /// Battery charge, cycle count, and health change slowly enough to sample lazily.
    static let batteryPollingInterval: Duration = .seconds(60)

    /// Peripheral battery levels change slowly, so refresh accessory batteries less often.
    static let peripheralBatteryRefreshInterval: Duration = .seconds(60)

    /// Number of historical samples to retain for sparklines.
    static let historySamples: Int = 60

    /// Zero-prefilled history used so sparklines render at full width from launch.
    static let prefilledHistory: [Double] = Array(repeating: 0, count: historySamples)

    /// Number of extended historical samples for the detail view (≈ 15 minutes at 1 Hz).
    static let extendedHistorySamples: Int = 900

    /// Short coalescing window for applying sampled values on the main actor.
    /// This reduces redundant UI transactions while keeping displayed data unchanged.
    static let updateCoalescingInterval: Duration = .milliseconds(100)

    /// Minimum width for the dashboard window content.
    /// 560 pt allows a 3-column layout even in comfortable mode (3×170 + 2×12 + 2×16 = 574).
    static let dashboardMinimumWindowWidth: CGFloat = 560

    /// Default size for the dashboard window.
    static let dashboardDefaultWindowWidth: CGFloat = 1200
    static let dashboardDefaultWindowHeight: CGFloat = 800
}
