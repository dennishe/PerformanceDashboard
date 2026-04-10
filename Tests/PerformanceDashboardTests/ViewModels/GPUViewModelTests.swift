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

    // MARK: - New coverage tests

    @Test func gpuUsageLabel_formatsPercentWhenPresent() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: 0.75)]
        let viewModel = GPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.usageLabel == "75.0%")
    }

    @Test func detailModel_hasOneUsageStat_whenUsagePresent() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: 0.65)]
        let viewModel = GPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Utilisation")
        #expect(viewModel.detailModel.stats[0].value == "65.0%")
    }

    @Test func detailModel_hasNoStats_whenUsageNil() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: nil)]
        let viewModel = GPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.isEmpty)
    }

    @Test func tileModel_hasUnavailableReason_whenUsageNil() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: nil)]
        let viewModel = GPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.unavailableReason == "GPU stats unavailable")
    }

    @Test func tileModel_noUnavailableReason_whenUsagePresent() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: 0.5)]
        let viewModel = GPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.unavailableReason == nil)
    }

    @Test func tileModel_gaugeIsNil_whenUsageNil() async {
        let monitor = MockMonitor<GPUSnapshot>()
        monitor.snapshots = [GPUSnapshot(usage: nil)]
        let viewModel = GPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.gaugeValue == nil)
    }

    @Test func gpuThreshold_warning_betweenSixtyAndEightyFive() {
        #expect(GPUThreshold().level(for: 0.7) == .warning)
    }
}
