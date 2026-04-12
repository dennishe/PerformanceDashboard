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
        let snapshot = BatteryMonitorService.readSnapshot()
        #expect(snapshot.chargeFraction >= 0)
        #expect(snapshot.chargeFraction <= 1)
    }

    @Test func sample_desktopWithNoBattery_hasConsistentDefaults() {
        let snapshot = BatteryMonitorService.readSnapshot()
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

    @Test @MainActor func service_usesBatteryPollingInterval() async {
        let service = BatteryMonitorService()
        let interval = await service.pollingInterval()
        #expect(interval == Constants.batteryPollingInterval)
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = BatteryMonitorService()
        _ = service.stream()
        service.stop()
    }

    // MARK: - Additional BatterySnapshot edge cases

    @Test func batterySnapshot_fullCharge() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 1.0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: 100, healthFraction: 1.0
        )
        #expect(snapshot.chargeFraction == 1.0)
        #expect(snapshot.isCharging == false)
    }

    @Test func batterySnapshot_lowCharge() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 0.05, isCharging: true,
            onAC: false, timeToEmptyMinutes: 10, cycleCount: 200, healthFraction: 0.8
        )
        #expect(snapshot.chargeFraction == 0.05)
        #expect(snapshot.timeToEmptyMinutes == 10)
    }

    @Test func batterySnapshot_chargingOnAC() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 0.95, isCharging: true,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: 75, healthFraction: 0.98
        )
        #expect(snapshot.isCharging == true)
        #expect(snapshot.onAC == true)
        #expect(snapshot.timeToEmptyMinutes == nil)
    }

    @Test func batterySnapshot_degradedHealth() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 0.70, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: 600, healthFraction: 0.65
        )
        #expect(snapshot.healthFraction == 0.65)
        #expect(snapshot.cycleCount == 600)
    }

    @Test func batterySnapshot_zeroTimeToEmpty() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 0.01, isCharging: false,
            onAC: false, timeToEmptyMinutes: 0, cycleCount: 300, healthFraction: 0.70
        )
        #expect(snapshot.timeToEmptyMinutes == 0)
    }

    @Test func batterySnapshot_largeTimeToEmpty() {
        let snapshot = BatterySnapshot(
            isPresent: true, chargeFraction: 1.0, isCharging: false,
            onAC: false, timeToEmptyMinutes: 720, cycleCount: 10, healthFraction: 1.0
        )
        #expect(snapshot.timeToEmptyMinutes == 720)
    }

    @Test func batterySnapshot_isSendable() {
        let snapshot = BatterySnapshot(
            isPresent: false, chargeFraction: 0, isCharging: false,
            onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
        )
        let _: Sendable = snapshot
    }

    @Test func sample_healthFractionIsValidWhenBatteryPresent() {
        let snapshot = BatteryMonitorService.readSnapshot()
        if snapshot.isPresent, let health = snapshot.healthFraction {
            #expect(health >= 0)
            #expect(health <= 1)
        }
    }

    @Test func sample_cycleCountIsNonNegativeWhenPresent() {
        let snapshot = BatteryMonitorService.readSnapshot()
        if let cycles = snapshot.cycleCount {
            #expect(cycles >= 0)
        }
    }
}
