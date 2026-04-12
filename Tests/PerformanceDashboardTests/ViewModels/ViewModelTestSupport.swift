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
