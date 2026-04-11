import Testing
@testable import PerformanceDashboard

@MainActor
struct BatteryViewModelDetailTests {
    @Test func detailModel_includesCharge_whenBatteryPresent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.75, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()

        let chargeValue = viewModel.detailModel.stats.first { $0.label == "Charge" }?.value
        #expect(chargeValue == "75.0%")
    }

    @Test func statusLabel_showsExactHours_whenMinutesZero() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.6, isCharging: false,
            onAC: false, timeToEmptyMinutes: 120, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.statusLabel == "2h 0m left")
    }
}
