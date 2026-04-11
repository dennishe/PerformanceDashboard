import AppKit

@MainActor
protocol RingGaugeAnimationTicking: AnyObject {
    func ringGaugeAnimationDidTick(at timestamp: CFTimeInterval)
}

@MainActor
final class RingGaugeAnimationDriver {
    static let shared = RingGaugeAnimationDriver()

    private let listeners = NSHashTable<AnyObject>.weakObjects()
    private var timer: Timer?

    private init() {}

    func add(_ listener: RingGaugeAnimationTicking) {
        listeners.add(listener)
        ensureTimer()
    }

    func remove(_ listener: RingGaugeAnimationTicking) {
        listeners.remove(listener)
        stopTimerIfIdle()
    }

    private func ensureTimer() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let timestamp = CACurrentMediaTime()
        let activeListeners = listeners.allObjects.compactMap { $0 as? RingGaugeAnimationTicking }
        for listener in activeListeners {
            listener.ringGaugeAnimationDidTick(at: timestamp)
        }
        stopTimerIfIdle()
    }

    private func stopTimerIfIdle() {
        guard listeners.allObjects.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }
}
