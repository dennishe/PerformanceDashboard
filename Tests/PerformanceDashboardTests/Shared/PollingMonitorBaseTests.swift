import Testing
@testable import PerformanceDashboard

struct PollingMonitorBaseTests {
    private struct TestSnapshot: MetricSnapshot {
        let value: Int
    }

    private final class TestMonitor: PollingMonitorBase<TestSnapshot> {
        @MonitorActor private(set) var sampleCallCount = 0
        @MonitorActor private(set) var tearDownCallCount = 0

        @MonitorActor
        override func sample() async -> TestSnapshot? {
            sampleCallCount += 1
            return sampleCallCount == 1 ? TestSnapshot(value: sampleCallCount) : nil
        }

        @MonitorActor
        override func tearDown() {
            tearDownCallCount += 1
        }
    }

    @Test @MainActor func stream_emitsFirstSample_fromSharedLoop() async {
        let monitor = TestMonitor()
        var iterator = monitor.stream().makeAsyncIterator()

        let snapshot = await iterator.next()

        #expect(snapshot == TestSnapshot(value: 1))
        monitor.stop()
    }

    @Test @MainActor func stop_cancelsLoop_andRunsTearDown() async {
        let monitor = TestMonitor()
        var iterator = monitor.stream().makeAsyncIterator()

        _ = await iterator.next()
        monitor.stop()
        await waitForAsyncUpdates()

        let sampleCallCount = await monitor.sampleCallCount
        let tearDownCallCount = await monitor.tearDownCallCount
        #expect(sampleCallCount >= 1)
        #expect(tearDownCallCount == 1)
    }
}
