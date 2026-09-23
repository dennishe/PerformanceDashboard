import AppKit

extension HostedNetworkTileContentView {
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
            style: SparklineStyle(color: color, displayScale: displayScale)
        )
        uploadSparklineView.update(
            history: outTileModel.history,
            style: SparklineStyle(
                color: .upload(dark: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua),
                displayScale: displayScale,
                showFill: false
            )
        )
    }
}
