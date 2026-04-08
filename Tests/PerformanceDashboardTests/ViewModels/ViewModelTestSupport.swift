import Foundation

@MainActor
func waitForAsyncUpdates(cycles: Int = 1) async {
    for _ in 0..<cycles {
        try? await Task.sleep(for: .milliseconds(50))
    }
}
