import SwiftUI

// MARK: - Network tile (combined ↓ / ↑ in one tile)

/// Single network tile that shows both download and upload throughput.
/// Uses `NetworkViewModel.tileModel` for the ring gauge and sparkline,
/// and overlays separate ↓/↑ labels with direction-coded colours.
struct NetworkTileView: View, Equatable {
    let models: NetworkTileModels

    var body: some View {
        HostedNetworkTileContentRepresentable(
            tileModel: models.tileModel,
            inTileModel: models.inTileModel,
            outTileModel: models.outTileModel
        )
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .tileCard()
    }
}
