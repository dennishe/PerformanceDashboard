import AppKit

struct LayerTextStyle: Equatable {
    enum FontKind: Equatable {
        case system
        case monospacedDigits
    }

    let fontSize: CGFloat
    let fontWeight: NSFont.Weight
    let color: NSColor
    let kerning: CGFloat
    let lineHeight: CGFloat
    let fontKind: FontKind

    @MainActor
    func font() -> NSFont {
        LayerTextStyleCache.shared.font(for: self)
    }

    @MainActor
    func textAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: font(),
            .foregroundColor: color,
            .kern: kerning,
            .paragraphStyle: paragraphStyle()
        ]
    }

    @MainActor
    private func paragraphStyle() -> NSParagraphStyle {
        LayerTextStyleCache.shared.paragraphStyle(lineHeight: lineHeight)
    }

    static func tileCaption(color: NSColor = .secondaryLabelColor) -> LayerTextStyle {
        LayerTextStyle(
            fontSize: DashboardDesign.FontSize.tileCaption,
            fontWeight: .semibold,
            color: color,
            kerning: 0.5,
            lineHeight: 12,
            fontKind: .system
        )
    }

    static func tileValue(color: NSColor) -> LayerTextStyle {
        LayerTextStyle(
            fontSize: DashboardDesign.FontSize.tileValue,
            fontWeight: .semibold,
            color: color,
            kerning: 0,
            lineHeight: 32,
            fontKind: .monospacedDigits
        )
    }

    static func tileSubtitle(color: NSColor = .tertiaryLabelColor) -> LayerTextStyle {
        LayerTextStyle(
            fontSize: DashboardDesign.FontSize.tileSubtitle,
            fontWeight: .regular,
            color: color,
            kerning: 0,
            lineHeight: 14,
            fontKind: .system
        )
    }

    static func tileBody(color: NSColor = .labelColor) -> LayerTextStyle {
        LayerTextStyle(
            fontSize: DashboardDesign.FontSize.tileBody,
            fontWeight: .regular,
            color: color,
            kerning: 0,
            lineHeight: 16,
            fontKind: .monospacedDigits
        )
    }
}
