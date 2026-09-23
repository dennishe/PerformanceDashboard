import Foundation
@testable import PerformanceDashboard

@MainActor
final class SynchronousBatcher: UpdateScheduling {
    private var completedUpdates = 0
    private var updateWaiter: CheckedContinuation<Void, Never>?

    func enqueue(owner: AnyObject, update: @escaping () -> Void) {
        update()
        completedUpdates += 1
        updateWaiter?.resume()
        updateWaiter = nil
    }

    func cancel(owner: AnyObject) {}

    func waitForUpdate() async {
        guard completedUpdates == 0 else { return }
        await withCheckedContinuation { updateWaiter = $0 }
    }
}

@MainActor
func waitForAsyncUpdates(cycles: Int = 1) async {
    let settleDelay = Constants.updateCoalescingInterval + .milliseconds(25)
    for _ in 0..<cycles {
        try? await Task.sleep(for: settleDelay)
    }
}

actor MockPeripheralBatteryProvider: PeripheralBatteryProviding {
    private let batteries: [PeripheralBattery]
    private var callCount = 0

    init(batteries: [PeripheralBattery] = []) {
        self.batteries = batteries
    }

    func peripheralBatteries() async -> [PeripheralBattery] {
        callCount += 1
        return batteries
    }

    func recordedCallCount() -> Int {
        callCount
    }
}
