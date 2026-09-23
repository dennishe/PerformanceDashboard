import AppKit

extension HostedNetworkTileContentView {
    func layoutSubviews() {
        let bounds = bounds.integral
        let row1Y = HostedNetworkTileLayout.headerHeight + DashboardDesign.Spacing.large + 2
        let row2Y = row1Y + HostedNetworkTileStyles.body.lineHeight + DashboardDesign.Spacing.xSmall
        let sparklineY = bounds.height - HostedNetworkTileLayout.sparklineHeight

        layoutHeader(in: bounds)
        layoutDirectionRows(in: bounds, row1Y: row1Y, row2Y: row2Y)
        layoutSparklines(in: bounds, sparklineY: sparklineY)
    }

    func layoutHeader(in bounds: CGRect) {
        let ringFrame = CGRect(
            x: bounds.maxX - MetricTileLayoutMetrics.ringGaugeSize,
            y: 0,
            width: MetricTileLayoutMetrics.ringGaugeSize,
            height: MetricTileLayoutMetrics.ringGaugeSize
        )
        setFrameIfNeeded(iconView, frame: MetricTileLayoutMetrics.iconFrame())
        setFrameIfNeeded(ringGauge.view, frame: ringFrame)
        setFrameIfNeeded(titleLayer, frame: MetricTileLayoutMetrics.titleFrame(
            width: bounds.width, trailingWidth: ringFrame.width, lineHeight: HostedNetworkTileStyles.title.lineHeight
        ))
    }

    func layoutDirectionRows(in bounds: CGRect, row1Y: CGFloat, row2Y: CGFloat) {
        let valueWidth = max(0, bounds.width - HostedNetworkTileLayout.arrowWidth - DashboardDesign.Spacing.xSmall)
        setFrameIfNeeded(downArrowLayer, frame: CGRect(
            x: 0,
            y: row1Y,
            width: HostedNetworkTileLayout.arrowWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        ))
        setFrameIfNeeded(downValueLayer, frame: CGRect(
            x: HostedNetworkTileLayout.arrowWidth + DashboardDesign.Spacing.xSmall,
            y: row1Y,
            width: valueWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        ))
        setFrameIfNeeded(upArrowLayer, frame: CGRect(
            x: 0,
            y: row2Y,
            width: HostedNetworkTileLayout.arrowWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        ))
        setFrameIfNeeded(upValueLayer, frame: CGRect(
            x: HostedNetworkTileLayout.arrowWidth + DashboardDesign.Spacing.xSmall,
            y: row2Y,
            width: valueWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        ))
    }

    func layoutSparklines(in bounds: CGRect, sparklineY: CGFloat) {
        let sparklineFrame = CGRect(
            x: 0,
            y: sparklineY,
            width: bounds.width,
            height: HostedNetworkTileLayout.sparklineHeight
        )
        setFrameIfNeeded(downloadSparklineView, frame: sparklineFrame)
        setFrameIfNeeded(uploadSparklineView, frame: sparklineFrame)
    }
}
