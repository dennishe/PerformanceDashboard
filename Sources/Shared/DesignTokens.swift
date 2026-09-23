import SwiftUI
import AppKit

enum DashboardPalette {
    static func accent(title: String, level: ThresholdLevel, dark: Bool) -> NSColor {
        switch level {
        case .warning: return .systemOrange
        case .critical: return .systemRed
        case .inactive: return .secondaryLabelColor
        case .normal: break
        }

        let rgb: UInt32
        switch title {
        case "GPU": rgb = dark ? 0x56C8E1 : 0x1B6D91
        case "Memory", "Power", "Temp", "Temperature": rgb = dark ? 0xE9B86B : 0x975F22
        case "Disk": rgb = dark ? 0xEF9B68 : 0xAA5226
        case "ANE", "Media Engine": rgb = dark ? 0x6FBBC8 : 0x2C7180
        case "Wireless": rgb = dark ? 0x8AA2A5 : 0x526C6F
        default: rgb = dark ? 0x67DBB5 : 0x137C69
        }
        return NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    static func accent(title: String, level: ThresholdLevel, appearance: NSAppearance) -> NSColor {
        accent(title: title, level: level, dark: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
    }

    static func color(title: String, level: ThresholdLevel) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            accent(title: title, level: level, appearance: appearance)
        }))
    }
}

enum DashboardDesign {
    enum FontSize {
        static let tileCaption: CGFloat = 10
        static let tileSubtitle: CGFloat = 11
        static let tileControl: CGFloat = 12
        static let tileBody: CGFloat = 13
        static let tileHeader: CGFloat = 13
        static let tileValue: CGFloat = 26
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 5
        static let compact: CGFloat = 10
        static let regular: CGFloat = 12
        static let medium: CGFloat = 14
        static let large: CGFloat = 16
    }

    enum Opacity {
        static let tileChrome: Double = 0.07
        static let modalScrim: Double = 0.45
        static let popoverDivider: Double = 0.06
    }

    enum Animation {
        static let detailReveal = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.82)
        static let detailDismiss = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.85)
    }
}
