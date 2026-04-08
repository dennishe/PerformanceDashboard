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
    @ObservationIgnored
    public private(set) var history: [Double] = Constants.prefilledHistory

    /// Up to 900 samples for the 15-minute detail chart.
    @ObservationIgnored
    public private(set) var extendedHistory: [Double] = []

    private var monitorTask: Task<Void, Never>?
    private let _monitor: any MetricMonitorProtocol<Snapshot>

    public init(monitor: some MetricMonitorProtocol<Snapshot>) {
        _monitor = monitor
    }

    public func start() {
        monitorTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in _monitor.stream() {
                DashboardUpdateBatcher.shared.enqueue(owner: self) { [weak self] in
                    self?.receive(snapshot)
                }
            }
        }
    }

    public func stop() {
        monitorTask?.cancel()
        DashboardUpdateBatcher.shared.cancel(owner: self)
        _monitor.stop()
    }

    /// Override to update the subclass's observable properties from fresh snapshot data.
    open func receive(_ snapshot: Snapshot) {
        preconditionFailure("\(type(of: self)) must override receive(_:)")
    }

    /// Appends `value` to both the sparkline history and the extended detail history.
    func appendHistory(_ value: Double) {
        history = Self.appendRingBuffer(history, value: value, maxCount: Constants.historySamples)
        extendedHistory = Self.appendRingBuffer(extendedHistory, value: value,
                                                maxCount: Constants.extendedHistorySamples)
    }

    private static func appendRingBuffer(_ buffer: [Double], value: Double, maxCount: Int) -> [Double] {
        var updated = buffer
        updated.append(value)
        if updated.count > maxCount {
            updated.removeFirst(updated.count - maxCount)
        }
        return updated
    }
}
