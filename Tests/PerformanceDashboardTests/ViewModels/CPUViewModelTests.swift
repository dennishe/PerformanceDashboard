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
        #expect(MetricThresholds.cpu.level(for: 0.5) == .normal)
    }

    @Test func cpuThreshold_warning_betweenSixtyAndEightyFive() {
        #expect(MetricThresholds.cpu.level(for: 0.7) == .warning)
    }

    @Test func cpuThreshold_critical_aboveEightyFive() {
        #expect(MetricThresholds.cpu.level(for: 0.9) == .critical)
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

    // MARK: - process / detailModel coverage

    @Test func topProcesses_empty_whenSnapshotHasNone() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.5, topProcesses: [])]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.topProcesses.isEmpty)
    }

    @Test func topProcesses_singleProcess() async {
        let monitor = MockMonitor<CPUSnapshot>()
        let process = ProcessCPUStat(name: "Safari", fraction: 0.25)
        monitor.snapshots = [CPUSnapshot(usage: 0.5, topProcesses: [process])]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.topProcesses.count == 1)
        #expect(viewModel.topProcesses[0].name == "Safari")
        #expect(viewModel.topProcesses[0].fraction == 0.25)
    }

    @Test func topProcesses_multipleProcesses() async {
        let monitor = MockMonitor<CPUSnapshot>()
        let processes = [
            ProcessCPUStat(name: "Safari", fraction: 0.3),
            ProcessCPUStat(name: "Xcode", fraction: 0.2),
            ProcessCPUStat(name: "Python", fraction: 0.15)
        ]
        monitor.snapshots = [CPUSnapshot(usage: 0.65, topProcesses: processes)]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.topProcesses.count == 3)
        #expect(viewModel.topProcesses[0].name == "Safari")
    }

    @Test func detailModel_showsUsageOnly_whenNoProcesses() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.4, topProcesses: [])]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Usage")
        #expect(viewModel.detailModel.stats[0].value == "40.0%")
    }

    @Test func detailModel_mapsProcessesToStats() async {
        let monitor = MockMonitor<CPUSnapshot>()
        let processes = [
            ProcessCPUStat(name: "Chrome", fraction: 0.35),
            ProcessCPUStat(name: "Node", fraction: 0.15)
        ]
        monitor.snapshots = [CPUSnapshot(usage: 0.5, topProcesses: processes)]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 2)
        #expect(viewModel.detailModel.stats[0].label == "Chrome")
        #expect(viewModel.detailModel.stats[0].value == "35.0%")
        #expect(viewModel.detailModel.stats[1].label == "Node")
        #expect(viewModel.detailModel.stats[1].value == "15.0%")
    }

    @Test func detailModel_hasCorrectMetadata() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.6)]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.title == "CPU")
        #expect(viewModel.detailModel.systemImage == "cpu")
        #expect(viewModel.detailModel.primaryValue == "60.0%")
    }

    @Test func processPercentLabel_formatsCorrectly() async {
        let monitor = MockMonitor<CPUSnapshot>()
        let process = ProcessCPUStat(name: "TestApp", fraction: 0.123)
        monitor.snapshots = [CPUSnapshot(usage: 0.5, topProcesses: [process])]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.topProcesses[0].percentLabel == "12.3%")
    }

    @Test func emptyProcessName_isHandled() async {
        let monitor = MockMonitor<CPUSnapshot>()
        monitor.snapshots = [CPUSnapshot(usage: 0.5, topProcesses: [ProcessCPUStat(name: "", fraction: 0.1)])]
        let viewModel = CPUViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.topProcesses[0].name.isEmpty)
        #expect(viewModel.detailModel.stats[0].label.isEmpty)
    }
}
