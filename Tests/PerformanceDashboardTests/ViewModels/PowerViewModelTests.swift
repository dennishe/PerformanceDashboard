import Testing
@testable import PerformanceDashboard

@MainActor
struct PowerViewModelTests {

    @Test func watts_updatesFromStream() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 15.5)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.watts == 15.5)
    }

    @Test func watts_isNilInitially() {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = []
        let viewModel = PowerViewModel(monitor: monitor)
        #expect(viewModel.watts == nil)
    }

    @Test func gaugeValue_isNil_whenWattsIsNil() {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = []
        let viewModel = PowerViewModel(monitor: monitor)
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_normalisesAgainstDefaultMax() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 10.0)]  // 10 / 20 = 0.5
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func adaptiveMax_growsWhenExceeded() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [
            PowerSnapshot(watts: 10.0),  // adaptiveMax stays 20
            PowerSnapshot(watts: 50.0)   // adaptiveMax grows to 50; gaugeValue = 50/50 = 1.0
        ]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 1.0)
        #expect(viewModel.watts == 50.0)
    }

    @Test func wattsLabel_formatsToOneDecimalPlace() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 12.3)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.wattsLabel == "12.3 W")
    }

    @Test func wattsLabel_showsDash_whenWattsIsNil() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: nil)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.wattsLabel == "—")
    }

    @Test func thresholdLevel_normal_forLowDraw() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 5.0)]  // 5/20 = 0.25 < 0.6
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forHighDraw() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 19.0)]  // 19/20 = 0.95 > 0.85
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsNormalizedValue() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 10.0)]  // 10/20 = 0.5
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(abs(viewModel.history[0] - 0.5) < 0.001)
    }

    @Test func history_appendsZero_whenWattsIsNil() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: nil)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(viewModel.history[0] == 0)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 12.5)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let wattsBeforeStop = viewModel.watts
        viewModel.stop()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.watts == wattsBeforeStop)
    }
}
