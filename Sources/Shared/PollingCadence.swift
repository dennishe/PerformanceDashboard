import Foundation

enum PollingCadence {
    static let clock = ContinuousClock()
    static let tolerance: Duration = .milliseconds(25)

    static func initialDeadline() -> ContinuousClock.Instant {
        clock.now.advanced(by: Constants.pollingInterval)
    }

    static func nextDeadline(after deadline: ContinuousClock.Instant) -> ContinuousClock.Instant {
        let scheduled = deadline.advanced(by: Constants.pollingInterval)
        // If the scheduled time is in the past (e.g. after wake from sleep), clamp to now.
        // Without this, every poll that fell asleep during system sleep would return
        // immediately — causing a burst of hundreds of back-to-back samples on wake.
        return scheduled > clock.now ? scheduled : clock.now
    }

    static func sleep(until deadline: ContinuousClock.Instant) async throws {
        try await clock.sleep(until: deadline, tolerance: tolerance)
    }
}
