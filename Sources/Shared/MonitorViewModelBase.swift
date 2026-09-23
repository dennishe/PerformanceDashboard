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
    private var storedTileModel: MetricTileModel?

    private var monitorTask: Task<Void, Never>?
    private let _monitor: any MetricMonitorProtocol<Snapshot>
    private let batcher: any UpdateScheduling
    #if DEBUG
    @ObservationIgnored private var appliedUpdateCount = 0
    @ObservationIgnored private var updateWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    #endif

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
        storedTileModel ?? makeTileModel()
    }

    /// Override to update the subclass's observable properties from fresh snapshot data.
    open func receive(_ snapshot: Snapshot) {
        preconditionFailure("\(type(of: self)) must override receive(_:)")
    }

    open func makeTileModel() -> MetricTileModel {
        preconditionFailure("\(type(of: self)) must override makeTileModel()")
    }

    func refreshTileModel() {
        storedTileModel = makeTileModel()
        #if DEBUG
        appliedUpdateCount += 1
        guard !updateWaiters.isEmpty else { return }
        let ready = updateWaiters.filter { $0.0 <= appliedUpdateCount }
        updateWaiters.removeAll { $0.0 <= appliedUpdateCount }
        ready.forEach { $0.1.resume() }
        #endif
    }

    #if DEBUG
    func waitForUpdates(atLeast count: Int = 1) async {
        guard appliedUpdateCount < count else { return }
        await withCheckedContinuation { updateWaiters.append((count, $0)) }
    }
    #endif

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
