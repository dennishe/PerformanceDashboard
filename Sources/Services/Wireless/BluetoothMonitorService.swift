import Foundation
import IOBluetooth
import IOKit

struct BluetoothControllerState: Sendable, Equatable {
    let connectedCount: Int
    let on: Bool
}

protocol BluetoothControllerStateProviding {
    func currentState() async -> BluetoothControllerState
}

struct BluetoothPeripheralHIDSample: Sendable, Equatable {
    let transport: String?
    let name: String?
    let batteryPercent: Int?
}

private struct LiveBluetoothControllerStateProvider: BluetoothControllerStateProviding {
    func currentState() async -> BluetoothControllerState {
        await MainActor.run {
            let on = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
            let count = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
                .filter { $0.isConnected() }
                .count
            return BluetoothControllerState(connectedCount: count, on: on)
        }
    }
}

/// Battery level for a connected Bluetooth peripheral.
public struct PeripheralBattery: Sendable, Equatable {
    public let name: String
    public let percent: Int
}

/// Snapshot of Bluetooth controller state at a point in time.
public struct BluetoothSnapshot: MetricSnapshot {
    /// Number of currently connected Bluetooth devices.
    public let connectedCount: Int
    /// `true` while Bluetooth is powered on.
    public let on: Bool

    public init(connectedCount: Int, on: Bool) {
        self.connectedCount = connectedCount
        self.on = on
    }
}

/// Polls Bluetooth status via IOBluetooth.
/// IOBluetooth requires main-thread access, so sampling is dispatched to `@MainActor`.
public final class BluetoothMonitorService: PollingMonitorBase<BluetoothSnapshot> {
    @MonitorActor
    override public func sample() async -> BluetoothSnapshot? {
        await BluetoothMonitorService.sample(provider: LiveBluetoothControllerStateProvider())
    }

    nonisolated static func sample(
        provider: some BluetoothControllerStateProviding
    ) async -> BluetoothSnapshot {
        snapshot(state: await provider.currentState())
    }

    nonisolated static func snapshot(state: BluetoothControllerState) -> BluetoothSnapshot {
        BluetoothSnapshot(connectedCount: state.connectedCount, on: state.on)
    }

    /// Reads battery percentage for connected Bluetooth HID devices via IOKit.
    nonisolated static func samplePeripheralBatteries() -> [PeripheralBattery] {
        guard let matchingDict = IOServiceMatching("IOHIDDevice") else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
                == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var devices: [BluetoothPeripheralHIDSample] = []
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            devices.append(
                BluetoothPeripheralHIDSample(
                    transport: stringProperty(named: "Transport", for: service),
                    name: stringProperty(named: "Product", for: service),
                    batteryPercent: intProperty(named: "BatteryPercent", for: service)
                )
            )
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return samplePeripheralBatteries(from: devices)
    }

    nonisolated static func samplePeripheralBatteries(
        from devices: [BluetoothPeripheralHIDSample]
    ) -> [PeripheralBattery] {
        devices.compactMap { device in
            guard device.transport == "Bluetooth",
                  let batteryPercent = device.batteryPercent else {
                return nil
            }

            return PeripheralBattery(
                name: device.name ?? "Bluetooth Device",
                percent: batteryPercent
            )
        }
    }

    nonisolated private static func stringProperty(named key: String, for service: io_service_t) -> String? {
        ioProperty(named: key, for: service) as? String
    }

    nonisolated private static func intProperty(named key: String, for service: io_service_t) -> Int? {
        if let value = ioProperty(named: key, for: service) as? Int {
            return value
        }

        if let number = ioProperty(named: key, for: service) as? NSNumber {
            return number.intValue
        }

        return nil
    }

    nonisolated private static func ioProperty(named key: String, for service: io_service_t) -> Any? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
    }
}
