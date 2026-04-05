import Foundation
import IOKit
import IOKit.graphics

/// Snapshot of GPU utilisation at a point in time.
public struct GPUSnapshot: Sendable {
    /// GPU utilisation as a fraction in [0, 1]. `nil` if unavailable.
    public let usage: Double?
}

/// Monitors GPU utilisation via IOKit `PerformanceStatistics`.
public final class GPUMonitorService: PollingMonitorBase<GPUSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<GPUSnapshot>.Continuation) async {
        var session = GPURegistrySession()
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            let usage = session?.sampleUsage()
            if usage == nil {
                session = GPURegistrySession()
            }
            continuation.yield(GPUSnapshot(usage: usage))
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
    }

    nonisolated static func sample() -> Double? {
        GPURegistrySession()?.sampleUsage()
    }
}

private final class GPURegistrySession {
    private static let utilizationKey = "Device Utilization %"

    private let services: [io_registry_entry_t]

    init?() {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var matchedServices: [io_registry_entry_t] = []
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            matchedServices.append(service)
            service = IOIteratorNext(iterator)
        }

        guard !matchedServices.isEmpty else { return nil }
        services = matchedServices
    }

    deinit {
        services.forEach { service in
            IOObjectRelease(service)
        }
    }

    func sampleUsage() -> Double? {
        let performanceStatisticsKey = "PerformanceStatistics" as CFString
        var totalUsage: Double = 0
        var count = 0

        for service in services {
            guard
                let property = IORegistryEntryCreateCFProperty(
                    service,
                    performanceStatisticsKey,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue(),
                let stats = property as? [String: AnyObject],
                let deviceUtil = stats[Self.utilizationKey] as? NSNumber
            else {
                continue
            }
            totalUsage += deviceUtil.doubleValue / 100.0
            count += 1
        }

        guard count > 0 else { return nil }
        return totalUsage / Double(count)
    }
}
