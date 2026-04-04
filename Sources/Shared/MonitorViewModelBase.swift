import SwiftUI

/// Base class for all metric view models.
///
/// Handles the stream subscription lifecycle (`start`, `stop`), history ring-buffer,
/// and the monitor reference. Subclasses override `receive(_:)` to update their
/// own `@Observable` properties and call `appendHistory(_:)` for the sparkline.
///
/// Complies with OCP: new metrics add a subclass and never touch this type.
@MainActor
@Observable
open class MonitorViewModelBase<Snapshot: Sendable> {
    public private(set) var history: [Double] = []

    private var monitorTask: Task<Void, Never>?
    private let _monitor: any MetricMonitorProtocol<Snapshot>

    public init(monitor: some MetricMonitorProtocol<Snapshot>) {
        _monitor = monitor
    }

    public func start() {
        monitorTask = Task {
            for await snapshot in _monitor.stream() {
                receive(snapshot)
            }
        }
    }

    public func stop() {
        monitorTask?.cancel()
        _monitor.stop()
    }

    /// Override to update the subclass's observable properties from fresh snapshot data.
    open func receive(_ snapshot: Snapshot) {
        preconditionFailure("\(type(of: self)) must override receive(_:)")
    }

    /// Appends `value` to the sparkline history and trims to `Constants.historySamples`.
    func appendHistory(_ value: Double) {
        history.append(value)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
