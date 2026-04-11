import Testing
@testable import PerformanceDashboard

@MainActor
struct ZipMonitorTests {
    private struct LeftSnapshot: MetricSnapshot {
        let value: Int
    }

    private struct RightSnapshot: MetricSnapshot {
        let value: String
    }

    private struct CombinedSnapshot: MetricSnapshot {
        let leftValue: Int
        let rightValue: String
    }

    private final class PushMonitor<Value: MetricSnapshot>: MetricMonitorProtocol {
        private var continuation: AsyncStream<Value>.Continuation?
        private(set) var stopCallCount = 0

        func stream() -> AsyncStream<Value> {
            AsyncStream { continuation in
                self.continuation = continuation
            }
        }

        func stop() {
            stopCallCount += 1
            continuation?.finish()
        }

        func send(_ value: Value) {
            continuation?.yield(value)
        }
    }

    @Test func bothSides_contributeToMergedOutput() async {
        let left = PushMonitor<LeftSnapshot>()
        let right = PushMonitor<RightSnapshot>()
        let monitor = ZipMonitor(left: left, right: right) { left, right in
            CombinedSnapshot(leftValue: left.value, rightValue: right.value)
        }

        let stream = monitor.stream()
        var iterator = stream.makeAsyncIterator()

        left.send(LeftSnapshot(value: 1))
        right.send(RightSnapshot(value: "A"))

        let first = await iterator.next()
        #expect(first == CombinedSnapshot(leftValue: 1, rightValue: "A"))
    }

    @Test func fastSide_reemitsWithLatestSlowValue() async {
        let left = PushMonitor<LeftSnapshot>()
        let right = PushMonitor<RightSnapshot>()
        let monitor = ZipMonitor(left: left, right: right) { left, right in
            CombinedSnapshot(leftValue: left.value, rightValue: right.value)
        }

        let stream = monitor.stream()
        var iterator = stream.makeAsyncIterator()

        left.send(LeftSnapshot(value: 1))
        right.send(RightSnapshot(value: "A"))
        _ = await iterator.next()

        left.send(LeftSnapshot(value: 2))

        let second = await iterator.next()
        #expect(second == CombinedSnapshot(leftValue: 2, rightValue: "A"))

        monitor.stop()
        #expect(left.stopCallCount == 1)
        #expect(right.stopCallCount == 1)
    }
}
