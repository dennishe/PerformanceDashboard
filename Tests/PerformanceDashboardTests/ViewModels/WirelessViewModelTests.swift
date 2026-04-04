import Testing
@testable import PerformanceDashboard

@MainActor
struct WirelessViewModelTests {

    @Test func wifiState_updatesFromStream() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "TestNet", wifiRSSI: -58, wifiOn: true,
            bluetoothConnectedCount: 2, bluetoothOn: true
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.wifiSSID == "TestNet")
        #expect(viewModel.wifiRSSI == -58)
        #expect(viewModel.wifiOn == true)
        #expect(viewModel.bluetoothConnectedCount == 2)
    }

    @Test func gaugeValue_isNil_whenWifiOff() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: false,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_isZero_whenWifiOnButNotConnected() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: true,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0)
    }

    @Test func gaugeValue_normalisesRSSI() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -65, wifiOn: true,  // (-65+100)/70 = 0.5
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(abs((viewModel.gaugeValue ?? -1) - 0.5) < 0.001)
    }

    @Test func gaugeValue_capsAtOne_forStrongSignal() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -20, wifiOn: true,  // (-20+100)/70 > 1.0 → capped at 1.0
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func signalLabel_showsWifiOff_whenRadioOff() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: false,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.signalLabel == "Wi-Fi Off")
    }

    @Test func signalLabel_showsDisconnected_whenWifiOnButNoRSSI() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: true,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.signalLabel == "Disconnected")
    }

    @Test func signalLabel_showsRSSI_whenConnected() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -58, wifiOn: true,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.signalLabel == "-58 dBm")
    }

    @Test func ssidLabel_returnsSSID() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "HomeNetwork", wifiRSSI: -50, wifiOn: true,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.ssidLabel == "HomeNetwork")
    }

    @Test func bluetoothLabel_showsBTOff_whenBluetoothOff() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: false,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.bluetoothLabel == "BT Off")
    }

    @Test func bluetoothLabel_showsConnectedCount() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: false,
            bluetoothConnectedCount: 3, bluetoothOn: true
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.bluetoothLabel == "BT: 3 connected")
    }

    @Test func thresholdLevel_inactive_whenWifiOff() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: false,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .inactive)
    }

    @Test func thresholdLevel_normal_forStrongSignal() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -50, wifiOn: true,  // (-50+100)/70 ≈ 0.71 ≥ 0.5
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forVeryWeakSignal() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -95, wifiOn: true,  // (-95+100)/70 ≈ 0.07 < 0.36
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsNormalizedRSSI() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -65, wifiOn: true,  // (-65+100)/70 = 0.5
            bluetoothConnectedCount: 0, bluetoothOn: false
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(abs(viewModel.history[0] - 0.5) < 0.001)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockWirelessMonitor()
        monitor.snapshots = [WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -58, wifiOn: true,
            bluetoothConnectedCount: 2, bluetoothOn: true
        )]
        let viewModel = WirelessViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let wifiStateBeforeStop = viewModel.wifiOn
        viewModel.stop()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.wifiOn == wifiStateBeforeStop)
    }
}
