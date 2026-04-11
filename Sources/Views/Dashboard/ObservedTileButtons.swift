import SwiftUI

@MainActor
struct ObservedMetricTileButton: View {
    let modelProvider: @MainActor () -> MetricTileModel
    let action: @MainActor () -> Void

    var body: some View {
        MetricTileView(model: modelProvider())
            .equatable()
            .tileButton(action: action)
    }
}

@MainActor
struct ObservedNetworkTileButton: View {
    let viewModel: NetworkViewModel
    let action: @MainActor () -> Void

    var body: some View {
        NetworkTileView(viewModel: viewModel)
            .tileButton(action: action)
    }
}

@MainActor
struct ObservedBatteryTileButton: View {
    let viewModel: BatteryViewModel
    let action: @MainActor () -> Void

    var body: some View {
        BatteryTileView(viewModel: viewModel)
            .tileButton(action: action)
    }
}
