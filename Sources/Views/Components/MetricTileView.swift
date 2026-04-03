import SwiftUI

/// A reusable metric tile showing a title, current value, ring gauge, and sparkline.
struct MetricTileView: View {
    let title: String
    let value: String
    let gaugeValue: Double?
    let history: [Double]
    let thresholdLevel: ThresholdLevel
    var subtitle: String?

    private var color: Color { .threshold(thresholdLevel) }
    /// Secondary/grey when the metric is unavailable (nil gaugeValue).
    private var gaugeColor: Color { gaugeValue == nil ? .secondary : color }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .accessibilityLabel(title)
                .accessibilityValue(value)

            Text(subtitle ?? "")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            SparklineView(history: history, color: gaugeColor)
                .frame(height: 40)
        }
        .padding(12)
        .overlay(alignment: .topTrailing) {
            RingGaugeView(value: gaugeValue ?? 0, color: gaugeColor)
                .frame(width: 44, height: 44)
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tileSurface)
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    MetricTileView(
        title: "CPU",
        value: "42.3%",
        gaugeValue: 0.423,
        history: (0..<60).map { _ in Double.random(in: 0...1) },
        thresholdLevel: .normal,
        subtitle: "8 cores"
    )
    .frame(width: 220)
    .padding()
}
