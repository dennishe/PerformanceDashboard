import Testing
@testable import PerformanceDashboard

struct WirelessServiceMappingTests {
    private struct MockWiFiStateProvider: WiFiStateProviding {
        let state: WiFiInterfaceState?

        func currentState() -> WiFiInterfaceState? {
            state
        }
    }

    private struct MockBluetoothControllerStateProvider: BluetoothControllerStateProviding {
        let state: BluetoothControllerState

        func currentState() async -> BluetoothControllerState {
            state
        }
    }

    @Test func wifiSample_returnsOffWhenInterfaceIsUnavailable() {
        let snapshot = WiFiMonitorService.sample(
            provider: MockWiFiStateProvider(state: nil)
        )

        #expect(snapshot == WiFiSnapshot(ssid: nil, rssi: nil, on: false))
    }

    @Test func wifiSample_returnsDisconnectedWhenRadioIsOnWithoutSSID() {
        let snapshot = WiFiMonitorService.sample(
            provider: MockWiFiStateProvider(state: WiFiInterfaceState(ssid: nil, rssi: -60, on: true))
        )

        #expect(snapshot == WiFiSnapshot(ssid: nil, rssi: nil, on: true))
    }

    @Test func wifiSample_dropsZeroRSSIForConnectedNetwork() {
        let snapshot = WiFiMonitorService.sample(
            provider: MockWiFiStateProvider(state: WiFiInterfaceState(ssid: "Cafe", rssi: 0, on: true))
        )

        #expect(snapshot == WiFiSnapshot(ssid: "Cafe", rssi: nil, on: true))
    }

    @Test func wifiSample_preservesConnectedNetworkWithNonZeroRSSI() {
        let snapshot = WiFiMonitorService.sample(
            provider: MockWiFiStateProvider(state: WiFiInterfaceState(ssid: "Office", rssi: -47, on: true))
        )

        #expect(snapshot == WiFiSnapshot(ssid: "Office", rssi: -47, on: true))
    }

    @Test func wifiSample_ignoresSSIDWhenRadioIsOff() {
        let snapshot = WiFiMonitorService.sample(
            provider: MockWiFiStateProvider(state: WiFiInterfaceState(ssid: "Office", rssi: -47, on: false))
        )

        #expect(snapshot == WiFiSnapshot(ssid: nil, rssi: nil, on: false))
    }

    @Test func bluetoothSample_usesInjectedControllerState() async {
        let snapshot = await BluetoothMonitorService.sample(
            provider: MockBluetoothControllerStateProvider(
                state: BluetoothControllerState(connectedCount: 3, on: true)
            )
        )

        #expect(snapshot == BluetoothSnapshot(connectedCount: 3, on: true))
    }

    @Test func bluetoothPeripheralBatteries_filterBluetoothDevicesAndUseFallbackName() {
        let batteries = BluetoothMonitorService.samplePeripheralBatteries(from: [
            BluetoothPeripheralHIDSample(transport: "Bluetooth", name: "Mouse", batteryPercent: 85),
            BluetoothPeripheralHIDSample(transport: "USB", name: "Keyboard", batteryPercent: 90),
            BluetoothPeripheralHIDSample(transport: "Bluetooth", name: nil, batteryPercent: 40),
            BluetoothPeripheralHIDSample(transport: "Bluetooth", name: "Trackpad", batteryPercent: nil)
        ])

        #expect(batteries.count == 2)
        #expect(batteries.contains { $0.name == "Mouse" && $0.percent == 85 })
        #expect(batteries.contains { $0.name == "Bluetooth Device" && $0.percent == 40 })
    }

    @Test func bluetoothPeripheralBatteries_keepsZeroPercentDevices() {
        let batteries = BluetoothMonitorService.samplePeripheralBatteries(from: [
            BluetoothPeripheralHIDSample(transport: "Bluetooth", name: "Headset", batteryPercent: 0)
        ])

        #expect(batteries == [PeripheralBattery(name: "Headset", percent: 0)])
    }
}
