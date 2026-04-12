import AppKit

extension HostedMetricTileContentView {
    enum Layout {
        static let headerHeight = MetricTileLayoutMetrics.ringGaugeSize
        static let sparklineHeight = SparklineGeometry.displayHeight
        static let iconSize: CGFloat = 14
    }

    enum Styles {
        static let title = LayerTextStyle.tileCaption()
        static let subtitle = LayerTextStyle.tileSubtitle()
        static let valueLayout = LayerTextStyle.tileValue(color: .labelColor)
        static let inactiveValue = LayerTextStyle.tileValue(color: .secondaryLabelColor)
        static let normalValue = LayerTextStyle.tileValue(color: .systemGreen)
        static let warningValue = LayerTextStyle.tileValue(color: .systemOrange)
        static let criticalValue = LayerTextStyle.tileValue(color: .systemRed)
    }

    func valueTextStyle(for model: MetricTileModel) -> PreparedTileTextStyle {
        guard model.gaugeValue != nil else { return inactiveValueTextStyle }

        switch model.thresholdLevel {
        case .normal: return normalValueTextStyle
        case .warning: return warningValueTextStyle
        case .critical: return criticalValueTextStyle
        case .inactive: return inactiveValueTextStyle
        }
    }

    func subtitle(for model: MetricTileModel) -> String {
        guard let reason = model.unavailableReason, model.gaugeValue == nil else {
            return model.subtitle ?? ""
        }
        return "! " + reason
    }
}
