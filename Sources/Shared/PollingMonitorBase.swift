/// Base class for all production monitor services.
///
/// Override `sample()` to produce one metric snapshot per polling interval.
/// `PollingMonitorBase` owns the async loop, scheduling, lifecycle hooks, and
/// cancellation handling. View models should still inject monitors as
/// `any MetricMonitorProtocol`.
open class PollingMonitorBase<Value: MetricSnapshot>: MetricMonitorProtocol {
    private let scheduler: PollingScheduler
    private var continuation: AsyncStream<Value>.Continuation?
    private var pollingTask: Task<Void, Never>?

    public init() {
        scheduler = PollingCadence.live
    }

    init(scheduler: PollingScheduler) {
        self.scheduler = scheduler
    }

    @MainActor
    public func stream() -> AsyncStream<Value> {
        AsyncStream { continuation in
            self.pollingTask?.cancel()
            self.continuation?.finish()
            self.continuation = continuation
            self.pollingTask = Task {
                await self.runPollingLoop(continuation: continuation)
            }
        }
    }

    @MainActor
    public func stop() {
        pollingTask?.cancel()
        continuation?.finish()
        pollingTask = nil
        continuation = nil
    }

    @MonitorActor
    private func runPollingLoop(continuation: AsyncStream<Value>.Continuation) async {
        setUp()
        defer {
            tearDown()
            continuation.finish()
        }

        let interval = pollingInterval()
        var nextPoll = initialPollDeadline()
        while !Task.isCancelled {
            do {
                try await scheduler.sleep(until: nextPoll)
            } catch {
                break
            }

            if let snapshot = await sample() {
                continuation.yield(snapshot)
            }

            nextPoll = scheduler.nextDeadline(after: nextPoll, interval: interval)
        }
    }

    /// Override to prepare state before the polling loop starts.
    @MonitorActor
    open func setUp() {}

    /// Override to clean up resources after the polling loop stops.
    @MonitorActor
    open func tearDown() {}

    /// Override when a service needs to delay the first sample.
    @MonitorActor
    open func initialPollDeadline() -> ContinuousClock.Instant {
        scheduler.initialDeadline(after: pollingInterval())
    }

    /// Override when a monitor should run at a different cadence than the default dashboard tick.
    @MonitorActor
    open func pollingInterval() -> Duration {
        Constants.pollingInterval
    }

    /// Override to provide one metric snapshot for the current polling tick.
    @MonitorActor
    open func sample() async -> Value? {
        preconditionFailure(
            "\(type(of: self)) must override sample() in PollingMonitorBase"
        )
    }
}
