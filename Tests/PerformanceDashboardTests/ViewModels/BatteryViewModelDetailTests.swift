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

    @Test func detailModel_includesConnectedDeviceBatteries_afterRefresh() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.8, isCharging: false,
            onAC: false, timeToEmptyMinutes: 90, cycleCount: 42, healthFraction: 0.94
        )]
        let provider = MockPeripheralBatteryProvider(batteries: [
            PeripheralBattery(name: "Magic Mouse", percent: 84),
            PeripheralBattery(name: "Magic Keyboard", percent: 63)
        ])
        let viewModel = BatteryViewModel(monitor: monitor, peripheralBatteryProvider: provider)
        viewModel.start()
        await waitForAsyncUpdates()

        await viewModel.refreshConnectedDeviceBatteries()

        let deviceStats = viewModel.detailModel.stats.filter {
            $0.label == "Magic Mouse" || $0.label == "Magic Keyboard"
        }
        #expect(deviceStats.count == 2)
        #expect(deviceStats.first { $0.label == "Magic Mouse" }?.value == "84%")
        #expect(deviceStats.first { $0.label == "Magic Keyboard" }?.value == "63%")
    }

    @Test func detailModel_showsConnectedDeviceFallback_whenNoHostBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(
            monitor: monitor,
            peripheralBatteryProvider: MockPeripheralBatteryProvider(batteries: [])
        )
        viewModel.start()
        await waitForAsyncUpdates()

        await viewModel.refreshConnectedDeviceBatteries()

        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Connected devices")
        #expect(viewModel.detailModel.stats[0].value == "None reported")
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
