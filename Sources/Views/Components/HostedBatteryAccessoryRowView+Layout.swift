import AppKit

extension HostedBatteryAccessoryRowView {
    enum Styles {
        static let badge = LayerTextStyle(
            fontSize: 7,
            fontWeight: .bold,
            color: .labelColor,
            kerning: 0,
            lineHeight: 8,
            fontKind: .system
        )

        static func value(color: NSColor, isProminent: Bool) -> LayerTextStyle {
            LayerTextStyle(
                fontSize: isProminent ? 13 : 12,
                fontWeight: .semibold,
                color: color,
                kerning: 0,
                lineHeight: isProminent ? 15 : 14,
                fontKind: .monospacedDigits
            )
        }
    }
}

extension HostedBatteryAccessoryRowView {
    struct RowLayout {
        let bounds: CGRect
        let glyphFrame: CGRect
        let barFrame: CGRect
        let fillWidth: CGFloat
        let valueWidth: CGFloat
        let valueLineHeight: CGFloat
        let isProminent: Bool

        init(bounds: CGRect, row: BatteryTileGaugeRow, isProminent: Bool) {
            self.bounds = bounds
            self.isProminent = isProminent

            let glyphSize = min(bounds.height, isProminent ? 22 : 18)
            valueWidth = isProminent ? 38 : 34

            let gap: CGFloat = isProminent ? 8 : 6
            let barHeight: CGFloat = isProminent ? 5 : 4
            glyphFrame = CGRect(
                x: 0,
                y: (bounds.height - glyphSize) / 2,
                width: glyphSize,
                height: glyphSize
            )

            let barX = glyphFrame.maxX + gap
            let barWidth = max(0, bounds.width - barX - gap - valueWidth)
            barFrame = CGRect(
                x: barX,
                y: (bounds.height - barHeight) / 2,
                width: barWidth,
                height: barHeight
            )
            fillWidth = row.fraction > 0 ? max(barHeight, barWidth * row.fraction) : 0
            valueLineHeight = Styles.value(
                color: .labelColor,
                isProminent: isProminent
            ).lineHeight
        }
    }
}

extension HostedBatteryAccessoryRowView {
    func layoutGlyph(using layout: RowLayout) {
        setFrameIfNeeded(glyphView, frame: layout.glyphFrame.insetBy(dx: 4, dy: 4))
        glyphBackgroundLayer.frame = layout.glyphFrame
        glyphBackgroundLayer.cornerRadius = layout.isProminent ? 9 : 8
        glyphBackgroundLayer.backgroundColor = NSColor.labelColor
            .withAlphaComponent(layout.isProminent ? 0.07 : 0.055)
            .cgColor

        glyphBorderLayer.frame = layout.glyphFrame
        glyphBorderLayer.cornerRadius = glyphBackgroundLayer.cornerRadius
        glyphBorderLayer.borderWidth = 1
        glyphBorderLayer.borderColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        glyphBorderLayer.backgroundColor = nil
    }

    func layoutProgress(using layout: RowLayout) {
        setFrameIfNeeded(barTrackLayer, frame: layout.barFrame)
        barTrackLayer.cornerRadius = layout.barFrame.height / 2
        barTrackLayer.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.11).cgColor

        setFrameIfNeeded(
            barFillLayer,
            frame: CGRect(
                x: layout.barFrame.minX,
                y: layout.barFrame.minY,
                width: layout.fillWidth,
                height: layout.barFrame.height
            )
        )
        barFillLayer.cornerRadius = layout.barFrame.height / 2
    }

    func layoutValue(using layout: RowLayout) {
        setFrameIfNeeded(
            valueLayer,
            frame: CGRect(
                x: layout.bounds.maxX - layout.valueWidth,
                y: (layout.bounds.height - layout.valueLineHeight) / 2,
                width: layout.valueWidth,
                height: layout.valueLineHeight
            )
        )
    }

    func layoutBadge(using layout: RowLayout) {
        guard !badgeLayer.isHidden else { return }
        setFrameIfNeeded(
            badgeLayer,
            frame: CGRect(
                x: layout.glyphFrame.maxX - 8,
                y: layout.glyphFrame.maxY - 8,
                width: 12,
                height: Styles.badge.lineHeight
            )
        )
    }
}
