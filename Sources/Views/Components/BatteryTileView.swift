import SwiftUI

struct BatteryTileView: View, Equatable {
    let model: BatteryTileModel

    var body: some View {
        HostedBatteryTileContentRepresentable(model: model)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .tileCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery")
    }
}
