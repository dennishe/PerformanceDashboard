import Testing
@testable import PerformanceDashboard

struct FanMonitorServiceTests {

    // MARK: - FanReading

    @Test func fanReading_fraction_isCorrectForNormalSpeed() {
        let fan = FanReading(current: 3000, max: 6000)
        #expect(abs(fan.fraction - 0.5) < 0.001)
    }

    @Test func fanReading_fraction_isZero_whenMaxIsZero() {
        let fan = FanReading(current: 1000, max: 0)
        #expect(fan.fraction == 0)
    }

    @Test func fanReading_fraction_capsAtOne_whenCurrentExceedsMax() {
        let fan = FanReading(current: 10000, max: 6000)
        #expect(fan.fraction == 1.0)
    }

    @Test func fanReading_fraction_isZero_whenCurrentIsZero() {
        let fan = FanReading(current: 0, max: 6000)
        #expect(fan.fraction == 0)
    }

    // MARK: - FanSnapshot

    @Test func fanSnapshot_storesAllFans() {
        let fans = [
            FanReading(current: 1200, max: 6000),
            FanReading(current: 2400, max: 6000)
        ]
        let snapshot = FanSnapshot(fans: fans)
        #expect(snapshot.fans.count == 2)
    }

    @Test func fanSnapshot_emptyFans_representsNoFans() {
        let snapshot = FanSnapshot(fans: [])
        #expect(snapshot.fans.isEmpty)
    }

    // MARK: - Sample with nil bridge (fanless / unavailable path)

    @Test func sample_returnsEmpty_whenBridgeIsNil() {
        let result = FanMonitorService.sample(nil)
        #expect(result.isEmpty)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = FanMonitorService()
        let _: any MetricMonitorProtocol<FanSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = FanMonitorService()
        let _ = service.stream()
        service.stop()
    }
}
