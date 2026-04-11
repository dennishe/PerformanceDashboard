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

    private var currentModel: MetricTileModel?
    private var currentScale: CGFloat = 0
    private var iconState: TileSymbolState?
    private var titleState: TileTextLayerState?
    private var valueState: TileTextLayerState?
    private var subtitleState: TileTextLayerState?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()

        configureTileTextLayer(titleLayer)
        configureTileTextLayer(valueLayer)
        configureTileTextLayer(subtitleLayer)

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
        layoutSubviews()
    }

    func update(model: MetricTileModel, displayScale: CGFloat) {
        guard currentModel != model || currentScale != displayScale else { return }

        currentModel = model
        currentScale = displayScale

        let layerColor = model.gaugeValue == nil ? LayerColorComponents.inactive : .threshold(model.thresholdLevel)
        let titleColor = NSColor.secondaryLabelColor
        let valueColor = model.gaugeValue == nil ? NSColor.secondaryLabelColor : layerColor.nsColor()
        let subtitleText = subtitle(for: model)
        let valueStyle = LayerTextStyle.tileValue(color: valueColor)

        applyTextContent(
            model: model,
            titleColor: titleColor,
            valueStyle: valueStyle,
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
    enum Layout {
        static let headerHeight = MetricTileLayoutMetrics.ringGaugeSize
        static let sparklineHeight = SparklineGeometry.displayHeight
        static let iconSize: CGFloat = 14
    }

    enum Styles {
        static let title = LayerTextStyle.tileCaption()
        static let subtitle = LayerTextStyle.tileSubtitle()
        static let valueLayout = LayerTextStyle.tileValue(color: .labelColor)
    }

    func applyTextContent(
        model: MetricTileModel,
        titleColor: NSColor,
        valueStyle: LayerTextStyle,
        subtitleText: String,
        displayScale: CGFloat
    ) {
        updateTileSymbolView(iconView, systemName: model.systemImage, tintColor: titleColor, state: &iconState)
        updateTileTextLayer(
            titleLayer,
            text: model.displayTitle,
            style: Styles.title,
            displayScale: displayScale,
            state: &titleState
        )
        updateTileTextLayer(
            valueLayer,
            text: model.value,
            style: valueStyle,
            displayScale: displayScale,
            state: &valueState
        )
        updateTileTextLayer(
            subtitleLayer,
            text: subtitleText,
            style: Styles.subtitle,
            displayScale: displayScale,
            state: &subtitleState
        )
    }

    func subtitle(for model: MetricTileModel) -> String {
        if let reason = model.unavailableReason, model.gaugeValue == nil {
            return "! " + reason
        }
        return model.subtitle ?? ""
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

        iconView.frame = CGRect(
            x: 0,
            y: (headerFrame.height - Layout.iconSize) / 2,
            width: Layout.iconSize,
            height: Layout.iconSize
        )
        ringGauge.view.frame = ringFrame
        titleLayer.frame = CGRect(
            x: titleStartX,
            y: (headerFrame.height - Styles.title.lineHeight) / 2,
            width: titleWidth,
            height: Styles.title.lineHeight
        )
        valueLayer.frame = CGRect(
            x: 0,
            y: headerFrame.maxY + DashboardDesign.Spacing.xSmall,
            width: bounds.width,
            height: Styles.valueLayout.lineHeight
        )
        subtitleLayer.frame = CGRect(
            x: 0,
            y: valueLayer.frame.maxY + DashboardDesign.Spacing.xSmall,
            width: bounds.width,
            height: Styles.subtitle.lineHeight
        )
        sparklineView.frame = CGRect(x: 0, y: sparklineY, width: bounds.width, height: Layout.sparklineHeight)
    }
}

struct HostedMetricTileContentRepresentable: NSViewRepresentable, Equatable {
    let model: MetricTileModel

    func makeNSView(context: Context) -> HostedMetricTileContentView {
        HostedMetricTileContentView()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HostedMetricTileContentView,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.bounds.width, height: MetricTileLayoutMetrics.contentHeight)
    }

    func updateNSView(_ nsView: HostedMetricTileContentView, context: Context) {
        nsView.update(model: model, displayScale: context.environment.displayScale)
    }
}
