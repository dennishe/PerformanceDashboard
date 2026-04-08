import Testing
@testable import PerformanceDashboard

@MainActor
struct ThermalViewModelTests {

    @Test func cpuCelsius_updatesFromStream() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 65.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.cpuCelsius == 65.0)
    }

    @Test func gpuCelsius_updatesFromStream() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 50.0, gpuCelsius: 40.0)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gpuCelsius == 40.0)
    }

    @Test func gaugeValue_normalisesTo100CelsiusMax() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 50.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func gaugeValue_capsAtOne_forOverheat() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 150.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func gaugeValue_isNil_whenCpuIsNil() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: nil, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func cpuLabel_formatsToOneDecimalPlace() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 72.3, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.cpuLabel == "72.3°C")
    }

    @Test func cpuLabel_showsDash_whenCpuIsNil() {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = []
        let viewModel = ThermalViewModel(monitor: monitor)
        #expect(viewModel.cpuLabel == "—")
    }

    @Test func gpuLabel_isNil_whenGpuIsNil() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 50.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gpuLabel == nil)
    }

    @Test func gpuLabel_showsGpuPrefix() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 60.0, gpuCelsius: 45.5)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gpuLabel == "GPU 45.5°C")
    }

    @Test func thresholdLevel_inactive_beforeFirstSample() {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = []
        let viewModel = ThermalViewModel(monitor: monitor)
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func thresholdLevel_normal_belowSeventyPercent() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 60.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_warning_betweenSeventyAndEightyFive() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 78.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .warning)
    }

    @Test func thresholdLevel_critical_aboveEightyFive() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 90.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsNormalizedValue() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 50.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(abs((viewModel.history.last ?? -1) - 0.5) < 0.001)
    }

    @Test func history_appendsZero_whenCpuIsNil() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: nil, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(viewModel.history.last == 0)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<ThermalSnapshot>()
        monitor.snapshots = [ThermalSnapshot(cpuCelsius: 60.0, gpuCelsius: nil)]
        let viewModel = ThermalViewModel(monitor: monitor)
        viewModel.start()
        await waitForAsyncUpdates()
        let cpuBeforeStop = viewModel.cpuCelsius
        viewModel.stop()
        await waitForAsyncUpdates()
        #expect(viewModel.cpuCelsius == cpuBeforeStop)
    }
}
