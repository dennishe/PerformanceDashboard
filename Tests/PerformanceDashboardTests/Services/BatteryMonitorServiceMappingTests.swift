import IOKit.ps
import Testing
@testable import PerformanceDashboard

struct BatteryMonitorServiceMappingTests {
    private struct MockBatteryPowerSourceProvider: BatteryPowerSourceProviding {
        let sourceDescription: [String: Any]?

        func description() -> [String: Any]? {
            sourceDescription
        }
    }

    private struct MockBatteryRegistryProvider: BatteryRegistryProviding {
        let info: (cycleCount: Int?, health: Double?)

        func batteryInfo() -> (cycleCount: Int?, health: Double?) {
            info
        }
    }

    @Test func readSnapshot_returnsUnavailableDefaults_whenPowerSourceIsMissing() {
        let snapshot = BatteryMonitorService.readSnapshot(
            powerSourceProvider: MockBatteryPowerSourceProvider(sourceDescription: nil),
            registryProvider: MockBatteryRegistryProvider(info: (cycleCount: 99, health: 0.9))
        )

        #expect(snapshot == BatterySnapshot(
            isPresent: false,
            chargeFraction: 0,
            isCharging: false,
            onAC: true,
            timeToEmptyMinutes: nil,
            cycleCount: nil,
            healthFraction: nil
        ))
    }

    @Test func readSnapshot_mapsPowerSourceAndRegistryFields() {
        let snapshot = BatteryMonitorService.readSnapshot(
            powerSourceProvider: MockBatteryPowerSourceProvider(sourceDescription: [
                kIOPSIsPresentKey: true,
                kIOPSCurrentCapacityKey: 40,
                kIOPSMaxCapacityKey: 80,
                kIOPSIsChargingKey: true,
                kIOPSPowerSourceStateKey: kIOPSACPowerValue,
                kIOPSTimeToEmptyKey: 120
            ]),
            registryProvider: MockBatteryRegistryProvider(info: (cycleCount: 120, health: 0.85))
        )

        #expect(snapshot == BatterySnapshot(
            isPresent: true,
            chargeFraction: 0.5,
            isCharging: true,
            onAC: true,
            timeToEmptyMinutes: 120,
            cycleCount: 120,
            healthFraction: 0.85
        ))
    }

    @Test func readSnapshot_clampsCapacityAndDropsNonPositiveTimeToEmpty() {
        let snapshot = BatteryMonitorService.readSnapshot(
            powerSourceProvider: MockBatteryPowerSourceProvider(sourceDescription: [
                kIOPSIsPresentKey: true,
                kIOPSCurrentCapacityKey: 15,
                kIOPSMaxCapacityKey: 0,
                kIOPSIsChargingKey: false,
                kIOPSPowerSourceStateKey: "Battery Power",
                kIOPSTimeToEmptyKey: 0
            ]),
            registryProvider: MockBatteryRegistryProvider(info: (cycleCount: nil, health: nil))
        )

        #expect(snapshot.chargeFraction == 15)
        #expect(snapshot.onAC == false)
        #expect(snapshot.timeToEmptyMinutes == nil)
        #expect(snapshot.cycleCount == nil)
        #expect(snapshot.healthFraction == nil)
    }

    @Test func readSnapshot_usesDefaultValues_whenFieldsAreMissing() {
        let snapshot = BatteryMonitorService.readSnapshot(
            powerSourceProvider: MockBatteryPowerSourceProvider(sourceDescription: [
                kIOPSIsPresentKey: true
            ]),
            registryProvider: MockBatteryRegistryProvider(info: (cycleCount: nil, health: nil))
        )

        #expect(snapshot.isPresent)
        #expect(snapshot.chargeFraction == 0)
        #expect(snapshot.isCharging == false)
        #expect(snapshot.onAC == false)
        #expect(snapshot.timeToEmptyMinutes == nil)
    }
}
