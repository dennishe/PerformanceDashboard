import Testing
@testable import PerformanceDashboard

struct FanMonitorServiceTests {
    private func floatBytes(_ value: Float) -> [UInt8] {
        let bitPattern = value.bitPattern
        return [
            UInt8(bitPattern & 0xFF),
            UInt8((bitPattern >> 8) & 0xFF),
            UInt8((bitPattern >> 16) & 0xFF),
            UInt8((bitPattern >> 24) & 0xFF)
        ]
    }

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

    @Test func sample_readsFanValues_fromInjectedReader() {
        let floatType = SMCBridge.fourCC("flt ") ?? 0
        let reader = MockSMCReader(readings: [
            "FNum": (dataType: 0, bytes: [1]),
            "F0Ac": (dataType: floatType, bytes: floatBytes(2_000)),
            "F0Mx": (dataType: floatType, bytes: floatBytes(4_000))
        ])

        let result = FanMonitorService.sample(reader)

        #expect(result.count == 1)
        #expect(result[0] == FanReading(current: 2_000, max: 4_000))
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = FanMonitorService()
        let _: any MetricMonitorProtocol<FanSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = FanMonitorService()
        _ = service.stream()
        service.stop()
    }

    // MARK: - Additional FanReading tests

    @Test func fanReading_fraction_oneQuarter() {
        let fan = FanReading(current: 1500, max: 6000)
        #expect(abs(fan.fraction - 0.25) < 0.001)
    }

    @Test func fanReading_storesCurrentAndMax() {
        let fan = FanReading(current: 2500, max: 7500)
        #expect(fan.current == 2500)
        #expect(fan.max == 7500)
    }

    @Test func fanReading_bothZero_fractionIsZero() {
        let fan = FanReading(current: 0, max: 0)
        #expect(fan.fraction == 0)
    }

    @Test func fanReading_maxEqualsCurrent_fractionIsOne() {
        let fan = FanReading(current: 5000, max: 5000)
        #expect(fan.fraction == 1.0)
    }

    @Test func fanReading_isSendable() {
        let fan = FanReading(current: 3000, max: 6000)
        let _: Sendable = fan
    }

    // MARK: - Additional FanSnapshot tests

    @Test func fanSnapshot_singleFan() {
        let fan = FanReading(current: 3000, max: 6000)
        let snapshot = FanSnapshot(fans: [fan])
        #expect(snapshot.fans.count == 1)
        #expect(snapshot.fans[0].current == 3000)
    }

    @Test func fanSnapshot_preservesOrder() {
        let fans = [
            FanReading(current: 1000, max: 6000),
            FanReading(current: 2000, max: 6000),
            FanReading(current: 3000, max: 6000)
        ]
        let snapshot = FanSnapshot(fans: fans)
        #expect(snapshot.fans[0].current == 1000)
        #expect(snapshot.fans[2].current == 3000)
    }

    @Test func fanSnapshot_isSendable() {
        let snapshot = FanSnapshot(fans: [])
        let _: Sendable = snapshot
    }

    @Test @MainActor func service_multipleStop_isIdempotent() {
        let service = FanMonitorService()
        _ = service.stream()
        service.stop()
        service.stop()
    }
}
