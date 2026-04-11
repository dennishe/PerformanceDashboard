import Testing
@testable import PerformanceDashboard

@MainActor
struct BatteryViewModelTests {

    @Test func snapshot_updatesFromStream() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.78, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: 42, healthFraction: 0.97
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.snapshot.chargeFraction == 0.78)
    }

    @Test func gaugeValue_returnsFraction_whenBatteryPresent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.6, isCharging: false,
            onAC: false, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 0.6)
    }

    @Test func gaugeValue_isNil_whenNoBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func chargeLabel_formatsPercent_whenBatteryPresent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.78, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.chargeLabel == "78.0%")
    }

    @Test func chargeLabel_showsACPower_whenNoBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.chargeLabel == "AC Power")
    }

    @Test func statusLabel_isNil_whenNoBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.statusLabel == nil)
    }

    @Test func statusLabel_showsCharging_whenCharging() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.5, isCharging: true,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.statusLabel == "Charging")
    }

    @Test func statusLabel_showsCharged_whenOnACNotCharging() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 1.0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.statusLabel == "Charged")
    }

    @Test func statusLabel_showsTimeToEmpty_withHoursAndMinutes() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.4, isCharging: false,
            onAC: false, timeToEmptyMinutes: 90, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.statusLabel == "1h 30m left")
    }

    @Test func statusLabel_showsMinutesOnly_whenUnderOneHour() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.2, isCharging: false,
            onAC: false, timeToEmptyMinutes: 45, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.statusLabel == "45m left")
    }

    @Test func statusLabel_showsOnBattery_whenNoTimeToEmpty() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.5, isCharging: false,
            onAC: false, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.statusLabel == "On battery")
    }

    @Test func cycleLabel_showsCycles_whenPresent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.8, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: 128, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.cycleLabel == "128 cycles")
    }

    @Test func cycleLabel_isNil_whenCycleCountIsNil() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.8, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.cycleLabel == nil)
    }

    @Test func cycleLabel_showsZero_whenZeroCycles() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.8, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: 0, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.cycleLabel == "0 cycles")
    }

    @Test func thresholdLevel_inactive_whenNoBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func detailModel_emptyStats_whenNoBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Connected devices")
        #expect(viewModel.detailModel.stats[0].value == "None reported")
    }
}
