import Foundation

/// Marker protocol for all monitor snapshots.
///
/// A `nil` field means the metric is unavailable on this hardware.
/// A zero value means the hardware is available and the current reading is zero.
public protocol MetricSnapshot: Sendable, Equatable {}

/// Injection protocol for monitors used by view models, previews, and tests.
///
/// Production services should inherit from `PollingMonitorBase` rather than
/// conforming to this protocol directly.
@MainActor
public protocol MetricMonitorProtocol<Value>: AnyObject {
    associatedtype Value: MetricSnapshot

    /// Starts continuous polling and emits snapshots via the returned `AsyncStream`.
    func stream() -> AsyncStream<Value>

    /// Stops polling and releases any held resources.
    func stop()
}
