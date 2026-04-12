import AppKit

@MainActor
final class HostedBatteryTileContentView: NSView {
    let iconView = NSImageView()
    let titleLayer = CATextLayer()
    let headerValueLayer = CATextLayer()
    let primaryLabelLayer = CATextLayer()
    let primaryValueLayer = CATextLayer()
    let primaryStatusLayer = CATextLayer()
    let accessoryTitleLayer = CATextLayer()
    let accessoryCountLayer = CATextLayer()
    let emptyMessageLayer = CATextLayer()
    let accessoryContainerLayer = CALayer()
    let accessoryContainerBorderLayer = CALayer()
    let primaryMeterView = HostedBatteryPrimaryMeterView()
    let rowViews = (0..<BatteryViewModel.maxVisibleTileGaugeRows).map { _ in
        HostedBatteryAccessoryRowView()
    }

    var model: BatteryTileModel?
    var currentScale: CGFloat = 0
    var iconState: TileSymbolState?
    var titleState: TileTextLayerState?
    var headerValueState: TileTextLayerState?
    var primaryLabelState: TileTextLayerState?
    var primaryValueState: TileTextLayerState?
    var primaryStatusState: TileTextLayerState?
    var accessoryTitleState: TileTextLayerState?
    var accessoryCountState: TileTextLayerState?
    var emptyMessageState: TileTextLayerState?
    var lastLaidOutBounds: CGRect = .null

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()

        [
            titleLayer,
            headerValueLayer,
            primaryLabelLayer,
            primaryValueLayer,
            primaryStatusLayer,
            accessoryTitleLayer,
            accessoryCountLayer,
            emptyMessageLayer
        ].forEach(configureTileTextLayer)
        headerValueLayer.alignmentMode = .right
        accessoryCountLayer.alignmentMode = .right

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        addSubview(primaryMeterView)
        rowViews.forEach(addSubview)

        accessoryContainerLayer.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull()]
        accessoryContainerBorderLayer.actions = ["bounds": NSNull(), "position": NSNull(), "borderColor": NSNull()]

        layer?.addSublayer(accessoryContainerLayer)
        layer?.addSublayer(accessoryContainerBorderLayer)
        layer?.addSublayer(titleLayer)
        layer?.addSublayer(headerValueLayer)
        layer?.addSublayer(primaryLabelLayer)
        layer?.addSublayer(primaryValueLayer)
        layer?.addSublayer(primaryStatusLayer)
        layer?.addSublayer(accessoryTitleLayer)
        layer?.addSublayer(accessoryCountLayer)
        layer?.addSublayer(emptyMessageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: MetricTileLayoutMetrics.contentHeight)
    }

    override func layout() {
        super.layout()
        let integralBounds = bounds.integral
        guard integralBounds != lastLaidOutBounds else { return }
        lastLaidOutBounds = integralBounds
        layoutTileSubviews()
    }

    func update(model: BatteryTileModel, displayScale: CGFloat) {
        guard self.model != model || currentScale != displayScale else { return }

        self.model = model
        currentScale = displayScale
        lastLaidOutBounds = .null

        let thresholdColor = LayerColorComponents.threshold(model.thresholdLevel).nsColor()

        applyHeaderText(displayScale: displayScale, thresholdColor: thresholdColor)
        applyPrimaryContent(model: model, displayScale: displayScale, thresholdColor: thresholdColor)
        applyAccessoryContent(model: model, displayScale: displayScale)
        applyAccessoryRows(model: model, displayScale: displayScale)

        needsLayout = true
    }
}
