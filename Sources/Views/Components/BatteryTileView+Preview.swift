import SwiftUI

#Preview {
    BatteryTileView(model: BatteryTileModel(viewModel: BatteryTilePreviewFactory.makeViewModel()))
        .frame(width: 220)
        .padding()
}

@MainActor
private enum BatteryTilePreviewFactory {
    static func makeViewModel() -> BatteryViewModel {
        let viewModel = BatteryViewModel(monitor: BatteryMonitorService())
        viewModel.receive(BatterySnapshot(
            isPresent: true,
            chargeFraction: 0.82,
            isCharging: false,
            onAC: false,
            timeToEmptyMinutes: 148,
            cycleCount: 210,
            healthFraction: 0.93
        ))
        return viewModel
    }
}
