import Testing
@testable import PerformanceDashboard

struct WirelessMonitorServiceTests {
    private struct MockWiFiStateProvider: WiFiStateProviding {
        let state: WiFiInterfaceState?

        func currentState() -> WiFiInterfaceState? {
            state
        }
    }

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

    @Test @MainActor func wifiService_sample_usesInjectedProvider() async {
        let service = WiFiMonitorService(
            provider: MockWiFiStateProvider(state: WiFiInterfaceState(ssid: "Lab", rssi: -55, on: true))
        )

        let snapshot = await service.sample()

        #expect(snapshot == WiFiSnapshot(ssid: "Lab", rssi: -55, on: true))
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

    // MARK: - WiFiSnapshot additional edge cases

    @Test func wifiSnapshot_strongSignal_isValid() {
        let snapshot = WiFiSnapshot(ssid: "Home", rssi: -30, on: true)
        #expect(snapshot.rssi == -30)
        #expect(snapshot.on == true)
    }

    @Test func wifiSnapshot_weakSignal_isValid() {
        let snapshot = WiFiSnapshot(ssid: "Weak", rssi: -80, on: true)
        #expect(snapshot.rssi == -80)
    }

    @Test func wifiSnapshot_radioOff_ssidNil() {
        let snapshot = WiFiSnapshot(ssid: nil, rssi: nil, on: false)
        #expect(snapshot.on == false)
        #expect(snapshot.ssid == nil)
    }

    @Test func wifiSnapshot_connectedButRssiNil() {
        let snapshot = WiFiSnapshot(ssid: "Connected", rssi: nil, on: true)
        #expect(snapshot.ssid == "Connected")
        #expect(snapshot.rssi == nil)
    }

    @Test func wifiSnapshot_isSendable() {
        let snapshot = WiFiSnapshot(ssid: "Net", rssi: -60, on: true)
        let _: Sendable = snapshot
    }

    // MARK: - PeripheralBattery

    @Test func peripheralBattery_storesNameAndPercent() {
        let peripheral = PeripheralBattery(name: "Mouse", percent: 85)
        #expect(peripheral.name == "Mouse")
        #expect(peripheral.percent == 85)
    }

    @Test func peripheralBattery_fullBattery_isValid() {
        let peripheral = PeripheralBattery(name: "Trackpad", percent: 100)
        #expect(peripheral.percent == 100)
    }

    @Test func peripheralBattery_zeroBattery_isValid() {
        let peripheral = PeripheralBattery(name: "Keyboard", percent: 0)
        #expect(peripheral.percent == 0)
    }

    @Test func peripheralBattery_isSendable() {
        let peripheral = PeripheralBattery(name: "Device", percent: 50)
        let _: Sendable = peripheral
    }

    @Test func bluetoothPeripheralProvider_merge_prefersHIDBatteryForSameName() {
        let merged = BluetoothPeripheralBatteryProvider.merge(
            hidBatteries: [PeripheralBattery(name: "Magic Keyboard", percent: 88)],
            runtimeBatteries: [PeripheralBattery(name: "Magic Keyboard", percent: 83)]
        )

        #expect(merged.count == 1)
        #expect(merged[0].name == "Magic Keyboard")
        #expect(merged[0].percent == 88)
    }

    @Test func bluetoothPeripheralProvider_merge_keepsDistinctRuntimeComponents() {
        let merged = BluetoothPeripheralBatteryProvider.merge(
            hidBatteries: [],
            runtimeBatteries: [
                PeripheralBattery(name: "AirPods Pro (Left)", percent: 71),
                PeripheralBattery(name: "AirPods Pro (Right)", percent: 68),
                PeripheralBattery(name: "AirPods Pro (Case)", percent: 42)
            ]
        )

        #expect(merged.count == 3)
        #expect(merged.contains {
            $0.name == "AirPods Pro (Left)" && $0.percent == 71
        })
        #expect(merged.contains {
            $0.name == "AirPods Pro (Right)" && $0.percent == 68
        })
        #expect(merged.contains {
            $0.name == "AirPods Pro (Case)" && $0.percent == 42
        })
    }

    // MARK: - BluetoothSnapshot additional

    @Test func bluetoothSnapshot_isSendable() {
        let snapshot = BluetoothSnapshot(connectedCount: 0, on: false)
        let _: Sendable = snapshot
    }

    @Test @MainActor func wifiService_stream_returnsAsyncStream() {
        let service = WiFiMonitorService()
        let stream: AsyncStream<WiFiSnapshot> = service.stream()
        _ = stream
        service.stop()
    }

    @Test @MainActor func bluetoothService_stop_isIdempotent() {
        let service = BluetoothMonitorService()
        _ = service.stream()
        service.stop()
        service.stop()
    }
}
