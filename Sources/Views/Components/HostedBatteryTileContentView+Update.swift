import AppKit

extension HostedBatteryTileContentView {
    func applyHeaderText(displayScale: CGFloat, thresholdColor: NSColor) {
        updateTileSymbolView(
            iconView,
            systemName: "battery.100",
            tintColor: .secondaryLabelColor,
            tintKey: .secondaryLabel,
            state: &iconState
        )
        updateTileTextLayer(
            titleLayer,
            text: "BATTERY",
            style: Styles.headerTitle,
            displayScale: displayScale,
            state: &titleState
        )

        let headerValue = model?.headerValueText ?? ""
        headerValueLayer.isHidden = headerValue.isEmpty

        guard !headerValue.isEmpty else { return }
        updateTileTextLayer(
            headerValueLayer,
            text: headerValue,
            style: Styles.headerValue(color: thresholdColor),
            displayScale: displayScale,
            state: &headerValueState
        )
    }

    func applyPrimaryContent(model: BatteryTileModel, displayScale: CGFloat, thresholdColor: NSColor) {
        guard model.isBatteryPresent else {
            primaryLabelLayer.isHidden = true
            primaryValueLayer.isHidden = true
            primaryStatusLayer.isHidden = true
            primaryMeterView.isHidden = true
            return
        }

        primaryLabelLayer.isHidden = false
        primaryValueLayer.isHidden = false
        primaryMeterView.isHidden = false

        updateTileTextLayer(
            primaryLabelLayer,
            text: "THIS MAC",
            style: Styles.primaryLabel,
            displayScale: displayScale,
            state: &primaryLabelState
        )
        updateTileTextLayer(
            primaryValueLayer,
            text: model.chargeLabel,
            style: Styles.primaryValue(color: thresholdColor),
            displayScale: displayScale,
            state: &primaryValueState
        )

        let statusText = model.statusLabel ?? ""
        primaryStatusLayer.isHidden = statusText.isEmpty
        if !statusText.isEmpty {
            updateTileTextLayer(
                primaryStatusLayer,
                text: statusText,
                style: Styles.primaryStatus,
                displayScale: displayScale,
                state: &primaryStatusState
            )
        }

        primaryMeterView.update(
            fraction: model.chargeFraction,
            thresholdLevel: model.thresholdLevel
        )
    }

    func applyAccessoryContent(model: BatteryTileModel, displayScale: CGFloat) {
        updateTileTextLayer(
            accessoryTitleLayer,
            text: model.accessorySectionTitle,
            style: Styles.accessoryTitle,
            displayScale: displayScale,
            state: &accessoryTitleState
        )

        let accessoryCount = model.accessoryCountText ?? ""
        accessoryCountLayer.isHidden = accessoryCount.isEmpty
        if !accessoryCount.isEmpty {
            updateTileTextLayer(
                accessoryCountLayer,
                text: accessoryCount,
                style: Styles.accessoryCount,
                displayScale: displayScale,
                state: &accessoryCountState
            )
        }

        let emptyMessage = model.accessoryEmptyMessage ?? ""
        emptyMessageLayer.isHidden = emptyMessage.isEmpty
        if !emptyMessage.isEmpty {
            updateTileTextLayer(
                emptyMessageLayer,
                text: emptyMessage,
                style: Styles.emptyMessage(isProminent: !model.isBatteryPresent),
                displayScale: displayScale,
                state: &emptyMessageState
            )
        }
    }

    func applyAccessoryRows(model: BatteryTileModel, displayScale: CGFloat) {
        for (index, rowView) in rowViews.enumerated() {
            guard index < model.accessoryRows.count else {
                rowView.isHidden = true
                continue
            }

            rowView.isHidden = false
            rowView.update(
                row: model.accessoryRows[index],
                isProminent: !model.isBatteryPresent,
                displayScale: displayScale
            )
        }
    }
}
