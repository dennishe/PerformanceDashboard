import AppKit

@MainActor
final class LayerTextStyleCache {
    private struct FontKey: Hashable {
        let fontSize: Int
        let fontWeight: Int
        let fontKind: LayerTextStyle.FontKind
    }

    static let shared = LayerTextStyleCache()

    private var fontCache: [FontKey: NSFont] = [:]
    private var paragraphStyleCache: [Int: NSParagraphStyle] = [:]

    private init() {}

    func font(for style: LayerTextStyle) -> NSFont {
        let key = FontKey(
            fontSize: Int((style.fontSize * 100).rounded()),
            fontWeight: Int((style.fontWeight.rawValue * 1_000).rounded()),
            fontKind: style.fontKind
        )
        if let cachedFont = fontCache[key] {
            return cachedFont
        }

        let font: NSFont
        switch style.fontKind {
        case .system:
            font = NSFont.systemFont(ofSize: style.fontSize, weight: style.fontWeight)
        case .monospacedDigits:
            font = NSFont.monospacedDigitSystemFont(ofSize: style.fontSize, weight: style.fontWeight)
        }

        fontCache[key] = font
        return font
    }

    func paragraphStyle(lineHeight: CGFloat) -> NSParagraphStyle {
        let key = Int((lineHeight * 100).rounded())
        if let cachedStyle = paragraphStyleCache[key] {
            return cachedStyle
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingTail
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        let cachedStyle = style.copy() as? NSParagraphStyle ?? style
        paragraphStyleCache[key] = cachedStyle
        return cachedStyle
    }
}
