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
        VStack(alignment: .leading, spacing: 4) {
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
        .background {
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .fill(Color.tileSurface)
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - Sub-views

    private var tileHeader: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: model.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(gaugeColor)
            Text(verbatim: model.displayTitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer(minLength: 0)
            RingGaugeView(
                value: model.gaugeValue ?? 0,
                color: layerColor,
                accessibilityLabel: model.gaugeAccessibilityLabel,
                accessibilityValue: model.value
            )
                .frame(width: 34, height: 34)
        }
    }

    private var valueText: some View {
        Text(verbatim: model.value)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(gaugeColor)
    }

    @ViewBuilder private var subtitleText: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(.system(size: 11))
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
