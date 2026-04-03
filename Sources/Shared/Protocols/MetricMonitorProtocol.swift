import Foundation

/// The single protocol every monitor service must conform to.
///
/// - `Value`: The snapshot type produced on each poll (e.g. `Double` for CPU %).
@MainActor
public protocol MetricMonitorProtocol<Value>: AnyObject {
    associatedtype Value: Sendable

    /// Starts continuous polling and emits snapshots via the returned `AsyncStream`.
    func stream() -> AsyncStream<Value>

    /// Stops polling and releases any held resources.
    func stop()
}
