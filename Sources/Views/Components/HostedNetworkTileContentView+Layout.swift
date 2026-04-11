import AppKit

extension HostedNetworkTileContentView {
    func layoutSubviews() {
        let bounds = bounds.integral
        let row1Y = HostedNetworkTileLayout.headerHeight + DashboardDesign.Spacing.xSmall
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
        let titleStartX = HostedNetworkTileLayout.iconSize + DashboardDesign.Spacing.small
        let titleWidth = max(0, ringFrame.minX - DashboardDesign.Spacing.small - titleStartX)

        iconView.frame = CGRect(
            x: 0,
            y: (HostedNetworkTileLayout.headerHeight - HostedNetworkTileLayout.iconSize) / 2,
            width: HostedNetworkTileLayout.iconSize,
            height: HostedNetworkTileLayout.iconSize
        )
        ringGauge.view.frame = ringFrame
        titleLayer.frame = CGRect(
            x: titleStartX,
            y: (HostedNetworkTileLayout.headerHeight - HostedNetworkTileStyles.title.lineHeight) / 2,
            width: titleWidth,
            height: HostedNetworkTileStyles.title.lineHeight
        )
    }

    func layoutDirectionRows(in bounds: CGRect, row1Y: CGFloat, row2Y: CGFloat) {
        let valueWidth = max(0, bounds.width - HostedNetworkTileLayout.arrowWidth - DashboardDesign.Spacing.xSmall)
        downArrowLayer.frame = CGRect(
            x: 0,
            y: row1Y,
            width: HostedNetworkTileLayout.arrowWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        )
        downValueLayer.frame = CGRect(
            x: HostedNetworkTileLayout.arrowWidth + DashboardDesign.Spacing.xSmall,
            y: row1Y,
            width: valueWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        )
        upArrowLayer.frame = CGRect(
            x: 0,
            y: row2Y,
            width: HostedNetworkTileLayout.arrowWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        )
        upValueLayer.frame = CGRect(
            x: HostedNetworkTileLayout.arrowWidth + DashboardDesign.Spacing.xSmall,
            y: row2Y,
            width: valueWidth,
            height: HostedNetworkTileStyles.body.lineHeight
        )
    }

    func layoutSparklines(in bounds: CGRect, sparklineY: CGFloat) {
        let sparklineFrame = CGRect(
            x: 0,
            y: sparklineY,
            width: bounds.width,
            height: HostedNetworkTileLayout.sparklineHeight
        )
        downloadSparklineView.frame = sparklineFrame
        uploadSparklineView.frame = sparklineFrame
    }
}
