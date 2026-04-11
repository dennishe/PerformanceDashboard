import Foundation
import IOBluetooth
import ObjectiveC

public protocol PeripheralBatteryProviding: Sendable {
    func peripheralBatteries() async -> [PeripheralBattery]
}

public actor BluetoothPeripheralBatteryProvider: PeripheralBatteryProviding {
    public init() {}

    public func peripheralBatteries() async -> [PeripheralBattery] {
        let hidBatteries = await Self.readHIDPeripheralBatteries()
        let runtimeBatteries = await MainActor.run {
            Self.readConnectedDeviceBatteries()
        }
        return Self.merge(hidBatteries: hidBatteries, runtimeBatteries: runtimeBatteries)
    }

    @MonitorActor
    private static func readHIDPeripheralBatteries() -> [PeripheralBattery] {
        BluetoothMonitorService.samplePeripheralBatteries()
    }

    private static func readConnectedDeviceBatteries() -> [PeripheralBattery] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
            .filter { $0.isConnected() }

        return devices.flatMap(Self.makeRuntimeBatteries(for:))
    }

    private static func makeRuntimeBatteries(for device: IOBluetoothDevice) -> [PeripheralBattery] {
        let name = device.nameOrAddress ?? "Bluetooth Device"
        let object = device as NSObject

        let single = selectorIntValue("batteryPercentSingle", on: object)
        let combined = selectorIntValue("batteryPercentCombined", on: object)
        let left = selectorIntValue("batteryPercentLeft", on: object)
        let right = selectorIntValue("batteryPercentRight", on: object)
        let chargingCase = selectorIntValue("batteryPercentCase", on: object)

        let componentBatteries = [
            makeBattery(name: name + " (Left)", percent: left),
            makeBattery(name: name + " (Right)", percent: right),
            makeBattery(name: name + " (Case)", percent: chargingCase)
        ].compactMap { $0 }

        if !componentBatteries.isEmpty {
            return componentBatteries
        }

        if let singleBattery = makeBattery(name: name, percent: single) {
            return [singleBattery]
        }

        if let combinedBattery = makeBattery(name: name, percent: combined) {
            return [combinedBattery]
        }

        return []
    }

    private static func makeBattery(name: String, percent: Int?) -> PeripheralBattery? {
        guard let percent, percent > 0 else { return nil }
        return PeripheralBattery(name: name, percent: min(percent, 100))
    }

    private static func selectorIntValue(_ selectorName: String, on object: NSObject) -> Int? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector),
              let method = class_getInstanceMethod(type(of: object), selector) else {
            return nil
        }

        typealias IntGetter = @convention(c) (AnyObject, Selector) -> Int
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: IntGetter.self)
        return function(object, selector)
    }

    static func merge(
        hidBatteries: [PeripheralBattery],
        runtimeBatteries: [PeripheralBattery]
    ) -> [PeripheralBattery] {
        var mergedByName: [String: PeripheralBattery] = [:]

        runtimeBatteries.forEach { battery in
            mergedByName[battery.name] = battery
        }

        hidBatteries.forEach { battery in
            mergedByName[battery.name] = battery
        }

        return mergedByName.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
