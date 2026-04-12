import AppKit
import SwiftUI

@MainActor
final class HostedNetworkTileContentView: NSView {
    let iconView = NSImageView()
    let titleLayer = CATextLayer()
    let downArrowLayer = CATextLayer()
    let downValueLayer = CATextLayer()
    let upArrowLayer = CATextLayer()
    let upValueLayer = CATextLayer()
    let downloadSparklineView = SparklineHostingView()
    let uploadSparklineView = SparklineHostingView()
    let ringGauge = makeRingGaugePlatformComponent()
    private let titleTextStyle = PreparedTileTextStyle(
        style: HostedNetworkTileStyles.title,
        tintKey: .secondaryLabel
    )
    private let downloadArrowTextStyle = PreparedTileTextStyle(
        style: HostedNetworkTileStyles.downloadArrow,
        tintKey: .normal
    )
    private let uploadArrowTextStyle = PreparedTileTextStyle(
        style: HostedNetworkTileStyles.uploadArrow,
        tintKey: .blue
    )
    private let bodyTextStyle = PreparedTileTextStyle(
        style: HostedNetworkTileStyles.body,
        tintKey: .label
    )

    private var currentTileModel: MetricTileModel?
    private var currentInTileModel: MetricTileModel?
    private var currentOutTileModel: MetricTileModel?
    private var currentScale: CGFloat = 0
    private var iconState: TileSymbolState?
    private var titleState: TileTextLayerState?
    private var downArrowState: TileTextLayerState?
    private var downValueState: TileTextLayerState?
    private var upArrowState: TileTextLayerState?
    private var upValueState: TileTextLayerState?
    private var lastLaidOutBounds: CGRect = .null

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()

        [titleLayer, downArrowLayer, downValueLayer, upArrowLayer, upValueLayer].forEach(configureTileTextLayer)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        addSubview(ringGauge.view)
        addSubview(downloadSparklineView)
        addSubview(uploadSparklineView)
        layer?.addSublayer(titleLayer)
        layer?.addSublayer(downArrowLayer)
        layer?.addSublayer(downValueLayer)
        layer?.addSublayer(upArrowLayer)
        layer?.addSublayer(upValueLayer)
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
        layoutSubviews()
    }

    func update(
        tileModel: MetricTileModel,
        inTileModel: MetricTileModel,
        outTileModel: MetricTileModel,
        displayScale: CGFloat
    ) {
        guard currentTileModel != tileModel
            || currentInTileModel != inTileModel
            || currentOutTileModel != outTileModel
            || currentScale != displayScale else {
            return
        }

        currentTileModel = tileModel
        currentInTileModel = inTileModel
        currentOutTileModel = outTileModel
        currentScale = displayScale

        let color = LayerColorComponents.threshold(tileModel.thresholdLevel)
        let tintColor = NSColor.secondaryLabelColor

        applyTextContent(
            tintColor: tintColor,
            inValue: inTileModel.value,
            outValue: outTileModel.value,
            displayScale: displayScale
        )
        applyChartContent(
            color: color,
            tileModel: tileModel,
            inTileModel: inTileModel,
            outTileModel: outTileModel,
            displayScale: displayScale
        )
    }
}

private extension HostedNetworkTileContentView {
    func applyTextContent(tintColor: NSColor, inValue: String, outValue: String, displayScale: CGFloat) {
        applyHeaderText(tintColor: tintColor, displayScale: displayScale)
        applyTransferText(inValue: inValue, outValue: outValue, displayScale: displayScale)
    }

    func applyChartContent(
        color: LayerColorComponents,
        tileModel: MetricTileModel,
        inTileModel: MetricTileModel,
        outTileModel: MetricTileModel,
        displayScale: CGFloat
    ) {
        ringGauge.update(
            tileModel.gaugeValue ?? 0,
            RingGaugeStyle(color: color, displayScale: displayScale, profile: tileModel.gaugeColorProfile)
        )
        downloadSparklineView.update(
            history: inTileModel.history,
            style: SparklineStyle(color: .normal, displayScale: displayScale)
        )
        uploadSparklineView.update(
            history: outTileModel.history,
            style: SparklineStyle(color: .blue, displayScale: displayScale, showFill: false)
        )
    }

    func applyHeaderText(tintColor: NSColor, displayScale: CGFloat) {
        updateTileSymbolView(
            iconView,
            systemName: "network",
            tintColor: tintColor,
            tintKey: .secondaryLabel,
            state: &iconState
        )
        updateTileTextLayer(
            titleLayer,
            text: "NETWORK",
            preparedStyle: titleTextStyle,
            displayScale: displayScale,
            state: &titleState
        )
    }

    func applyTransferText(inValue: String, outValue: String, displayScale: CGFloat) {
        updateTileTextLayer(
            downArrowLayer,
            text: "↓",
            preparedStyle: downloadArrowTextStyle,
            displayScale: displayScale,
            state: &downArrowState
        )
        updateTileTextLayer(
            downValueLayer,
            text: inValue,
            preparedStyle: bodyTextStyle,
            displayScale: displayScale,
            state: &downValueState
        )
        updateTileTextLayer(
            upArrowLayer,
            text: "↑",
            preparedStyle: uploadArrowTextStyle,
            displayScale: displayScale,
            state: &upArrowState
        )
        updateTileTextLayer(
            upValueLayer,
            text: outValue,
            preparedStyle: bodyTextStyle,
            displayScale: displayScale,
            state: &upValueState
        )
    }
}
