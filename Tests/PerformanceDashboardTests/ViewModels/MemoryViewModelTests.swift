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
        #expect(MemoryThreshold().level(for: 0.6) == .normal)
    }

    @Test func memoryThreshold_warning_betweenSeventyAndNinety() {
        #expect(MemoryThreshold().level(for: 0.8) == .warning)
    }

    @Test func memoryThreshold_critical_aboveNinety() {
        #expect(MemoryThreshold().level(for: 0.95) == .critical)
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
}
