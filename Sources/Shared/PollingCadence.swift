import Foundation

enum PollingCadence {
    static let clock = ContinuousClock()
    static let tolerance: Duration = .milliseconds(25)

    static func initialDeadline() -> ContinuousClock.Instant {
        clock.now.advanced(by: Constants.pollingInterval)
    }

    static func nextDeadline(after deadline: ContinuousClock.Instant) -> ContinuousClock.Instant {
        deadline.advanced(by: Constants.pollingInterval)
    }

    static func sleep(until deadline: ContinuousClock.Instant) async throws {
        try await clock.sleep(until: deadline, tolerance: tolerance)
    }
}
