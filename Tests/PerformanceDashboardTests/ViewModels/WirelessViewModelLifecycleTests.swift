import Testing
@testable import PerformanceDashboard

@MainActor
private func startAndDrain(_ viewModel: WirelessViewModel, passes: Int = 10) async {
    viewModel.start()
    for _ in 0..<passes {
        await Task.yield()
    }
}

@MainActor
struct WirelessViewModelLifecycleTests {

    @Test func history_appendsNormalizedRSSI() async {
        let wifiMock = MockMonitor<WiFiSnapshot>(snapshots: [WiFiSnapshot(ssid: "Net", rssi: -65, on: true)])
        let btMock = MockMonitor<BluetoothSnapshot>(snapshots: [BluetoothSnapshot(connectedCount: 0, on: false)])
        let viewModel = WirelessViewModel(
            wifiMonitor: wifiMock,
            btMonitor: btMock,
            batcher: SynchronousBatcher()
        )
        await startAndDrain(viewModel)
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(abs((viewModel.history.last ?? -1) - 0.5) < 0.001) // (-65+100)/70 = 0.5
    }

    @Test func stop_haltsUpdates() async {
        let wifiMock = MockMonitor<WiFiSnapshot>(snapshots: [WiFiSnapshot(ssid: "Net", rssi: -58, on: true)])
        let btMock   = MockMonitor<BluetoothSnapshot>(snapshots: [BluetoothSnapshot(connectedCount: 2, on: true)])
        let viewModel = WirelessViewModel(
            wifiMonitor: wifiMock,
            btMonitor: btMock,
            batcher: SynchronousBatcher()
        )
        await startAndDrain(viewModel)
        let wifiStateBeforeStop = viewModel.wifiOn
        viewModel.stop()
        await Task.yield()
        #expect(viewModel.wifiOn == wifiStateBeforeStop)
    }
}
