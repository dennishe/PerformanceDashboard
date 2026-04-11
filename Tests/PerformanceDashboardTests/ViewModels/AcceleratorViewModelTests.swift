import Testing
@testable import PerformanceDashboard

@MainActor
struct AcceleratorViewModelTests {
    @Test func acceleratorUsage_updatesFromStream() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.25)]
        let viewModel = AcceleratorViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.aneUsage == 0.25)
    }

    @Test func acceleratorUsageLabel_showsNAWhenNil() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: nil)]
        let viewModel = AcceleratorViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.usageLabel == "N/A")
    }

    @Test func acceleratorThreshold_normal_belowSixty() {
        #expect(MetricThresholds.accelerator.level(for: 0.3) == .normal)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.2)]
        let viewModel = AcceleratorViewModel(monitor: monitor)

        viewModel.start()
        await waitForAsyncUpdates()
        let usageBeforeStop = viewModel.aneUsage
        viewModel.stop()

        await waitForAsyncUpdates()
        #expect(viewModel.aneUsage == usageBeforeStop)
    }

    // MARK: - New coverage tests

    @Test func usageLabel_formatsPercentWhenPresent() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.45)]
        let viewModel = AcceleratorViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.usageLabel == "45.0%")
    }

    @Test func detailModel_hasOneStat_whenUsagePresent() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.3)]
        let viewModel = AcceleratorViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Utilisation")
        #expect(viewModel.detailModel.stats[0].value == "30.0%")
    }

    @Test func detailModel_hasNoStats_whenUsageNil() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: nil)]
        let viewModel = AcceleratorViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.stats.isEmpty)
    }

    @Test func detailModel_hasCorrectMetadata() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.5)]
        let viewModel = AcceleratorViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.detailModel.title == "ANE")
        #expect(viewModel.detailModel.systemImage == "brain")
    }

    @Test func tileModel_gaugeIsNil_whenUsageNil() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: nil)]
        let viewModel = AcceleratorViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.gaugeValue == nil)
    }

    @Test func tileModel_hasGaugeValue_whenUsagePresent() async {
        let monitor = MockMonitor<AcceleratorSnapshot>()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.7)]
        let viewModel = AcceleratorViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.tileModel.gaugeValue == 0.7)
    }

    @Test func acceleratorThreshold_warning_betweenSixtyAndEightyFive() {
        #expect(MetricThresholds.accelerator.level(for: 0.7) == .warning)
    }

    @Test func acceleratorThreshold_critical_aboveEightyFive() {
        #expect(MetricThresholds.accelerator.level(for: 0.9) == .critical)
    }
}
