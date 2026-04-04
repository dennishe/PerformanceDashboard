import Testing
@testable import PerformanceDashboard

struct BatteryMonitorServiceTests {

    // MARK: - BatterySnapshot

    @Test func batterySnapshot_storesAllFields() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 0.78, isCharging: true,
            onAC: true, timeToEmptyMinutes: 90, cycleCount: 42, healthFraction: 0.97
        )
        #expect(snapshot.isPresent == true)
        #expect(snapshot.chargeFraction == 0.78)
        #expect(snapshot.isCharging == true)
        #expect(snapshot.onAC == true)
        #expect(snapshot.timeToEmptyMinutes == 90)
        #expect(snapshot.cycleCount == 42)
        #expect(snapshot.healthFraction == 0.97)
    }

    @Test func batterySnapshot_allowsNilOptionals() {
        let snapshot = BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )
        #expect(snapshot.isPresent == false)
        #expect(snapshot.timeToEmptyMinutes == nil)
        #expect(snapshot.cycleCount == nil)
        #expect(snapshot.healthFraction == nil)
    }

    @Test func batterySnapshot_desktopDefault_hasZeroCharge() {
        let snapshot = BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )
        #expect(snapshot.chargeFraction == 0)
        #expect(snapshot.onAC == true)
    }

    // MARK: - Sample integration

    @Test func sample_returnsChargeFractionInValidRange() {
        let snapshot = BatteryMonitorService.sample()
        #expect(snapshot.chargeFraction >= 0)
        #expect(snapshot.chargeFraction <= 1)
    }

    @Test func sample_desktopWithNoBattery_hasConsistentDefaults() {
        let snapshot = BatteryMonitorService.sample()
        if !snapshot.isPresent {
            // Desktop Mac: no battery → AC power, no time-to-empty
            #expect(snapshot.onAC == true)
            #expect(snapshot.timeToEmptyMinutes == nil)
        }
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = BatteryMonitorService()
        let _: any MetricMonitorProtocol<BatterySnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = BatteryMonitorService()
        _ = service.stream()
        service.stop()
    }
}
