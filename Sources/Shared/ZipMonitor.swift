import Foundation

@MainActor
public final class ZipMonitor<Left: MetricSnapshot, Right: MetricSnapshot, Merged: MetricSnapshot>:
    MetricMonitorProtocol {
    private let left: any MetricMonitorProtocol<Left>
    private let right: any MetricMonitorProtocol<Right>
    private let merge: @Sendable (Left, Right) -> Merged

    private var leftTask: Task<Void, Never>?
    private var rightTask: Task<Void, Never>?
    private var continuation: AsyncStream<Merged>.Continuation?
    private var latestLeft: Left?
    private var latestRight: Right?
    private var completedStreams = 0

    public init(
        left: some MetricMonitorProtocol<Left>,
        right: some MetricMonitorProtocol<Right>,
        merge: @escaping @Sendable (Left, Right) -> Merged
    ) {
        self.left = left
        self.right = right
        self.merge = merge
    }

    public func stream() -> AsyncStream<Merged> {
        leftTask?.cancel()
        rightTask?.cancel()
        latestLeft = nil
        latestRight = nil
        completedStreams = 0

        let leftStream = left.stream()
        let rightStream = right.stream()

        return AsyncStream { continuation in
            self.continuation = continuation
            leftTask = Task { [weak self] in
                guard let self else { return }
                for await snapshot in leftStream {
                    await receiveLeft(snapshot)
                }
                await upstreamFinished()
            }
            rightTask = Task { [weak self] in
                guard let self else { return }
                for await snapshot in rightStream {
                    await receiveRight(snapshot)
                }
                await upstreamFinished()
            }
        }
    }

    public func stop() {
        leftTask?.cancel()
        rightTask?.cancel()
        continuation?.finish()
        continuation = nil
        left.stop()
        right.stop()
    }

    private func receiveLeft(_ snapshot: Left) {
        latestLeft = snapshot
        emitIfPossible()
    }

    private func receiveRight(_ snapshot: Right) {
        latestRight = snapshot
        emitIfPossible()
    }

    private func emitIfPossible() {
        guard let latestLeft, let latestRight else { return }
        continuation?.yield(merge(latestLeft, latestRight))
    }

    private func upstreamFinished() {
        completedStreams += 1
        if completedStreams == 2 {
            continuation?.finish()
            continuation = nil
        }
    }
}
