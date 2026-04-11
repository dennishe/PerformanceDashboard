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
open class MonitorViewModelBase<Snapshot: MetricSnapshot> {
    public private(set) var history: [Double] = Constants.prefilledHistory

    /// Up to 900 samples for the 15-minute detail chart.
    public private(set) var extendedHistory: [Double] = []

    private var monitorTask: Task<Void, Never>?
    private let _monitor: any MetricMonitorProtocol<Snapshot>
    private let batcher: any UpdateScheduling

    public init(
        monitor: some MetricMonitorProtocol<Snapshot>,
        batcher: any UpdateScheduling = DashboardUpdateBatcher.shared
    ) {
        _monitor = monitor
        self.batcher = batcher
    }

    public func start() {
        monitorTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in _monitor.stream() {
                batcher.enqueue(owner: self) { [weak self] in
                    self?.receive(snapshot)
                }
            }
        }
    }

    public func stop() {
        monitorTask?.cancel()
        batcher.cancel(owner: self)
        _monitor.stop()
    }

    public var tileModel: MetricTileModel {
        makeTileModel()
    }

    /// Override to update the subclass's observable properties from fresh snapshot data.
    open func receive(_ snapshot: Snapshot) {
        preconditionFailure("\(type(of: self)) must override receive(_:)")
    }

    open func makeTileModel() -> MetricTileModel {
        preconditionFailure("\(type(of: self)) must override makeTileModel()")
    }

    /// Appends `value` to both the sparkline history and the extended detail history.
    func appendHistory(_ value: Double) {
        history = ringBufferAppending(history, value: value, maxCount: Constants.historySamples)
        extendedHistory = ringBufferAppending(
            extendedHistory,
            value: value,
            maxCount: Constants.extendedHistorySamples
        )
    }
}
