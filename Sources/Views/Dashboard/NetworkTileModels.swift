import Foundation

struct NetworkTileModels: Equatable {
    let tileModel: MetricTileModel
    let inTileModel: MetricTileModel
    let outTileModel: MetricTileModel

    @MainActor
    init(viewModel: NetworkViewModel) {
        self.tileModel = viewModel.tileModel
        self.inTileModel = viewModel.inTileModel
        self.outTileModel = viewModel.outTileModel
    }
}
