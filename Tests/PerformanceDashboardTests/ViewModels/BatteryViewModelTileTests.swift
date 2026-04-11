import Testing
@testable import PerformanceDashboard

@MainActor
struct BatteryViewModelTileTests {
    @Test func tileGaugeRows_includeHostBatteryAndConnectedDevices() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.78, isCharging: false,
            onAC: false, timeToEmptyMinutes: 110, cycleCount: nil, healthFraction: nil
        )]
        let provider = MockPeripheralBatteryProvider(batteries: [
            PeripheralBattery(name: "Magic Keyboard", percent: 63),
            PeripheralBattery(name: "Magic Mouse", percent: 84)
        ])
        let viewModel = BatteryViewModel(monitor: monitor, peripheralBatteryProvider: provider)
        viewModel.start()
        await waitForAsyncUpdates()

        await viewModel.refreshConnectedDeviceBatteries()

        #expect(viewModel.visibleTileGaugeRows.map { $0.name } == ["This Mac", "Magic Keyboard", "Magic Mouse"])
        #expect(viewModel.visibleTileGaugeRows.map { $0.valueText } == ["78%", "63%", "84%"])
        #expect(viewModel.tileSubtitle == "1h 50m left · 2 accessories")
    }

    @Test func tileGaugeRows_limitVisibleRowsAndExposeOverflow() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.55, isCharging: false,
            onAC: false, timeToEmptyMinutes: 75, cycleCount: nil, healthFraction: nil
        )]
        let provider = MockPeripheralBatteryProvider(batteries: [
            PeripheralBattery(name: "Magic Keyboard", percent: 63),
            PeripheralBattery(name: "Magic Mouse", percent: 84),
            PeripheralBattery(name: "Trackpad", percent: 77),
            PeripheralBattery(name: "AirPods", percent: 42)
        ])
        let viewModel = BatteryViewModel(monitor: monitor, peripheralBatteryProvider: provider)
        viewModel.start()
        await waitForAsyncUpdates()

        await viewModel.refreshConnectedDeviceBatteries()

        #expect(viewModel.visibleTileGaugeRows.count == 4)
        #expect(viewModel.hiddenTileGaugeRowCount == 1)
    }

    @Test func startPeripheralBatteryRefreshLoop_refreshesImmediately() async {
        let monitor = MockMonitor<BatterySnapshot>()
        let provider = MockPeripheralBatteryProvider(batteries: [
            PeripheralBattery(name: "Magic Mouse", percent: 84)
        ])
        let viewModel = BatteryViewModel(
            monitor: monitor,
            peripheralBatteryProvider: provider,
            peripheralRefreshInterval: .seconds(3_600)
        )

        viewModel.startPeripheralBatteryRefreshLoop()
        await waitForAsyncUpdates(cycles: 2)
        viewModel.stopPeripheralBatteryRefreshLoop()

        #expect(await provider.recordedCallCount() == 1)
        #expect(
            viewModel.connectedDeviceBatteries
                == [PeripheralBattery(name: "Magic Mouse", percent: 84)]
        )
    }

    @Test func accessoryKind_infersCommonDeviceTypesFromNames() {
        #expect(BatteryAccessoryKind.infer(from: "Magic Keyboard") == .keyboard)
        #expect(BatteryAccessoryKind.infer(from: "Dennis - Magic Trackpad") == .pointingDevice)
        #expect(BatteryAccessoryKind.infer(from: "AirPods Max") == .headphones)
    }

    @Test func accessoryKind_componentBadge_detectsSplitBatteryNames() {
        #expect(BatteryAccessoryKind.componentBadge(for: "AirPods Pro (Left)") == "L")
        #expect(BatteryAccessoryKind.componentBadge(for: "AirPods Pro (Right)") == "R")
        #expect(BatteryAccessoryKind.componentBadge(for: "AirPods Pro (Case)") == "C")
        #expect(BatteryAccessoryKind.componentBadge(for: "Magic Keyboard") == nil)
    }
}
