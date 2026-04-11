import Testing
@testable import PerformanceDashboard

@MainActor
struct FanViewModelDetailTests {
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
