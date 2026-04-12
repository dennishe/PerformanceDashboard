import AppKit

@MainActor
final class HostedBatteryAccessoryRowView: NSView {
    let glyphView = NSImageView()
    let glyphBackgroundLayer = CALayer()
    let glyphBorderLayer = CALayer()
    let badgeLayer = CATextLayer()
    let barTrackLayer = CALayer()
    let barFillLayer = CALayer()
    let valueLayer = CATextLayer()

    var row: BatteryTileGaugeRow?
    var isProminent = false
    var currentScale: CGFloat = 0
    var symbolState: TileSymbolState?
    var badgeState: TileTextLayerState?
    var valueState: TileTextLayerState?
    var lastLaidOutBounds: CGRect = .null

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()

        glyphView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(glyphView)

        configureTileTextLayer(badgeLayer)
        configureTileTextLayer(valueLayer)
        valueLayer.alignmentMode = .right

        [glyphBackgroundLayer, glyphBorderLayer, barTrackLayer, barFillLayer].forEach {
            $0.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull()]
        }

        layer?.addSublayer(glyphBackgroundLayer)
        layer?.addSublayer(glyphBorderLayer)
        layer?.addSublayer(badgeLayer)
        layer?.addSublayer(barTrackLayer)
        layer?.addSublayer(barFillLayer)
        layer?.addSublayer(valueLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let integralBounds = bounds.integral
        guard integralBounds != lastLaidOutBounds else { return }
        lastLaidOutBounds = integralBounds
        layoutRowSubviews()
    }

    func update(row: BatteryTileGaugeRow, isProminent: Bool, displayScale: CGFloat) {
        guard self.row != row
            || self.isProminent != isProminent
            || currentScale != displayScale else { return }

        self.row = row
        self.isProminent = isProminent
        currentScale = displayScale
        lastLaidOutBounds = .null
        toolTip = row.name

        let kind = BatteryAccessoryKind.infer(from: row.name)
        let badge = BatteryAccessoryKind.componentBadge(for: row.name) ?? ""
        let valueColor = LayerColorComponents.threshold(row.thresholdLevel).nsColor()

        updateTileSymbolView(
            glyphView,
            systemName: kind.symbolName,
            tintColor: .secondaryLabelColor,
            tintKey: .secondaryLabel,
            state: &symbolState
        )
        updateTileTextLayer(
            valueLayer,
            text: row.valueText,
            style: Styles.value(color: valueColor, isProminent: isProminent),
            displayScale: displayScale,
            state: &valueState
        )

        badgeLayer.isHidden = badge.isEmpty
        if !badge.isEmpty {
            updateTileTextLayer(
                badgeLayer,
                text: badge,
                style: Styles.badge,
                displayScale: displayScale,
                state: &badgeState
            )
        }

        barFillLayer.backgroundColor = valueColor.cgColor
        needsLayout = true
    }
}

private extension HostedBatteryAccessoryRowView {
    func layoutRowSubviews() {
        guard let row else { return }

        let layout = RowLayout(bounds: bounds.integral, row: row, isProminent: isProminent)

        layoutGlyph(using: layout)
        layoutProgress(using: layout)
        layoutValue(using: layout)
        layoutBadge(using: layout)
    }
}
