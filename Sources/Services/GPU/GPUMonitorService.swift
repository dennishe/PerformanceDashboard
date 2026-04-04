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
        while !Task.isCancelled {
            continuation.yield(GPUSnapshot(usage: GPUMonitorService.sample()))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    nonisolated static func sample() -> Double? {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalUsage: Double = 0
        var count = 0
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: AnyObject],
                  let stats = dict["PerformanceStatistics"] as? [String: AnyObject],
                  let deviceUtil = stats["Device Utilization %"] as? NSNumber else { continue }
            totalUsage += deviceUtil.doubleValue / 100.0
            count += 1
        }
        guard count > 0 else { return nil }
        return totalUsage / Double(count)
    }
}
