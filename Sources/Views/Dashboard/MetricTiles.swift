import SwiftUI

// MARK: - Network tile (combined ↓ / ↑ in one tile)

/// Single network tile that shows both download and upload throughput.
/// Uses `NetworkViewModel.tileModel` for the ring gauge and sparkline,
/// and overlays separate ↓/↑ labels with direction-coded colours.
struct NetworkTileView: View {
    let viewModel: NetworkViewModel

    var body: some View {
        let tileModel = viewModel.tileModel
        let inTileModel = viewModel.inTileModel
        let outTileModel = viewModel.outTileModel
        HostedNetworkTileContentRepresentable(
            tileModel: tileModel,
            inTileModel: inTileModel,
            outTileModel: outTileModel
        )
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .tileCard()
    }
}
