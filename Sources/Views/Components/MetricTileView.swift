import SwiftUI

/// A reusable metric tile: icon + title header, ring gauge, value, subtitle, and sparkline.
struct MetricTileView: View, Equatable {
    let model: MetricTileModel

    var body: some View {
        HostedMetricTileContentRepresentable(model: model)
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .tileCard()
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
