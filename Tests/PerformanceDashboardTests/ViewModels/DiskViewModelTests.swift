import Testing
@testable import PerformanceDashboard

@MainActor
struct DiskViewModelTests {
    @Test func diskUsage_updatesFromStream() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.6, total: 500_000_000_000, available: 200_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.usage == 0.6)
    }

    @Test func diskAvailableLabel_usesByteCountFormatter() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.5, total: 1_000_000_000_000, available: 500_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(!viewModel.availableLabel.isEmpty)
    }

    @Test func diskThreshold_normal_belowSeventyFive() {
        #expect(DiskThreshold().level(for: 0.5) == .normal)
    }

    @Test func diskThreshold_warning_betweenSeventyFiveAndNinety() {
        #expect(DiskThreshold().level(for: 0.8) == .warning)
    }

    @Test func diskThreshold_critical_aboveNinety() {
        #expect(DiskThreshold().level(for: 0.95) == .critical)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.4, total: 500_000_000_000, available: 300_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let usageBeforeStop = viewModel.usage
        viewModel.stop()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.usage == usageBeforeStop)
    }
}
