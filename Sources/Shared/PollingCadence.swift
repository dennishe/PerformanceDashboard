import Foundation

enum PollingCadence {
    static let clock = ContinuousClock()
    static let tolerance: Duration = .milliseconds(25)

    static func initialDeadline() -> ContinuousClock.Instant {
        initialDeadline(after: Constants.pollingInterval)
    }

    static func initialDeadline(after interval: Duration) -> ContinuousClock.Instant {
        clock.now.advanced(by: interval)
    }

    static func nextDeadline(after deadline: ContinuousClock.Instant) -> ContinuousClock.Instant {
        nextDeadline(after: deadline, interval: Constants.pollingInterval)
    }

    static func nextDeadline(
        after deadline: ContinuousClock.Instant,
        interval: Duration
    ) -> ContinuousClock.Instant {
        let scheduled = deadline.advanced(by: interval)
        // If the scheduled time is in the past (e.g. after wake from sleep), clamp to now.
        // Without this, every poll that fell asleep during system sleep would return
        // immediately — causing a burst of hundreds of back-to-back samples on wake.
        return scheduled > clock.now ? scheduled : clock.now
    }

    static func sleep(until deadline: ContinuousClock.Instant) async throws {
        try await clock.sleep(until: deadline, tolerance: tolerance)
    }
}
