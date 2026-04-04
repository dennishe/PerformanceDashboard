import Foundation

// MARK: - Generic mock — replaces 12 structurally identical concrete mocks

#if DEBUG

/// Drop-in mock for any `MetricMonitorProtocol` conformance.
/// Set `snapshots` before calling `stream()`; all values are yielded then the stream finishes.
@MainActor
final class MockMonitor<Snapshot: Sendable>: MetricMonitorProtocol {
    var snapshots: [Snapshot]

    init(snapshots: [Snapshot] = []) {
        self.snapshots = snapshots
    }

    func stream() -> AsyncStream<Snapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }

    func stop() {}
}

#endif
