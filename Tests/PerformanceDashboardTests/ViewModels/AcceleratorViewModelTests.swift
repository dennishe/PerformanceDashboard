import Testing
@testable import PerformanceDashboard

@MainActor
struct AcceleratorViewModelTests {
    @Test func acceleratorUsage_updatesFromStream() async {
        let monitor = MockAcceleratorMonitor()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.25)]
        let viewModel = AcceleratorViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.aneUsage == 0.25)
    }

    @Test func acceleratorUsageLabel_showsNAWhenNil() async {
        let monitor = MockAcceleratorMonitor()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: nil)]
        let viewModel = AcceleratorViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.usageLabel == "N/A")
    }

    @Test func acceleratorThreshold_normal_belowSixty() {
        #expect(AcceleratorThreshold().level(for: 0.3) == .normal)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockAcceleratorMonitor()
        monitor.snapshots = [AcceleratorSnapshot(aneUsage: 0.2)]
        let viewModel = AcceleratorViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let usageBeforeStop = viewModel.aneUsage
        viewModel.stop()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.aneUsage == usageBeforeStop)
    }
}
