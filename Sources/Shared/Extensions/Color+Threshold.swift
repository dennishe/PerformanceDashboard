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

    static let tileSurface = adaptive(
        light: NSColor(srgbRed: 0.98, green: 0.99, blue: 0.98, alpha: 1),
        dark: NSColor(srgbRed: 24 / 255, green: 39 / 255, blue: 44 / 255, alpha: 1)
    )

    static let dashboardBackground = adaptive(
        light: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.94, alpha: 1),
        dark: NSColor(srgbRed: 16 / 255, green: 27 / 255, blue: 32 / 255, alpha: 1)
    )

    static let dashboardTitlebar = adaptive(
        light: NSColor(srgbRed: 0.98, green: 0.99, blue: 0.98, alpha: 1),
        dark: NSColor(srgbRed: 21 / 255, green: 36 / 255, blue: 42 / 255, alpha: 1)
    )

    static let tileBorder = adaptive(
        light: NSColor(srgbRed: 0.79, green: 0.84, blue: 0.82, alpha: 1),
        dark: NSColor(srgbRed: 49 / 255, green: 66 / 255, blue: 72 / 255, alpha: 1)
    )

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }))
    }
}
