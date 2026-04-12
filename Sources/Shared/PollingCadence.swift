import Foundation

struct PollingScheduler: Sendable {
    typealias Instant = ContinuousClock.Instant

    private let initialDeadlineProvider: @Sendable (Duration) -> Instant
    private let nextDeadlineProvider: @Sendable (Instant, Duration) -> Instant
    private let sleepProvider: @Sendable (Instant) async throws -> Void

    init(
        initialDeadline: @escaping @Sendable (Duration) -> Instant,
        nextDeadline: @escaping @Sendable (Instant, Duration) -> Instant,
        sleepUntil: @escaping @Sendable (Instant) async throws -> Void
    ) {
        initialDeadlineProvider = initialDeadline
        nextDeadlineProvider = nextDeadline
        sleepProvider = sleepUntil
    }

    func initialDeadline(after interval: Duration) -> Instant {
        initialDeadlineProvider(interval)
    }

    func nextDeadline(after deadline: Instant, interval: Duration) -> Instant {
        nextDeadlineProvider(deadline, interval)
    }

    func sleep(until deadline: Instant) async throws {
        try await sleepProvider(deadline)
    }
}

enum PollingCadence {
    static let clock = ContinuousClock()
    static let tolerance: Duration = .milliseconds(25)
    static let live = PollingScheduler(
        initialDeadline: { interval in
            initialDeadline(after: interval)
        },
        nextDeadline: { deadline, interval in
            nextDeadline(after: deadline, interval: interval)
        },
        sleepUntil: { deadline in
            try await sleep(until: deadline)
        }
    )

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
