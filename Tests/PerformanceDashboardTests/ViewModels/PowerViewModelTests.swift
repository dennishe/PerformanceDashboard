import Testing
@testable import PerformanceDashboard

@MainActor
struct PowerViewModelTests {

    @Test func watts_updatesFromStream() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 15.5)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
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
        await waitForAsyncUpdates()
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
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 1.0)
        #expect(viewModel.watts == 50.0)
    }

    @Test func wattsLabel_formatsToOneDecimalPlace() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 12.3)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.wattsLabel == "12.3 W")
    }

    @Test func wattsLabel_showsDash_whenWattsIsNil() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: nil)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.wattsLabel == "—")
    }

    @Test func thresholdLevel_normal_forLowDraw() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 5.0)]  // 5/20 = 0.25 < 0.6
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forHighDraw() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 19.0)]  // 19/20 = 0.95 > 0.85
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsNormalizedValue() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 10.0)]  // 10/20 = 0.5
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(abs((viewModel.history.last ?? -1) - 0.5) < 0.001)
    }

    @Test func history_appendsZero_whenWattsIsNil() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: nil)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(viewModel.history.last == 0)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 12.5)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        let wattsBeforeStop = viewModel.watts
        viewModel.stop()
        await waitForAsyncUpdates()
        #expect(viewModel.watts == wattsBeforeStop)
    }

    // MARK: - New coverage tests

    @Test func gaugeValue_clampedToOne_whenWattsExceedsAdaptiveMax() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [
            PowerSnapshot(watts: 50.0),  // grows adaptiveMax to 50
            PowerSnapshot(watts: 50.0)   // gaugeValue = 50/50 = 1.0
        ]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func gaugeValue_clampedToZero_whenWattsIsNegative() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: -5.0)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect((viewModel.gaugeValue ?? -1) >= 0)
    }

    @Test func detailModel_showsDrawStat_whenWattsPresent() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 12.3)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Draw")
        #expect(viewModel.detailModel.stats[0].value == "12.30 W")
    }

    @Test func detailModel_noStats_whenWattsNil() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: nil)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.isEmpty)
    }

    @Test func detailModel_hasCorrectMetadata() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [PowerSnapshot(watts: 10.0)]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.title == "Power")
        #expect(viewModel.detailModel.systemImage == "bolt")
    }

    @Test func adaptiveMax_doesNotDecreaseForLowerValue() async {
        let monitor = MockMonitor<PowerSnapshot>()
        monitor.snapshots = [
            PowerSnapshot(watts: 40.0),  // grows adaptiveMax to 40
            PowerSnapshot(watts: 5.0)    // adaptiveMax stays 40; gaugeValue = 5/40 = 0.125
        ]
        let viewModel = PowerViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        // gaugeValue should be 5/40 = 0.125, not 5/20 = 0.25
        #expect(viewModel.gaugeValue != nil)
        #expect((viewModel.gaugeValue ?? 1) < 0.2)
    }
}
