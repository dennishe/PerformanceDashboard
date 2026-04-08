import Testing
@testable import PerformanceDashboard

@MainActor
struct GPUViewModelTests {
    @Test func gpuUsage_updatesFromStream() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: 0.55)]
        let viewModel = GPUViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usage == 0.55)
    }

    @Test func gpuUsageLabel_showsNAWhenNil() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: nil)]
        let viewModel = GPUViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usageLabel == "N/A")
    }

    @Test func gpuThreshold_normal_belowSixty() {
        #expect(GPUThreshold().level(for: 0.4) == .normal)
    }

    @Test func gpuThreshold_critical_aboveEightyFive() {
        #expect(GPUThreshold().level(for: 0.9) == .critical)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: 0.5)]
        let viewModel = GPUViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()
        let usageBeforeStop = viewModel.usage
        viewModel.stop()

        await waitForAsyncUpdates()
        #expect(viewModel.usage == usageBeforeStop)
    }
}
