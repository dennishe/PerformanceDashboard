import SwiftUI

struct BatteryTileView: View, Equatable {
    let model: BatteryTileModel

    var body: some View {
        HostedBatteryTileContentRepresentable(model: model)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(.horizontal, MetricTileLayoutMetrics.padding)
        .padding(.top, MetricTileLayoutMetrics.topPadding)
        .padding(.bottom, MetricTileLayoutMetrics.padding)
        .tileCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery")
    }
}
