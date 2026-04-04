import Testing
@testable import PerformanceDashboard

struct WirelessMonitorServiceTests {

    // MARK: - WirelessSnapshot

    @Test func wirelessSnapshot_storesAllFields() {
        let snapshot = WirelessSnapshot(
            wifiSSID: "TestNetwork", wifiRSSI: -58, wifiOn: true,
            bluetoothConnectedCount: 2, bluetoothOn: true
        )
        #expect(snapshot.wifiSSID == "TestNetwork")
        #expect(snapshot.wifiRSSI == -58)
        #expect(snapshot.wifiOn == true)
        #expect(snapshot.bluetoothConnectedCount == 2)
        #expect(snapshot.bluetoothOn == true)
    }

    @Test func wirelessSnapshot_allowsAllNilWifi() {
        let snapshot = WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: false,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )
        #expect(snapshot.wifiSSID == nil)
        #expect(snapshot.wifiRSSI == nil)
        #expect(snapshot.wifiOn == false)
        #expect(snapshot.bluetoothConnectedCount == 0)
        #expect(snapshot.bluetoothOn == false)
    }

    @Test func wirelessSnapshot_negativeRSSI_isStoredVerbatim() {
        let snapshot = WirelessSnapshot(
            wifiSSID: "Net", wifiRSSI: -100, wifiOn: true,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )
        #expect(snapshot.wifiRSSI == -100)
    }

    @Test func wirelessSnapshot_ssidWithoutRSSI_representsDisconnected() {
        let snapshot = WirelessSnapshot(
            wifiSSID: nil, wifiRSSI: nil, wifiOn: true,
            bluetoothConnectedCount: 0, bluetoothOn: false
        )
        #expect(snapshot.wifiOn == true)
        #expect(snapshot.wifiSSID == nil)
        #expect(snapshot.wifiRSSI == nil)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = WirelessMonitorService()
        let _: any MetricMonitorProtocol<WirelessSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = WirelessMonitorService()
        let _ = service.stream()
        service.stop()
    }
}
