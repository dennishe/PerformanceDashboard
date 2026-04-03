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

    /// Tile card surface — white in light mode, slightly elevated dark in dark mode.
    /// Matches the card surfaces used in macOS Settings.
    static let tileSurface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.17, alpha: 1)   // ~#2b2b2b
            : .white
    })

    /// Dashboard window background — light gray in light mode, near-black in dark mode.
    /// Matches the window background used in macOS Settings.
    static let dashboardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.11, alpha: 1)   // ~#1c1c1c
            : NSColor(white: 0.94, alpha: 1)   // ~#f0f0f0
    })
}
