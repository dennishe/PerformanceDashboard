import Foundation
@testable import PerformanceDashboard

@MainActor
final class SynchronousBatcher: UpdateScheduling {
    func enqueue(owner: AnyObject, update: @escaping () -> Void) {
        update()
    }

    func cancel(owner: AnyObject) {}
}

@MainActor
func waitForAsyncUpdates(cycles: Int = 1) async {
    for _ in 0..<cycles {
        try? await Task.sleep(for: .milliseconds(50))
    }
}
