import Foundation
import IOBluetooth
import IOKit

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
        let (count, on) = await sampleStateOnMain()
        return BluetoothSnapshot(connectedCount: count, on: on)
    }

    private func sampleStateOnMain() async -> (connectedCount: Int, on: Bool) {
        await MainActor.run {
            let on = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
            let count = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
                .filter { $0.isConnected() }
                .count
            return (count, on)
        }
    }

    /// Reads battery percentage for connected Bluetooth HID devices via IOKit.
    nonisolated static func samplePeripheralBatteries() -> [PeripheralBattery] {
        guard let matchingDict = IOServiceMatching("IOHIDDevice") else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
                == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var result: [PeripheralBattery] = []
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            if stringProperty(named: "Transport", for: service) == "Bluetooth",
               let battery = intProperty(named: "BatteryPercent", for: service) {
                let name = stringProperty(named: "Product", for: service) ?? "Bluetooth Device"
                result.append(PeripheralBattery(name: name, percent: battery))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
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
