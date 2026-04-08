import Testing
@testable import PerformanceDashboard

@MainActor
struct CPUViewModelTests {
    @Test func cpuUsage_updatesFromStream() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.75)]
        let viewModel = CPUViewModel(monitor: monitor)

        viewModel.start()
        // Allow the async stream to emit
        await waitForAsyncUpdates()

        #expect(viewModel.usage == 0.75)
    }

    @Test func cpuUsageLabel_formatsToOneDecimal() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.5)]
        let viewModel = CPUViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usageLabel == "50.0%")
    }

    @Test func cpuHistory_appendsAndCapsAtHistorySamples() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = (0..<70).map { _ in CPUSnapshot(usage: 0.1) }
        let viewModel = CPUViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates(cycles: 2)

        #expect(viewModel.history.count <= Constants.historySamples)
    }

    @Test func cpuThreshold_normal_belowSixty() {
        #expect(CPUThreshold().level(for: 0.5) == .normal)
    }

    @Test func cpuThreshold_warning_betweenSixtyAndEightyFive() {
        #expect(CPUThreshold().level(for: 0.7) == .warning)
    }

    @Test func cpuThreshold_critical_aboveEightyFive() {
        #expect(CPUThreshold().level(for: 0.9) == .critical)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.3)]
        let viewModel = CPUViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()
        let usageBeforeStop = viewModel.usage
        viewModel.stop()

        // Further ticks should not change state after stop.
        await waitForAsyncUpdates()
        #expect(viewModel.usage == usageBeforeStop)
    }
}
