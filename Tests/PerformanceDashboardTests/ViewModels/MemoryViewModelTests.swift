import Testing
@testable import PerformanceDashboard

@MainActor
struct MemoryViewModelTests {
    @Test func memoryUsage_updatesFromStream() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.8, total: 16_000_000_000, used: 12_800_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usage == 0.8)
        #expect(viewModel.totalBytes == 16_000_000_000)
        #expect(viewModel.usedBytes == 12_800_000_000)
    }

    @Test func memoryUsageLabel_formatsToOneDecimal() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.5, total: 8_000_000_000, used: 4_000_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usageLabel == "50.0%")
    }

    @Test func memoryThreshold_normal_belowSeventy() {
        #expect(MetricThresholds.memory.level(for: 0.6) == .normal)
    }

    @Test func memoryThreshold_warning_betweenSeventyAndNinety() {
        #expect(MetricThresholds.memory.level(for: 0.8) == .warning)
    }

    @Test func memoryThreshold_critical_aboveNinety() {
        #expect(MetricThresholds.memory.level(for: 0.95) == .critical)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.7, total: 8_000_000_000, used: 5_600_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()
        let usageBeforeStop = viewModel.usage
        viewModel.stop()

        await waitForAsyncUpdates()
        #expect(viewModel.usage == usageBeforeStop)
    }

    // MARK: - Label formatting

    @Test func usedLabel_containsUnit() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.5, total: 8_000_000_000, used: 4_000_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(!viewModel.usedLabel.isEmpty)
        #expect(viewModel.usedLabel.contains("B"))
    }

    @Test func totalLabel_containsUnit() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.5, total: 16_000_000_000, used: 8_000_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(!viewModel.totalLabel.isEmpty)
        #expect(viewModel.totalLabel.contains("B"))
    }

    // MARK: - detailModel

    @Test func detailModel_hasThreeStats() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.75, total: 16_000_000_000, used: 12_000_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 3)
        #expect(viewModel.detailModel.stats[0].label == "Used")
        #expect(viewModel.detailModel.stats[1].label == "Total")
        #expect(viewModel.detailModel.stats[2].label == "Free")
    }

    @Test func detailModel_primaryValueMatchesUsageLabel() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.55, total: 8_000_000_000, used: 4_400_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.primaryValue == "55.0%")
        #expect(viewModel.detailModel.title == "Memory")
        #expect(viewModel.detailModel.systemImage == "memorychip")
    }

    @Test func detailModel_freeStatIsComputed() async {
        let monitor = MockMonitor<MemorySnapshot>()
        let total: UInt64 = 16_000_000_000
        let used: UInt64 = 12_000_000_000
        monitor.snapshots = [MemorySnapshot(usage: 0.75, total: total, used: used)]
        let viewModel = MemoryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        let freeStat = viewModel.detailModel.stats[2]
        #expect(!freeStat.value.isEmpty)
    }

    @Test func tileModel_gaugeValueMatchesUsage() async {
        let monitor = MockMonitor<MemorySnapshot>()
        monitor.snapshots = [MemorySnapshot(usage: 0.6, total: 16_000_000_000, used: 9_600_000_000)]
        let viewModel = MemoryViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.gaugeValue == 0.6)
        #expect(viewModel.tileModel.value == "60.0%")
    }
}
