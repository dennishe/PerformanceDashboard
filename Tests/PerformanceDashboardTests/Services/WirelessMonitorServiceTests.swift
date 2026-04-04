import Testing
@testable import PerformanceDashboard

struct WirelessMonitorServiceTests {

    // MARK: - WiFiSnapshot

    @Test func wifiSnapshot_storesAllFields() {
        let snapshot = WiFiSnapshot(ssid: "TestNetwork", rssi: -58, on: true)
        #expect(snapshot.ssid == "TestNetwork")
        #expect(snapshot.rssi == -58)
        #expect(snapshot.on == true)
    }

    @Test func wifiSnapshot_allowsNilFields() {
        let snapshot = WiFiSnapshot(ssid: nil, rssi: nil, on: false)
        #expect(snapshot.ssid == nil)
        #expect(snapshot.rssi == nil)
        #expect(snapshot.on == false)
    }

    @Test func wifiSnapshot_negativeRSSI_isStoredVerbatim() {
        let snapshot = WiFiSnapshot(ssid: "Net", rssi: -100, on: true)
        #expect(snapshot.rssi == -100)
    }

    // MARK: - BluetoothSnapshot

    @Test func bluetoothSnapshot_storesAllFields() {
        let snapshot = BluetoothSnapshot(connectedCount: 3, on: true)
        #expect(snapshot.connectedCount == 3)
        #expect(snapshot.on == true)
    }

    @Test func bluetoothSnapshot_zeroCount_whenOff() {
        let snapshot = BluetoothSnapshot(connectedCount: 0, on: false)
        #expect(snapshot.connectedCount == 0)
        #expect(snapshot.on == false)
    }

    // MARK: - WiFiMonitorService lifecycle

    @Test @MainActor func wifiService_conformsToProtocol() {
        let service = WiFiMonitorService()
        let _: any MetricMonitorProtocol<WiFiSnapshot> = service
    }

    @Test @MainActor func wifiService_stream_canBeStartedAndStopped() {
        let service = WiFiMonitorService()
        _ = service.stream()
        service.stop()
    }

    // MARK: - BluetoothMonitorService lifecycle

    @Test @MainActor func bluetoothService_conformsToProtocol() {
        let service = BluetoothMonitorService()
        let _: any MetricMonitorProtocol<BluetoothSnapshot> = service
    }

    @Test @MainActor func bluetoothService_stream_canBeStartedAndStopped() {
        let service = BluetoothMonitorService()
        _ = service.stream()
        service.stop()
    }
}
