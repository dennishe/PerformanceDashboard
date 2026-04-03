import SwiftUI
import AppKit

extension Color {
    /// Returns the semantic colour for a given threshold level.
    static func threshold(_ level: ThresholdLevel) -> Color {
        switch level {
        case .normal:   return .green
        case .warning:  return .orange
        case .critical: return .red
        case .inactive: return .secondary
        }
    }

    /// Tile card surface — uses the macOS semantic controlBackground color,
    /// which is white in light mode and elevated dark in dark mode.
    static let tileSurface = Color(nsColor: .controlBackgroundColor)

    /// Dashboard window background — uses the macOS semantic windowBackground color,
    /// which is light gray in light mode and near-black in dark mode.
    static let dashboardBackground = Color(nsColor: .windowBackgroundColor)
}
