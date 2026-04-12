import SwiftUI

@MainActor
protocol MetricTileModelProviding: AnyObject {
    var tileModel: MetricTileModel { get }
}

extension MonitorViewModelBase: MetricTileModelProviding {}

@MainActor
struct ObservedMetricTileButton<ViewModel: MetricTileModelProviding>: View {
    let viewModel: ViewModel
    let action: @MainActor () -> Void

    var body: some View {
        MetricTileView(model: viewModel.tileModel)
            .equatable()
            .tileButton(action: action)
    }
}

@MainActor
struct ObservedNetworkTileButton: View {
    let viewModel: NetworkViewModel
    let action: @MainActor () -> Void

    var body: some View {
        NetworkTileView(models: NetworkTileModels(viewModel: viewModel))
            .equatable()
            .tileButton(action: action)
    }
}

@MainActor
struct ObservedBatteryTileButton: View {
    let viewModel: BatteryViewModel
    let action: @MainActor () -> Void

    var body: some View {
        BatteryTileView(model: BatteryTileModel(viewModel: viewModel))
            .equatable()
            .tileButton(action: action)
    }
}
