import Foundation

/// Snapshot of disk usage for the boot volume.
public struct DiskSnapshot: Sendable {
    /// Used capacity as a fraction in [0, 1].
    public let usage: Double
    /// Total capacity in bytes.
    public let total: Int64
    /// Available bytes.
    public let available: Int64
}

/// Monitors boot-volume disk usage via `URLResourceValues`.
public final class DiskMonitorService: PollingMonitorBase<DiskSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<DiskSnapshot>.Continuation) async {
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            if let snapshot = DiskMonitorService.sample() {
                continuation.yield(snapshot)
            }
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
    }

    nonisolated static func sample() -> DiskSnapshot? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]),
        let total = values.volumeTotalCapacity,
        let available = values.volumeAvailableCapacity else { return nil }

        let used = Int64(total) - Int64(available)
        let usage = total > 0 ? Double(used) / Double(total) : 0
        return DiskSnapshot(usage: usage, total: Int64(total), available: Int64(available))
    }
}
