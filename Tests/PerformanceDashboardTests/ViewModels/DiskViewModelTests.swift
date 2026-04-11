import Testing
@testable import PerformanceDashboard

@MainActor
struct DiskViewModelTests {
    @Test func diskUsage_updatesFromStream() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.6, total: 500_000_000_000, available: 200_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usage == 0.6)
    }

    @Test func diskAvailableLabel_usesByteCountFormatter() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.5, total: 1_000_000_000_000, available: 500_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(!viewModel.availableLabel.isEmpty)
    }

    @Test func diskThreshold_normal_belowSeventyFive() {
        #expect(MetricThresholds.disk.level(for: 0.5) == .normal)
    }

    @Test func diskThreshold_warning_betweenSeventyFiveAndNinety() {
        #expect(MetricThresholds.disk.level(for: 0.8) == .warning)
    }

    @Test func diskThreshold_critical_aboveNinety() {
        #expect(MetricThresholds.disk.level(for: 0.95) == .critical)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.4, total: 500_000_000_000, available: 300_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()
        let usageBeforeStop = viewModel.usage
        viewModel.stop()

        await waitForAsyncUpdates()
        #expect(viewModel.usage == usageBeforeStop)
    }

    // MARK: - New coverage tests

    @Test func diskUsageLabel_formatsToOneDecimal() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.735, total: 1_000_000_000_000, available: 265_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.usageLabel == "73.5%")
    }

    @Test func availableLabel_containsUnit() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.5, total: 1_000_000_000_000, available: 500_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.availableLabel.contains("B"))
    }

    @Test func totalLabel_containsUnit() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.25, total: 1_000_000_000_000, available: 750_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.totalLabel.contains("B"))
    }

    @Test func totalBytes_updatesFromStream() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.5, total: 1_000_000_000_000, available: 500_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.totalBytes == 1_000_000_000_000)
        #expect(viewModel.availableBytes == 500_000_000_000)
    }

    @Test func detailModel_hasThreeStats() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.6, total: 1_000_000_000_000, available: 400_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 3)
        #expect(viewModel.detailModel.stats[0].label == "Used")
        #expect(viewModel.detailModel.stats[1].label == "Free")
        #expect(viewModel.detailModel.stats[2].label == "Total")
    }

    @Test func detailModel_usedStatMatchesUsageLabel() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.65, total: 1_000_000_000_000, available: 350_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats[0].value == "65.0%")
    }

    @Test func detailModel_hasCorrectMetadata() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.4, total: 500_000_000_000, available: 300_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.title == "Disk")
        #expect(viewModel.detailModel.systemImage == "internaldrive")
        #expect(viewModel.detailModel.primaryValue == "40.0%")
    }

    @Test func tileModel_subtitleHasFreeIndicator() async {
        let monitor = MockMonitor<DiskSnapshot>()
        monitor.snapshots = [DiskSnapshot(usage: 0.4, total: 1_000_000_000_000, available: 600_000_000_000)]
        let viewModel = DiskViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.subtitle?.hasSuffix(" free") == true)
    }
}
