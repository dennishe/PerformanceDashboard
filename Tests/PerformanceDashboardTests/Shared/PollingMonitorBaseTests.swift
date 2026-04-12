import Foundation
import Testing
@testable import PerformanceDashboard

struct PollingMonitorBaseTests {
    private struct TestSnapshot: MetricSnapshot {
        let value: Int
    }

    private final class SchedulerProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var initialIntervals: [Duration] = []
        private var nextIntervals: [Duration] = []
        private var sleepCallCount = 0

        func makeScheduler() -> PollingScheduler {
            PollingScheduler(
                initialDeadline: { interval in
                    self.recordInitial(interval)
                    return PollingCadence.clock.now
                },
                nextDeadline: { deadline, interval in
                    self.recordNext(interval)
                    return deadline.advanced(by: interval)
                },
                sleepUntil: { _ in
                    let callCount = self.recordSleepCall()
                    if callCount > 1 {
                        try await Task.sleep(for: .seconds(3600))
                    }
                }
            )
        }

        var recordedInitialIntervals: [Duration] {
            lock.withLock { initialIntervals }
        }

        var recordedNextIntervals: [Duration] {
            lock.withLock { nextIntervals }
        }

        var recordedSleepCallCount: Int {
            lock.withLock { sleepCallCount }
        }

        private func recordInitial(_ interval: Duration) {
            lock.withLock {
                initialIntervals.append(interval)
            }
        }

        private func recordNext(_ interval: Duration) {
            lock.withLock {
                nextIntervals.append(interval)
            }
        }

        private func recordSleepCall() -> Int {
            lock.withLock {
                sleepCallCount += 1
                return sleepCallCount
            }
        }
    }

    private final class TestMonitor: PollingMonitorBase<TestSnapshot> {
        private let interval: Duration
        @MonitorActor private(set) var sampleCallCount = 0
        @MonitorActor private(set) var tearDownCallCount = 0

        init(interval: Duration = .milliseconds(10), scheduler: PollingScheduler) {
            self.interval = interval
            super.init(scheduler: scheduler)
        }

        @MonitorActor
        override func pollingInterval() -> Duration {
            interval
        }

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

    @Test @MainActor func stream_emitsFirstSample_fromInjectedScheduler() async {
        let probe = SchedulerProbe()
        let interval: Duration = .milliseconds(10)
        let monitor = TestMonitor(interval: interval, scheduler: probe.makeScheduler())
        var iterator = monitor.stream().makeAsyncIterator()

        let snapshot = await iterator.next()

        #expect(snapshot == TestSnapshot(value: 1))
        #expect(probe.recordedInitialIntervals == [interval])
        #expect(probe.recordedNextIntervals == [interval])
        #expect(probe.recordedSleepCallCount >= 1)
        monitor.stop()
    }

    @Test @MainActor func stop_cancelsBlockedSleep_andRunsTearDown() async {
        let probe = SchedulerProbe()
        let monitor = TestMonitor(scheduler: probe.makeScheduler())
        var iterator = monitor.stream().makeAsyncIterator()

        _ = await iterator.next()
        monitor.stop()
        let finalSnapshot = await iterator.next()

        let sampleCallCount = await monitor.sampleCallCount
        let tearDownCallCount = await monitor.tearDownCallCount
        #expect(finalSnapshot == nil)
        #expect(sampleCallCount == 1)
        #expect(tearDownCallCount == 1)
        #expect(probe.recordedSleepCallCount >= 2)
    }
}
