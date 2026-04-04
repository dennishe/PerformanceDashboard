import Testing
@testable import PerformanceDashboard

struct PowerMonitorServiceTests {

    // MARK: - PowerSnapshot

    @Test func powerSnapshot_storesWatts() {
        let snapshot = PowerSnapshot(watts: 15.5)
        #expect(snapshot.watts == 15.5)
    }

    @Test func powerSnapshot_allowsNilWatts() {
        let snapshot = PowerSnapshot(watts: nil)
        #expect(snapshot.watts == nil)
    }

    @Test func powerSnapshot_zeroWatts_isValid() {
        let snapshot = PowerSnapshot(watts: 0)
        #expect(snapshot.watts == 0)
    }

    @Test func powerSnapshot_highWatts_isValid() {
        let snapshot = PowerSnapshot(watts: 250.0)
        #expect(snapshot.watts == 250.0)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = PowerMonitorService()
        let _: any MetricMonitorProtocol<PowerSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = PowerMonitorService()
        _ = service.stream()
        service.stop()
    }
}
