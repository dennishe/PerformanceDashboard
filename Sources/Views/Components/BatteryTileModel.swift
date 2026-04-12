import Foundation

struct BatteryTileModel: Equatable {
    let isBatteryPresent: Bool
    let chargeLabel: String
    let chargeFraction: Double
    let thresholdLevel: ThresholdLevel
    let statusLabel: String?
    let headerValueText: String?
    let accessorySectionTitle: String
    let accessoryCountText: String?
    let accessoryRows: [BatteryTileGaugeRow]
    let accessoryEmptyMessage: String?

    @MainActor
    init(viewModel: BatteryViewModel) {
        let snapshot = viewModel.snapshot
        let visibleRows = viewModel.visibleTileGaugeRows
        let accessoryRows = snapshot.isPresent ? Array(visibleRows.dropFirst()) : visibleRows
        let connectedAccessoryCount = viewModel.connectedDeviceBatteries.count

        self.isBatteryPresent = snapshot.isPresent
        self.chargeLabel = viewModel.chargeLabel
        self.chargeFraction = viewModel.gaugeValue ?? 0
        self.thresholdLevel = viewModel.thresholdLevel
        self.statusLabel = viewModel.statusLabel
        self.headerValueText = snapshot.isPresent ? viewModel.chargeLabel : nil
        self.accessorySectionTitle = snapshot.isPresent ? "ACCESSORIES" : "ACCESSORY POWER"
        self.accessoryCountText = connectedAccessoryCount > 0 ? "\(connectedAccessoryCount) connected" : nil
        self.accessoryRows = accessoryRows
        self.accessoryEmptyMessage = accessoryRows.isEmpty
            ? Self.makeEmptyMessage(viewModel: viewModel)
            : nil
    }
}

private extension BatteryTileModel {
    @MainActor
    static func makeEmptyMessage(viewModel: BatteryViewModel) -> String {
        if viewModel.isLoadingConnectedDeviceBatteries {
            return "Loading batteries..."
        }

        return viewModel.snapshot.isPresent
            ? "No connected accessory batteries"
            : "No accessory batteries available"
    }
}
