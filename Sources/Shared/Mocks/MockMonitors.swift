import Foundation

// MARK: - Generic mock — replaces 12 structurally identical concrete mocks

#if DEBUG

/// Drop-in mock for any `MetricMonitorProtocol` conformance.
/// Set `snapshots` before calling `stream()`; all values are yielded then the stream finishes.
@MainActor
final class MockMonitor<Snapshot: MetricSnapshot>: MetricMonitorProtocol {
    var snapshots: [Snapshot]
    private(set) var streamCallCount = 0
    private(set) var stopCallCount = 0

    init(snapshots: [Snapshot] = []) {
        self.snapshots = snapshots
    }

    func stream() -> AsyncStream<Snapshot> {
        streamCallCount += 1
        return AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }

    func stop() {
        stopCallCount += 1
    }
}

#endif
