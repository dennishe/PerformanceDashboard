import Foundation
import IOBluetooth
import IOKit

/// Battery level for a connected Bluetooth peripheral.
public struct PeripheralBattery: Sendable {
    public let name: String
    public let percent: Int
}

/// Snapshot of Bluetooth controller state at a point in time.
public struct BluetoothSnapshot: Sendable {
    /// Number of currently connected Bluetooth devices.
    public let connectedCount: Int
    /// `true` while Bluetooth is powered on.
    public let on: Bool
    /// Battery levels for HID peripherals reporting via IOKit.
    public let peripherals: [PeripheralBattery]

    public init(connectedCount: Int, on: Bool, peripherals: [PeripheralBattery] = []) {
        self.connectedCount = connectedCount
        self.on = on
        self.peripherals = peripherals
    }
}

/// Polls Bluetooth status via IOBluetooth.
/// IOBluetooth requires main-thread access, so sampling is dispatched to `@MainActor`.
public final class BluetoothMonitorService: PollingMonitorBase<BluetoothSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<BluetoothSnapshot>.Continuation) async {
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            let (count, on) = await sampleStateOnMain()
            let peripherals = BluetoothMonitorService.samplePeripheralBatteries()
            continuation.yield(BluetoothSnapshot(connectedCount: count, on: on, peripherals: peripherals))
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
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
            if let props = ioProperties(for: service),
               props["Transport"] as? String == "Bluetooth",
               let battery = props["BatteryPercent"] as? Int {
                let name = props["Product"] as? String ?? "Bluetooth Device"
                result.append(PeripheralBattery(name: name, percent: battery))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }

    nonisolated private static func ioProperties(for service: io_service_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
                == KERN_SUCCESS else { return nil }
        return props?.takeRetainedValue() as? [String: Any]
    }
}
