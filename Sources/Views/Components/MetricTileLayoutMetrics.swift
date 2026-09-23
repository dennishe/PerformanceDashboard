import AppKit

enum MetricTileLayoutMetrics {
    static let height: CGFloat = 190
    static let padding: CGFloat = 16
    static let topPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 3
    static let ringGaugeSize: CGFloat = 28
    static let contentHeight: CGFloat = height - padding - topPadding
    static let headerIconSize: CGFloat = 16
    static let headerGap: CGFloat = 8

    static func iconFrame() -> CGRect {
        CGRect(x: 0, y: (ringGaugeSize - headerIconSize) / 2, width: headerIconSize, height: headerIconSize)
    }

    static func titleFrame(width: CGFloat, trailingWidth: CGFloat, lineHeight: CGFloat) -> CGRect {
        let start = headerIconSize + headerGap
        return CGRect(
            x: start,
            y: (ringGaugeSize - lineHeight) / 2,
            width: max(0, width - start - trailingWidth - headerGap),
            height: lineHeight
        )
    }
}
