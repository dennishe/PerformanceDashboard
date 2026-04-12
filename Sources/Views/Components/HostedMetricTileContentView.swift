import AppKit
import SwiftUI

@MainActor
final class HostedMetricTileContentView: NSView {
    private let iconView = NSImageView()
    private let titleLayer = CATextLayer()
    private let valueLayer = CATextLayer()
    private let subtitleLayer = CATextLayer()
    private let sparklineView = SparklineHostingView()
    private let ringGauge = makeRingGaugePlatformComponent()
    let titleTextStyle = PreparedTileTextStyle(
        style: Styles.title,
        tintKey: .secondaryLabel
    )
    let subtitleTextStyle = PreparedTileTextStyle(
        style: Styles.subtitle,
        tintKey: .tertiaryLabel
    )
    let inactiveValueTextStyle = PreparedTileTextStyle(
        style: Styles.inactiveValue,
        tintKey: .secondaryLabel
    )
    let normalValueTextStyle = PreparedTileTextStyle(
        style: Styles.normalValue,
        tintKey: .normal
    )
    let warningValueTextStyle = PreparedTileTextStyle(
        style: Styles.warningValue,
        tintKey: .warning
    )
    let criticalValueTextStyle = PreparedTileTextStyle(
        style: Styles.criticalValue,
        tintKey: .critical
    )

    private var currentModel: MetricTileModel?
    private var currentScale: CGFloat = 0
    private var iconState: TileSymbolState?
    private var titleState: TileTextLayerState?
    private var valueState: TileTextLayerState?
    private var subtitleState: TileTextLayerState?
    private var lastLaidOutBounds: CGRect = .null

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        [titleLayer, valueLayer, subtitleLayer].forEach(configureTileTextLayer)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        addSubview(ringGauge.view)
        addSubview(sparklineView)
        layer?.addSublayer(titleLayer)
        layer?.addSublayer(valueLayer)
        layer?.addSublayer(subtitleLayer)
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

    func update(model: MetricTileModel, displayScale: CGFloat) {
        guard currentModel != model || currentScale != displayScale else { return }

        currentModel = model
        currentScale = displayScale

        let layerColor = model.gaugeValue == nil ? LayerColorComponents.inactive : .threshold(model.thresholdLevel)
        let subtitleText = subtitle(for: model)

        applyTextContent(
            model: model,
            valueTextStyle: valueTextStyle(for: model),
            subtitleText: subtitleText,
            displayScale: displayScale
        )
        subtitleLayer.isHidden = subtitleText.isEmpty

        ringGauge.update(
            model.gaugeValue ?? 0,
            RingGaugeStyle(color: layerColor, displayScale: displayScale, profile: model.gaugeColorProfile)
        )
        sparklineView.update(
            history: model.history,
            style: SparklineStyle(color: layerColor, displayScale: displayScale)
        )
    }
}

private extension HostedMetricTileContentView {
    func applyTextContent(
        model: MetricTileModel,
        valueTextStyle: PreparedTileTextStyle,
        subtitleText: String,
        displayScale: CGFloat
    ) {
        updateTileSymbolView(
            iconView,
            systemName: model.systemImage,
            tintColor: .secondaryLabelColor,
            tintKey: .secondaryLabel,
            state: &iconState
        )
        updateTileTextLayer(
            titleLayer,
            text: model.displayTitle,
            preparedStyle: titleTextStyle,
            displayScale: displayScale,
            state: &titleState
        )
        updateTileTextLayer(
            valueLayer,
            text: model.value,
            preparedStyle: valueTextStyle,
            displayScale: displayScale,
            state: &valueState
        )
        updateTileTextLayer(
            subtitleLayer,
            text: subtitleText,
            preparedStyle: subtitleTextStyle,
            displayScale: displayScale,
            state: &subtitleState
        )
    }

    func layoutSubviews() {
        let bounds = bounds.integral
        let headerFrame = CGRect(x: 0, y: 0, width: bounds.width, height: Layout.headerHeight)
        let ringFrame = CGRect(
            x: bounds.maxX - MetricTileLayoutMetrics.ringGaugeSize,
            y: 0,
            width: MetricTileLayoutMetrics.ringGaugeSize,
            height: MetricTileLayoutMetrics.ringGaugeSize
        )
        let titleStartX = Layout.iconSize + DashboardDesign.Spacing.small
        let titleWidth = max(0, ringFrame.minX - DashboardDesign.Spacing.small - titleStartX)
        let sparklineY = bounds.height - Layout.sparklineHeight

        setFrameIfNeeded(iconView, frame: CGRect(
            x: 0,
            y: (headerFrame.height - Layout.iconSize) / 2,
            width: Layout.iconSize,
            height: Layout.iconSize
        ))
        setFrameIfNeeded(ringGauge.view, frame: ringFrame)
        setFrameIfNeeded(titleLayer, frame: CGRect(
            x: titleStartX,
            y: (headerFrame.height - Styles.title.lineHeight) / 2,
            width: titleWidth,
            height: Styles.title.lineHeight
        ))
        setFrameIfNeeded(valueLayer, frame: CGRect(
            x: 0,
            y: headerFrame.maxY + DashboardDesign.Spacing.xSmall,
            width: bounds.width,
            height: Styles.valueLayout.lineHeight
        ))
        setFrameIfNeeded(subtitleLayer, frame: CGRect(
            x: 0,
            y: valueLayer.frame.maxY + DashboardDesign.Spacing.xSmall,
            width: bounds.width,
            height: Styles.subtitle.lineHeight
        ))
        setFrameIfNeeded(sparklineView, frame: CGRect(
            x: 0, y: sparklineY, width: bounds.width, height: Layout.sparklineHeight
        ))
    }
}
