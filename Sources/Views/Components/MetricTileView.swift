import SwiftUI

/// A reusable metric tile: icon + title header, ring gauge, value, subtitle, and sparkline.
struct MetricTileView: View {
    let title: String
    let value: String
    let gaugeValue: Double?
    let history: [Double]
    let thresholdLevel: ThresholdLevel
    var subtitle: String?
    var systemImage: String = "chart.xyaxis.line"

    private var color: Color { .threshold(thresholdLevel) }
    /// Secondary/grey when the metric is unavailable (nil gaugeValue).
    private var gaugeColor: Color { gaugeValue == nil ? .secondary : color }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            tileHeader
            valueText
            subtitleText
            SparklineView(history: history, color: gaugeColor)
                .frame(height: 38)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.tileSurface)
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - Sub-views

    private var tileHeader: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(gaugeColor)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer(minLength: 0)
            RingGaugeView(value: gaugeValue ?? 0, color: gaugeColor)
                .frame(width: 34, height: 34)
        }
    }

    private var valueText: some View {
        Text(value)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(gaugeColor)
            .accessibilityLabel(title)
            .accessibilityValue(value)
    }

    @ViewBuilder private var subtitleText: some View {
        if let subtitle {
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

#Preview {
    MetricTileView(
        title: "CPU",
        value: "42.3%",
        gaugeValue: 0.423,
        history: (0..<60).map { _ in Double.random(in: 0...1) },
        thresholdLevel: .normal,
        subtitle: "8 cores",
        systemImage: "cpu"
    )
    .frame(width: 220)
    .padding()
}
