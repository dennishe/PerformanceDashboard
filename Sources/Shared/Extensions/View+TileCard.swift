import SwiftUI

extension View {
    func tileCard(headerDivider: Bool = true) -> some View {
        background {
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .fill(Color.tileSurface)
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .strokeBorder(
                    Color.tileBorder,
                    lineWidth: 1
                )
            if headerDivider {
                Color.tileBorder
                    .frame(height: 1)
                    .padding(.horizontal, MetricTileLayoutMetrics.padding)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: MetricTileLayoutMetrics.padding + MetricTileLayoutMetrics.ringGaugeSize + 5)
            }
        }
    }
}
