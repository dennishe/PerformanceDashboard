import Testing
@testable import PerformanceDashboard

@MainActor
struct FanViewModelTests {

    @Test func fans_updatesFromStream() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 1200, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.fans.count == 1)
        #expect(viewModel.fans[0].current == 1200)
    }

    @Test func gaugeValue_isNil_whenNoFans() {
        let monitor = MockFanMonitor()
        monitor.snapshots = []
        let viewModel = FanViewModel(monitor: monitor)
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_returnsFraction_forSingleFan() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]  // 0.5
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func gaugeValue_returnsMaxFraction_forMultipleFans() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 3000, max: 6000),  // 0.5
            FanReading(current: 4800, max: 6000)   // 0.8
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0.8)
    }

    @Test func primaryLabel_showsNoFans_whenEmpty() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.primaryLabel == "No fans")
    }

    @Test func primaryLabel_showsFastestRPM() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 1200, max: 6000),
            FanReading(current: 2400, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.primaryLabel == "2400 RPM")
    }

    @Test func subtitle_isNil_whenNoFans() {
        let monitor = MockFanMonitor()
        monitor.snapshots = []
        let viewModel = FanViewModel(monitor: monitor)
        #expect(viewModel.subtitle == nil)
    }

    @Test func subtitle_showsSingleFanDetail() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 1200, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.subtitle == "F0: 1200 / 6000")
    }

    @Test func subtitle_showsMultipleFansJoined() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [
            FanReading(current: 1200, max: 6000),
            FanReading(current: 2400, max: 6000)
        ])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.subtitle == "F0: 1200 / 6000 · F1: 2400 / 6000")
    }

    @Test func thresholdLevel_inactive_whenNoFans() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func thresholdLevel_normal_forLowFanSpeed() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]  // 0.5 < 0.7
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forHighFanSpeed() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 5700, max: 6000)])]  // 0.95 > 0.9
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsFanFraction() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 3000, max: 6000)])]  // 0.5
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(abs(viewModel.history[0] - 0.5) < 0.001)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockFanMonitor()
        monitor.snapshots = [FanSnapshot(fans: [FanReading(current: 1200, max: 6000)])]
        let viewModel = FanViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let countBeforeStop = viewModel.fans.count
        viewModel.stop()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.fans.count == countBeforeStop)
    }
}
