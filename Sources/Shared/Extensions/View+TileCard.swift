import SwiftUI

extension View {
    func tileCard() -> some View {
        background {
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .fill(Color.tileSurface)
                .shadow(
                    color: .black.opacity(DashboardDesign.Opacity.tileChrome),
                    radius: 6,
                    x: 0,
                    y: 2
                )
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .strokeBorder(
                    Color.primary.opacity(DashboardDesign.Opacity.tileChrome),
                    lineWidth: 1
                )
        }
    }
}
