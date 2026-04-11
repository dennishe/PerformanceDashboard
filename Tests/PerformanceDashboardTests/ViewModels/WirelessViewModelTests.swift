import Testing
@testable import PerformanceDashboard

@MainActor
private func makeViewModel(
    ssid: String? = nil, rssi: Int? = nil, wifiOn: Bool = false,
    btCount: Int = 0, btOn: Bool = false
) -> WirelessViewModel {
    let wifiMock = MockMonitor<WiFiSnapshot>(snapshots: [WiFiSnapshot(ssid: ssid, rssi: rssi, on: wifiOn)])
    let btMock   = MockMonitor<BluetoothSnapshot>(snapshots: [BluetoothSnapshot(connectedCount: btCount, on: btOn)])
    return WirelessViewModel(wifiMonitor: wifiMock, btMonitor: btMock)
}

@MainActor
struct WirelessViewModelTests {

    @Test func wifiState_updatesFromStream() async {
        let wifiMock = MockMonitor<WiFiSnapshot>(snapshots: [WiFiSnapshot(ssid: "TestNet", rssi: -58, on: true)])
        let btMock   = MockMonitor<BluetoothSnapshot>(snapshots: [BluetoothSnapshot(connectedCount: 2, on: true)])
        let viewModel = WirelessViewModel(wifiMonitor: wifiMock, btMonitor: btMock)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.wifiSSID == "TestNet")
        #expect(viewModel.wifiRSSI == -58)
        #expect(viewModel.wifiOn == true)
        #expect(viewModel.bluetoothConnectedCount == 2)
    }

    @Test func gaugeValue_isNil_whenWifiOff() async {
        let viewModel = makeViewModel(wifiOn: false)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_isZero_whenWifiOnButNotConnected() async {
        let viewModel = makeViewModel(wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 0)
    }

    @Test func gaugeValue_normalisesRSSI() async {
        let viewModel = makeViewModel(ssid: "Net", rssi: -65, wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(abs((viewModel.gaugeValue ?? -1) - 0.5) < 0.001)
    }

    @Test func gaugeValue_capsAtOne_forStrongSignal() async {
        let viewModel = makeViewModel(ssid: "Net", rssi: -20, wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func signalLabel_showsWifiOff_whenRadioOff() async {
        let viewModel = makeViewModel(wifiOn: false)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.signalLabel == "Wi-Fi Off")
    }

    @Test func signalLabel_showsDisconnected_whenWifiOnButNoRSSI() async {
        let viewModel = makeViewModel(wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.signalLabel == "Disconnected")
    }

    @Test func signalLabel_showsRSSI_whenConnected() async {
        let viewModel = makeViewModel(ssid: "Net", rssi: -58, wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.signalLabel == "-58 dBm")
    }

    @Test func ssidLabel_returnsSSID() async {
        let viewModel = makeViewModel(ssid: "HomeNetwork", rssi: -50, wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.ssidLabel == "HomeNetwork")
    }

    @Test func bluetoothLabel_showsBTOff_whenBluetoothOff() async {
        let viewModel = makeViewModel(btOn: false)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.bluetoothLabel == "BT Off")
    }

    @Test func bluetoothLabel_showsConnectedCount() async {
        let viewModel = makeViewModel(btCount: 3, btOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.bluetoothLabel == "BT: 3 connected")
    }

    @Test func thresholdLevel_inactive_whenWifiOff() async {
        let viewModel = makeViewModel(wifiOn: false)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func thresholdLevel_normal_forStrongSignal() async {
        let viewModel = makeViewModel(ssid: "Net", rssi: -50, wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forVeryWeakSignal() async {
        let viewModel = makeViewModel(ssid: "Net", rssi: -95, wifiOn: true)
        viewModel.start()
        await waitForAsyncUpdates()
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func detailModel_keepsBluetoothSummary_withoutPeripheralBatteryRows() async {
        let viewModel = makeViewModel(ssid: "Net", rssi: -58, wifiOn: true, btCount: 2, btOn: true)
        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.detailModel.stats.contains {
            $0.label == "Bluetooth" && $0.value == "2 connected"
        })
        #expect(!viewModel.detailModel.stats.contains { $0.value.hasSuffix("%") })
    }
}
