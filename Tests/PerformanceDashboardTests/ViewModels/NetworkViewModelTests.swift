import Testing
@testable import PerformanceDashboard

@MainActor
struct NetworkViewModelTests {
    @Test func networkLabels_formatBytesPerSecond() async {
        let monitor = MockMonitor<NetworkSnapshot>()
        monitor.snapshots = [NetworkSnapshot(bytesInPerSecond: 1_048_576, bytesOutPerSecond: 524_288)]
        let viewModel = NetworkViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.inLabel.contains("/s"))
        #expect(viewModel.outLabel.contains("/s"))
    }

    @Test func networkHistory_appendsSeparateInAndOut() async {
        let monitor = MockMonitor<NetworkSnapshot>()
        monitor.snapshots = [
            NetworkSnapshot(bytesInPerSecond: 100, bytesOutPerSecond: 200),
            NetworkSnapshot(bytesInPerSecond: 300, bytesOutPerSecond: 400)
        ]
        let viewModel = NetworkViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.historyIn.count == Constants.historySamples)
        #expect(viewModel.historyOut.count == Constants.historySamples)
        #expect(viewModel.historyIn.suffix(2).elementsEqual([100, 300]))
        #expect(viewModel.historyOut.suffix(2).elementsEqual([200, 400]))
    }

    @Test func networkThreshold_normal_belowFiftyMB() {
        #expect(NetworkThreshold().level(for: 10_000_000) == .normal)
    }

    @Test func networkThreshold_warning_betweenFiftyAndHundredMB() {
        #expect(NetworkThreshold().level(for: 75_000_000) == .warning)
    }

    @Test func networkThreshold_critical_aboveHundredMB() {
        #expect(NetworkThreshold().level(for: 150_000_000) == .critical)
    }

    @Test func normalizedGauge_capsAtOne() async {
        let monitor = MockMonitor<NetworkSnapshot>()
        monitor.snapshots = [NetworkSnapshot(bytesInPerSecond: 200_000_000, bytesOutPerSecond: 150_000_000)]
        let viewModel = NetworkViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.inGauge == 1.0)
        #expect(viewModel.outGauge == 1.0)
    }

    @Test func normalizedGauge_belowCeiling() async {
        let monitor = MockMonitor<NetworkSnapshot>()
        monitor.snapshots = [NetworkSnapshot(bytesInPerSecond: 50_000_000, bytesOutPerSecond: 25_000_000)]
        let viewModel = NetworkViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.inGauge == 0.5)
        #expect(viewModel.outGauge == 0.25)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<NetworkSnapshot>()
        monitor.snapshots = [NetworkSnapshot(bytesInPerSecond: 1_000_000, bytesOutPerSecond: 500_000)]
        let viewModel = NetworkViewModel(monitor: monitor)

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let inBeforeStop = viewModel.bytesInPerSecond
        viewModel.stop()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.bytesInPerSecond == inBeforeStop)
    }

    @Test func networkLabels_zeroBytes_showsZeroKBps() {
        let monitor = MockMonitor<NetworkSnapshot>()
        monitor.snapshots = []
        let viewModel = NetworkViewModel(monitor: monitor)
        #expect(viewModel.inLabel == "0 KB/s")
        #expect(viewModel.outLabel == "0 KB/s")
    }
}
