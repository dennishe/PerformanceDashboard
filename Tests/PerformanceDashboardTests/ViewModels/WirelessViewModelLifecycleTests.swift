import Testing
@testable import PerformanceDashboard

@MainActor
struct WirelessViewModelLifecycleTests {

    @Test func history_appendsNormalizedRSSI() async {
        let wifiMock = MockMonitor<WiFiSnapshot>(snapshots: [WiFiSnapshot(ssid: "Net", rssi: -65, on: true)])
        let btMock   = MockMonitor<BluetoothSnapshot>()
        let viewModel = WirelessViewModel(wifiMonitor: wifiMock, btMonitor: btMock)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(abs(viewModel.history[0] - 0.5) < 0.001) // (-65+100)/70 = 0.5
    }

    @Test func stop_haltsUpdates() async {
        let wifiMock = MockMonitor<WiFiSnapshot>(snapshots: [WiFiSnapshot(ssid: "Net", rssi: -58, on: true)])
        let btMock   = MockMonitor<BluetoothSnapshot>(snapshots: [BluetoothSnapshot(connectedCount: 2, on: true)])
        let viewModel = WirelessViewModel(wifiMonitor: wifiMock, btMonitor: btMock)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let wifiStateBeforeStop = viewModel.wifiOn
        viewModel.stop()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.wifiOn == wifiStateBeforeStop)
    }
}
