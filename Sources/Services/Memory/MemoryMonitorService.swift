import Darwin
import Foundation

/// Snapshot of system memory at a point in time.
public struct MemorySnapshot: Sendable {
    /// Used memory as a fraction in [0, 1].
    public let usage: Double
    /// Total physical memory in bytes.
    public let total: UInt64
    /// Used memory in bytes (active + wired + compressed).
    public let used: UInt64
}

/// Monitors memory pressure via `host_statistics64`.
public final class MemoryMonitorService: PollingMonitorBase<MemorySnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<MemorySnapshot>.Continuation) async {
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            if let snapshot = MemoryMonitorService.sample() {
                continuation.yield(snapshot)
            }
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
    }

    nonisolated static func sample() -> MemorySnapshot? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let total = ProcessInfo.processInfo.physicalMemory
        let used = (UInt64(stats.active_count) +
                    UInt64(stats.wire_count) +
                    UInt64(stats.compressor_page_count)) * pageSize
        let usage = total > 0 ? Double(used) / Double(total) : 0
        return MemorySnapshot(usage: usage, total: total, used: used)
    }
}
