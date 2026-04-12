import AppKit
import Testing
@testable import PerformanceDashboard

@MainActor
struct RingGaugeAnimationDriverTests {
    @Test func tick_deliversToRemainingListeners_whenEarlierListenerRemovesItself() {
        let driver = RingGaugeAnimationDriver.makeForTesting()
        let remover = SelfRemovingListener(driver: driver)
        let survivor = RecordingListener()

        driver.add(remover)
        driver.add(survivor)

        driver.tick(at: 12)
        driver.tick(at: 24)

        #expect(remover.timestamps == [12])
        #expect(survivor.timestamps == [12, 24])
    }

    @Test func atlasHostingView_reachesFinalFrame_whenEarlierListenerStopsDuringFinalTick() {
        let driver = RingGaugeAnimationDriver.makeForTesting()
        let startTime: CFTimeInterval = 100
        let style = RingGaugeStyle(color: .normal, displayScale: 2, profile: .standard)
        let firstGauge = AtlasRingGaugeHostingView(
            frame: .zero,
            animationDriver: driver,
            currentTimestamp: { startTime }
        )
        let secondGauge = AtlasRingGaugeHostingView(
            frame: .zero,
            animationDriver: driver,
            currentTimestamp: { startTime }
        )

        firstGauge.update(value: 0.25, style: style)
        secondGauge.update(value: 0.72, style: style)

        driver.tick(at: startTime + RingGaugeLayerSupport.animationDuration + 0.001)

        #expect(firstGauge.renderedFrameIndex == firstGauge.destinationFrameIndex)
        #expect(secondGauge.renderedFrameIndex == secondGauge.destinationFrameIndex)
        #expect(!firstGauge.isAnimatingForTesting)
        #expect(!secondGauge.isAnimatingForTesting)
    }
}

@MainActor
private final class RecordingListener: RingGaugeAnimationTicking {
    private(set) var timestamps: [CFTimeInterval] = []

    func ringGaugeAnimationDidTick(at timestamp: CFTimeInterval) {
        timestamps.append(timestamp)
    }
}

@MainActor
private final class SelfRemovingListener: RingGaugeAnimationTicking {
    private let driver: RingGaugeAnimationDriver
    private(set) var timestamps: [CFTimeInterval] = []

    init(driver: RingGaugeAnimationDriver) {
        self.driver = driver
    }

    func ringGaugeAnimationDidTick(at timestamp: CFTimeInterval) {
        timestamps.append(timestamp)
        driver.remove(self)
    }
}
