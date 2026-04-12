import AppKit

@MainActor
protocol RingGaugeAnimationTicking: AnyObject {
    func ringGaugeAnimationDidTick(at timestamp: CFTimeInterval)
}

@MainActor
final class RingGaugeAnimationDriver: NSObject {
    static let shared = RingGaugeAnimationDriver(automaticallySchedulesTimer: true)

    private static let targetFramesPerSecond: TimeInterval = 30
    private static let frameInterval = 1.0 / targetFramesPerSecond
    private static let timerTolerance = frameInterval * 0.25

    private struct WeakListener {
        weak var object: AnyObject?

        init(_ listener: RingGaugeAnimationTicking) {
            object = listener
        }

        var value: (any RingGaugeAnimationTicking)? {
            object as? any RingGaugeAnimationTicking
        }

        func references(_ listener: RingGaugeAnimationTicking) -> Bool {
            object === listener
        }
    }

    private let automaticallySchedulesTimer: Bool
    private var listeners: [WeakListener] = []
    private var timer: Timer?

    private init(automaticallySchedulesTimer: Bool) {
        self.automaticallySchedulesTimer = automaticallySchedulesTimer
        super.init()
    }

    static func makeForTesting() -> RingGaugeAnimationDriver {
        RingGaugeAnimationDriver(automaticallySchedulesTimer: false)
    }

    func add(_ listener: RingGaugeAnimationTicking) {
        compactListeners()
        guard !listeners.contains(where: { $0.references(listener) }) else { return }

        listeners.append(WeakListener(listener))
        if automaticallySchedulesTimer {
            ensureTimer()
        }
    }

    func remove(_ listener: RingGaugeAnimationTicking) {
        listeners.removeAll { weakListener in
            weakListener.object == nil || weakListener.references(listener)
        }
        stopTimerIfIdle()
    }

    private func ensureTimer() {
        guard timer == nil else { return }

        let timer = Timer(
            timeInterval: Self.frameInterval,
            target: self,
            selector: #selector(handleTimerFire(_:)),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = Self.timerTolerance
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func handleTimerFire(_ timer: Timer) {
        tick(at: CACurrentMediaTime())
    }

    func tick(at timestamp: CFTimeInterval) {
        for listener in listenerSnapshot() {
            listener.ringGaugeAnimationDidTick(at: timestamp)
        }
        stopTimerIfIdle()
    }

    private func stopTimerIfIdle() {
        compactListeners()
        guard listeners.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }

    private func listenerSnapshot() -> [any RingGaugeAnimationTicking] {
        compactListeners()
        return listeners.compactMap(\ .value)
    }

    private func compactListeners() {
        listeners.removeAll { $0.object == nil }
    }
}
