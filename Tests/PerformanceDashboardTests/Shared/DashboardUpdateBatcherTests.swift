import Testing
@testable import PerformanceDashboard

@MainActor
struct DashboardUpdateBatcherTests {
    private final class Owner {}

    @Test func enqueue_flushesPendingUpdatesAfterDelay() async {
        let batcher = DashboardUpdateBatcher(flushDelay: .milliseconds(5))
        let owner = Owner()
        var updates: [Int] = []

        batcher.enqueue(owner: owner) { updates.append(1) }
        batcher.enqueue(owner: owner) { updates.append(2) }

        #expect(updates.isEmpty)

        try? await Task.sleep(for: .milliseconds(20))

        #expect(updates == [1, 2])
    }

    @Test func cancel_discardsPendingUpdates() async {
        let batcher = DashboardUpdateBatcher(flushDelay: .milliseconds(5))
        let owner = Owner()
        var ranUpdate = false

        batcher.enqueue(owner: owner) { ranUpdate = true }
        batcher.cancel(owner: owner)

        try? await Task.sleep(for: .milliseconds(20))

        #expect(ranUpdate == false)
    }
}
