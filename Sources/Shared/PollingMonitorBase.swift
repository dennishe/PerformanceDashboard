/// Provides the `AsyncStream` lifecycle boilerplate shared by all monitor services.
///
/// Subclasses override `poll(continuation:)` with their metric-specific sampling logic
/// and are otherwise free from boilerplate. Complies with OCP: new metrics are added by
/// subclassing, never by modifying this type.
open class PollingMonitorBase<Value: Sendable>: MetricMonitorProtocol {
    private var continuation: AsyncStream<Value>.Continuation?
    private var pollingTask: Task<Void, Never>?

    public init() {}

    @MainActor
    public func stream() -> AsyncStream<Value> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.pollingTask = Task {
                await self.poll(continuation: continuation)
            }
        }
    }

    @MainActor
    public func stop() {
        pollingTask?.cancel()
        continuation?.finish()
    }

    /// Override to provide metric-specific sampling logic.
    /// The loop, sleep, and cancellation check live here in each subclass.
    @MonitorActor
    open func poll(continuation: AsyncStream<Value>.Continuation) async {
        preconditionFailure("\(type(of: self)) must override poll(continuation:)")
    }
}
