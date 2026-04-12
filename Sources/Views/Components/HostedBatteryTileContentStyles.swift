import AppKit

extension HostedBatteryTileContentView {
    enum Styles {
        static let headerTitle = LayerTextStyle.tileCaption()
        static let primaryLabel = LayerTextStyle(
            fontSize: 9,
            fontWeight: .bold,
            color: .secondaryLabelColor,
            kerning: 0.4,
            lineHeight: 11,
            fontKind: .system
        )
        static let primaryStatus = LayerTextStyle(
            fontSize: 10,
            fontWeight: .regular,
            color: .secondaryLabelColor,
            kerning: 0,
            lineHeight: 12,
            fontKind: .system
        )
        static let accessoryTitle = LayerTextStyle(
            fontSize: 9,
            fontWeight: .bold,
            color: .secondaryLabelColor,
            kerning: 0.4,
            lineHeight: 11,
            fontKind: .system
        )
        static let accessoryCount = LayerTextStyle(
            fontSize: 9,
            fontWeight: .medium,
            color: .secondaryLabelColor,
            kerning: 0,
            lineHeight: 11,
            fontKind: .monospacedDigits
        )

        static func headerValue(color: NSColor) -> LayerTextStyle {
            LayerTextStyle(
                fontSize: DashboardDesign.FontSize.tileBody,
                fontWeight: .semibold,
                color: color,
                kerning: 0,
                lineHeight: 16,
                fontKind: .monospacedDigits
            )
        }

        static func primaryValue(color: NSColor) -> LayerTextStyle {
            LayerTextStyle(
                fontSize: 24,
                fontWeight: .bold,
                color: color,
                kerning: 0,
                lineHeight: 28,
                fontKind: .monospacedDigits
            )
        }

        static func emptyMessage(isProminent: Bool) -> LayerTextStyle {
            LayerTextStyle(
                fontSize: isProminent ? DashboardDesign.FontSize.tileBody : 12,
                fontWeight: .medium,
                color: .secondaryLabelColor,
                kerning: 0,
                lineHeight: isProminent ? 16 : 14,
                fontKind: .system
            )
        }
    }
}
