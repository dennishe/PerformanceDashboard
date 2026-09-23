import Darwin
import Foundation

/// Reads SoC die temperatures from HID PMU sensors when SMC CPU keys are absent.
@MonitorActor
final class HIDDieTemperatureReader {
    private typealias Create = @convention(c) (CFAllocator?, Int32) -> UnsafeMutableRawPointer?
    private typealias Services = @convention(c) (UnsafeMutableRawPointer) -> Unmanaged<CFArray>?
    private typealias Property = @convention(c) (
        UnsafeMutableRawPointer, CFString
    ) -> Unmanaged<CFTypeRef>?
    private typealias Event = @convention(c) (
        UnsafeMutableRawPointer, Int64, CFDictionary?, Int64
    ) -> Unmanaged<CFTypeRef>?
    private typealias Value = @convention(c) (CFTypeRef, Int32) -> Double

    nonisolated(unsafe) private let library: UnsafeMutableRawPointer
    nonisolated(unsafe) private let client: UnsafeMutableRawPointer
    private let services: [AnyObject]
    private let dieSensors: [UnsafeMutableRawPointer]
    private let copyEvent: Event
    private let floatValue: Value

    init?() {
        guard let library = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return nil }
        guard let createSymbol = dlsym(library, "IOHIDEventSystemClientCreate"),
              let servicesSymbol = dlsym(library, "IOHIDEventSystemClientCopyServices"),
              let propertySymbol = dlsym(library, "IOHIDServiceClientCopyProperty"),
              let eventSymbol = dlsym(library, "IOHIDServiceClientCopyEvent"),
              let valueSymbol = dlsym(library, "IOHIDEventGetFloatValue"),
              let client = unsafeBitCast(createSymbol, to: Create.self)(nil, 0) else {
            dlclose(library)
            return nil
        }
        guard let services = unsafeBitCast(servicesSymbol, to: Services.self)(client)?
            .takeRetainedValue() as? [AnyObject] else {
            Unmanaged<AnyObject>.fromOpaque(client).release()
            dlclose(library)
            return nil
        }
        let property = unsafeBitCast(propertySymbol, to: Property.self)
        let dieSensors = services.compactMap { service -> UnsafeMutableRawPointer? in
            let pointer = Unmanaged.passUnretained(service).toOpaque()
            let name = property(pointer, "Product" as CFString)?.takeRetainedValue() as? String
            return name?.hasPrefix("PMU tdie") == true ? pointer : nil
        }
        guard !dieSensors.isEmpty else {
            Unmanaged<AnyObject>.fromOpaque(client).release()
            dlclose(library)
            return nil
        }
        self.library = library
        self.client = client
        self.services = services
        self.dieSensors = dieSensors
        copyEvent = unsafeBitCast(eventSymbol, to: Event.self)
        floatValue = unsafeBitCast(valueSymbol, to: Value.self)
    }

    deinit {
        Unmanaged<AnyObject>.fromOpaque(client).release()
        dlclose(library)
    }

    func hottestDieCelsius() -> Double? {
        let values = dieSensors.compactMap { sensor -> Double? in
            guard let event = copyEvent(sensor, 15, nil, 0)?.takeRetainedValue() else { return nil }
            return floatValue(event, 15 << 16)
        }
        return Self.hottestValidTemperature(values)
    }

    nonisolated static func hottestValidTemperature(_ values: [Double]) -> Double? {
        values.filter { $0.isFinite && (20...125).contains($0) }.max()
    }
}
