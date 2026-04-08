import SwiftUI

/// A reusable metric tile: icon + title header, ring gauge, value, subtitle, and sparkline.
struct MetricTileView: View {
    let model: MetricTileModel

    private var color: Color { .threshold(model.thresholdLevel) }
    /// Secondary/grey when the metric is unavailable (nil gaugeValue).
    private var gaugeColor: Color { model.gaugeValue == nil ? .secondary : color }
    private var layerColor: LayerColorComponents {
        model.gaugeValue == nil ? .inactive : .threshold(model.thresholdLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.xSmall) {
            tileHeader
            valueText
            subtitleText
            Spacer(minLength: 0)
            SparklineView(
                history: model.history,
                color: layerColor,
                accessibilityLabel: model.sparklineAccessibilityLabel,
                accessibilityValue: model.value
            )
                .frame(height: SparklineGeometry.displayHeight)
        }
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .tileCard()
    }

    // MARK: - Sub-views

    private var tileHeader: some View {
        HStack(alignment: .center, spacing: DashboardDesign.Spacing.small) {
            Image(systemName: model.systemImage)
                .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .semibold))
                .foregroundStyle(gaugeColor)
            Text(verbatim: model.displayTitle)
                .font(.system(size: DashboardDesign.FontSize.tileCaption, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer(minLength: 0)
            RingGaugeView(
                value: model.gaugeValue ?? 0,
                color: layerColor,
                accessibilityLabel: model.gaugeAccessibilityLabel,
                accessibilityValue: model.value
            )
                .frame(
                    width: MetricTileLayoutMetrics.ringGaugeSize,
                    height: MetricTileLayoutMetrics.ringGaugeSize
                )
        }
    }

    private var valueText: some View {
        Text(verbatim: model.value)
            .font(.system(size: DashboardDesign.FontSize.tileValue, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(gaugeColor)
            .contentTransition(.numericText())
            .accessibilityLabel(model.accessibilityLabel)
            .accessibilityValue(model.value)
    }

    @ViewBuilder private var subtitleText: some View {
        if let reason = model.unavailableReason, model.gaugeValue == nil {
            Label(reason, systemImage: "exclamationmark.circle")
                .font(.system(size: DashboardDesign.FontSize.tileCaption))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(.system(size: DashboardDesign.FontSize.tileSubtitle))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

#Preview {
    MetricTileView(model: MetricTileModel(
        title: "CPU",
        value: "42.3%",
        gaugeValue: 0.423,
        history: (0..<60).map { _ in Double.random(in: 0...1) },
        thresholdLevel: .normal,
        subtitle: "8 cores",
        systemImage: "cpu"
    ))
    .frame(width: 220)
    .padding()
}
