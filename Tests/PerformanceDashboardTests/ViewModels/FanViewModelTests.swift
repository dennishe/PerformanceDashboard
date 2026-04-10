import Testing
@testable import PerformanceDashboard

@MainActor
struct FanViewModelTests {

    @Test func fans_updatesFromStream() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 1200, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.fans.count == 1)
        #expect(viewModel.fans[0].current == 1200)
    }

    @Test func gaugeValue_isNil_whenNoFans() {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = []
        let viewModel = FanViewModel(monitor: monitor)
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_returnsFraction_forSingleFan() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]  // 0.5
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func gaugeValue_returnsMaxFraction_forMultipleFans() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 3000, max: 6000),  // 0.5
            FanReading(current: 4800, max: 6000)   // 0.8
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 0.8)
    }

    @Test func primaryLabel_showsNoFans_whenEmpty() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.primaryLabel == "No fans")
    }

    @Test func primaryLabel_showsFastestRPM() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 1200, max: 6000),
            FanReading(current: 2400, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.primaryLabel == "2400 RPM")
    }

    @Test func subtitle_isNil_whenNoFans() {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = []
        let viewModel = FanViewModel(monitor: monitor)
        #expect(viewModel.subtitle == nil)
    }

    @Test func subtitle_showsSingleFanDetail() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 1200, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.subtitle == "F0: 1200 / 6000")
    }

    @Test func subtitle_showsMultipleFansJoined() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 1200, max: 6000),
            FanReading(current: 2400, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.subtitle == "F0: 1200 / 6000 · F1: 2400 / 6000")
    }

    @Test func thresholdLevel_inactive_whenNoFans() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func thresholdLevel_normal_forLowFanSpeed() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]  // 0.5 < 0.7
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forHighFanSpeed() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 5700, max: 6000)])]  // 0.95 > 0.9
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsFanFraction() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]  // 0.5
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(abs((viewModel.history.last ?? -1) - 0.5) < 0.001)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 1200, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        let countBeforeStop = viewModel.fans.count
        viewModel.stop()
        await waitForAsyncUpdates()
        #expect(viewModel.fans.count == countBeforeStop)
    }

    // MARK: - New coverage tests

    @Test func gaugeValue_clampedToOne_whenCurrentExceedsMax() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 7000, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func gaugeValue_returnsMaxAcrossThreeFans() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 5000, max: 6000),
            FanReading(current: 4000, max: 6000),
            FanReading(current: 3000, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        let expected = 5000.0 / 6000.0
        #expect(abs((viewModel.gaugeValue ?? 0) - expected) < 0.001)
    }

    @Test func primaryLabel_selectsFastestWhenNonMonotonic() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 1500, max: 6000),
            FanReading(current: 2200, max: 6000),
            FanReading(current: 1800, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.primaryLabel == "2200 RPM")
    }

    @Test func subtitle_threeFansJoined() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 1200, max: 6000),
            FanReading(current: 2400, max: 6000),
            FanReading(current: 3600, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.subtitle == "F0: 1200 / 6000 · F1: 2400 / 6000 · F2: 3600 / 6000")
    }

    @Test func detailModel_hasFanStats() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 3000, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Fan 1")
    }

    @Test func tileModel_unavailableReason_whenFanless() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.unavailableReason == "No fans detected")
    }

    @Test func tileModel_noUnavailableReason_whenFansPresent() async {
        let monitor = MockMonitor<FanSnapshot>()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.unavailableReason == nil)
    }
}
