import AppKit

extension HostedBatteryTileContentView {
    func layoutTileSubviews() {
        guard let model else { return }

        let bounds = bounds.integral
        layoutHeader(in: bounds)

        if model.isBatteryPresent {
            layoutPrimaryBatteryContent(in: bounds)
        } else {
            layoutAccessoryOnlyContent(in: bounds)
        }
    }

    func layoutPrimaryBatteryContent(in bounds: CGRect) {
        let meterFrame = CGRect(x: bounds.maxX - 46, y: 34, width: 40, height: 16)
        let accessoryTop: CGFloat = 72
        let accessoryFrame = CGRect(
            x: 0,
            y: accessoryTop,
            width: bounds.width,
            height: bounds.height - accessoryTop
        )
        layoutPrimaryText(in: bounds, meterFrame: meterFrame)
        layoutAccessoryContainer(frame: accessoryFrame)

        let insetFrame = accessoryFrame.insetBy(
            dx: DashboardDesign.Spacing.compact,
            dy: 8
        )
        layoutAccessoryContent(in: insetFrame, isProminent: false)
    }

    func layoutAccessoryOnlyContent(in bounds: CGRect) {
        primaryStatusLayer.isHidden = true
        accessoryContainerLayer.frame = .zero
        accessoryContainerBorderLayer.frame = .zero
        layoutAccessoryContent(
            in: CGRect(x: 0, y: 26, width: bounds.width, height: bounds.height - 26),
            isProminent: true
        )
    }

    func layoutAccessoryContent(in contentFrame: CGRect, isProminent: Bool) {
        let titleHeight = Styles.accessoryTitle.lineHeight
        let countHeight = Styles.accessoryCount.lineHeight
        let countWidth: CGFloat = 70

        layoutAccessoryHeader(
            in: contentFrame,
            titleHeight: titleHeight,
            countHeight: countHeight,
            countWidth: countWidth
        )
        layoutEmptyMessageIfNeeded(
            in: contentFrame,
            isProminent: isProminent,
            titleHeight: titleHeight
        )
        layoutVisibleRows(
            in: contentFrame,
            isProminent: isProminent,
            titleHeight: titleHeight
        )
    }
}

private extension HostedBatteryTileContentView {
    func layoutPrimaryText(in bounds: CGRect, meterFrame: CGRect) {
        let textWidth = max(0, meterFrame.minX - 8)

        setFrameIfNeeded(
            primaryLabelLayer,
            frame: CGRect(x: 0, y: 22, width: textWidth, height: Styles.primaryLabel.lineHeight)
        )
        setFrameIfNeeded(
            primaryValueLayer,
            frame: CGRect(
                x: 0,
                y: 32,
                width: textWidth,
                height: Styles.primaryValue(color: .labelColor).lineHeight
            )
        )
        setFrameIfNeeded(
            primaryStatusLayer,
            frame: CGRect(
                x: 0,
                y: 59,
                width: max(0, bounds.width - 4),
                height: Styles.primaryStatus.lineHeight
            )
        )
        setFrameIfNeeded(primaryMeterView, frame: meterFrame)
    }

    func layoutAccessoryContainer(frame: CGRect) {
        accessoryContainerLayer.frame = frame
        accessoryContainerLayer.cornerRadius = 12
        accessoryContainerLayer.backgroundColor =
            NSColor.labelColor.withAlphaComponent(0.025).cgColor

        accessoryContainerBorderLayer.frame = frame
        accessoryContainerBorderLayer.cornerRadius = 12
        accessoryContainerBorderLayer.borderWidth = 1
        accessoryContainerBorderLayer.borderColor =
            NSColor.labelColor.withAlphaComponent(0.05).cgColor
        accessoryContainerBorderLayer.backgroundColor = nil
    }

    func layoutHeader(in bounds: CGRect) {
        let iconSize: CGFloat = 14
        let titleX = iconSize + DashboardDesign.Spacing.small
        let headerValueWidth: CGFloat = 52
        let titleWidth = max(
            0,
            bounds.width - titleX - headerValueWidth - DashboardDesign.Spacing.small
        )

        setFrameIfNeeded(iconView, frame: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
        setFrameIfNeeded(
            titleLayer,
            frame: CGRect(x: titleX, y: 1, width: titleWidth, height: Styles.headerTitle.lineHeight)
        )
        setFrameIfNeeded(
            headerValueLayer,
            frame: CGRect(
                x: bounds.maxX - headerValueWidth,
                y: 0,
                width: headerValueWidth,
                height: Styles.headerValue(color: .labelColor).lineHeight
            )
        )
    }

    func layoutAccessoryHeader(
        in contentFrame: CGRect,
        titleHeight: CGFloat,
        countHeight: CGFloat,
        countWidth: CGFloat
    ) {
        setFrameIfNeeded(
            accessoryTitleLayer,
            frame: CGRect(
                x: contentFrame.minX,
                y: contentFrame.minY,
                width: max(0, contentFrame.width - countWidth),
                height: titleHeight
            )
        )
        setFrameIfNeeded(
            accessoryCountLayer,
            frame: CGRect(
                x: contentFrame.maxX - countWidth,
                y: contentFrame.minY,
                width: countWidth,
                height: countHeight
            )
        )
    }

    func layoutEmptyMessageIfNeeded(
        in contentFrame: CGRect,
        isProminent: Bool,
        titleHeight: CGFloat
    ) {
        guard !emptyMessageLayer.isHidden else { return }
        let emptyHeight = Styles.emptyMessage(isProminent: isProminent).lineHeight
        setFrameIfNeeded(
            emptyMessageLayer,
            frame: CGRect(
                x: contentFrame.minX,
                y: contentFrame.minY + titleHeight + 8,
                width: contentFrame.width,
                height: emptyHeight
            )
        )
    }

    func layoutVisibleRows(in contentFrame: CGRect, isProminent: Bool, titleHeight: CGFloat) {
        let rowTop = contentFrame.minY + titleHeight + 8
        let rowHeight: CGFloat = isProminent ? 22 : 14
        let rowSpacing: CGFloat = isProminent ? 7 : 4

        for (index, rowView) in rowViews.enumerated() where !rowView.isHidden {
            let y = rowTop + CGFloat(index) * (rowHeight + rowSpacing)
            setFrameIfNeeded(
                rowView,
                frame: CGRect(
                    x: contentFrame.minX,
                    y: y,
                    width: contentFrame.width,
                    height: rowHeight
                )
            )
        }
    }
}
