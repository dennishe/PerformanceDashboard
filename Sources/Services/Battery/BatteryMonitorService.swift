import Foundation
import IOKit
import IOKit.ps

/// Snapshot of battery and power-source state.
public struct BatterySnapshot: Sendable {
    /// `false` on desktop Macs with no internal battery.
    public let isPresent: Bool
    /// Charge level in [0, 1]. 0 on desktop Macs.
    public let chargeFraction: Double
    /// `true` while the battery is actively charging.
    public let isCharging: Bool
    /// `true` when running on AC (wall power).
    public let onAC: Bool
    /// Estimated minutes until empty; `nil` when on AC or unknown.
    public let timeToEmptyMinutes: Int?
    /// Total full-charge cycles; `nil` when unavailable or no battery.
    public let cycleCount: Int?
    /// Current max capacity / design capacity, as a fraction in [0, 1]; `nil` when unavailable.
    public let healthFraction: Double?
}

/// Monitors battery and power source via the public IOPS API + IORegistry.
public final class BatteryMonitorService: PollingMonitorBase<BatterySnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<BatterySnapshot>.Continuation) async {
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            continuation.yield(BatteryMonitorService.sample())
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
    }

    // MARK: - Sampling

    nonisolated static func sample() -> BatterySnapshot {
        guard let psInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(psInfo)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty,
              let descRef = IOPSGetPowerSourceDescription(psInfo, sources[0]),
              let desc = descRef.takeUnretainedValue() as? [String: Any]
        else {
            return BatterySnapshot(
                isPresent: false, chargeFraction: 0, isCharging: false,
                onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
            )
        }

        let isPresent = desc[kIOPSIsPresentKey] as? Bool ?? false
        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCap = max(desc[kIOPSMaxCapacityKey] as? Int ?? 1, 1)
        let chargeFraction = Double(current) / Double(maxCap)
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let state = desc[kIOPSPowerSourceStateKey] as? String
        let onAC = state == kIOPSACPowerValue
        let tte = desc[kIOPSTimeToEmptyKey] as? Int

        let (cycleCount, healthFraction) = ioRegistryBatteryInfo()

        return BatterySnapshot(
            isPresent: isPresent,
            chargeFraction: chargeFraction,
            isCharging: isCharging,
            onAC: onAC,
            timeToEmptyMinutes: (tte ?? 0) > 0 ? tte : nil,
            cycleCount: cycleCount,
            healthFraction: healthFraction
        )
    }

    /// Reads `CycleCount` and `DesignCapacity` from the IORegistry `AppleSmartBattery` node.
    nonisolated private static func ioRegistryBatteryInfo() -> (cycleCount: Int?, health: Double?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any]
        else { return (nil, nil) }

        let cycles = dict["CycleCount"] as? Int
        let designCap = dict["DesignCapacity"] as? Int
        let currentMax = dict["MaxCapacity"] as? Int
        var health: Double?
        if let designCap, let currentMax, designCap > 0 {
            health = min(1.0, Double(currentMax) / Double(designCap))
        }
        return (cycles, health)
    }
}
