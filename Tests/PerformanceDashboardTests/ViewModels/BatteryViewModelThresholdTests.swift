import Testing
@testable import PerformanceDashboard

@MainActor
struct BatteryViewModelThresholdTests {

    @Test func thresholdLevel_inactive_whenNoBattery() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func thresholdLevel_normal_aboveTwentyPercent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.8, isCharging: false,
            onAC: false, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_warning_betweenTenAndTwentyPercent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.15, isCharging: false,
            onAC: false, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .warning)
    }

    @Test func thresholdLevel_critical_belowTenPercent() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.05, isCharging: false,
            onAC: false, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsChargeFraction() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.75, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(viewModel.history[0] == 0.75)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<BatterySnapshot>()
        monitor.snapshots = [BatterySnapshot(
            isPresent: true, chargeFraction: 0.78, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )]
        let viewModel = BatteryViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let chargeBeforeStop = viewModel.snapshot.chargeFraction
        viewModel.stop()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.snapshot.chargeFraction == chargeBeforeStop)
    }
}
