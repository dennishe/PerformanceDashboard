import AppKit

struct LayerColorComponents: Hashable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let normal = LayerColorComponents(nsColor: .systemGreen)
    static let warning = LayerColorComponents(nsColor: .systemOrange)
    static let critical = LayerColorComponents(nsColor: .systemRed)
    static let inactive = LayerColorComponents(nsColor: .secondaryLabelColor)
    static let blue = LayerColorComponents(nsColor: .systemBlue)

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.deviceRGB)
            ?? nsColor.usingColorSpace(.extendedSRGB)
            ?? NSColor(deviceWhite: 0, alpha: 1)

        red = converted.redComponent
        green = converted.greenComponent
        blue = converted.blueComponent
        alpha = converted.alphaComponent
    }

    func cgColor(alphaMultiplier: CGFloat = 1) -> CGColor {
        let finalAlpha = min(max(alpha * alphaMultiplier, 0), 1)
        return CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [red, green, blue, finalAlpha]
        ) ?? NSColor(deviceRed: red, green: green, blue: blue, alpha: finalAlpha).cgColor
    }

    func nsColor(alphaMultiplier: CGFloat = 1) -> NSColor {
        let finalAlpha = min(max(alpha * alphaMultiplier, 0), 1)
        return NSColor(deviceRed: red, green: green, blue: blue, alpha: finalAlpha)
    }

    static func threshold(_ level: ThresholdLevel) -> LayerColorComponents {
        switch level {
        case .normal: .normal
        case .warning: .warning
        case .critical: .critical
        case .inactive: .inactive
        }
    }
}
