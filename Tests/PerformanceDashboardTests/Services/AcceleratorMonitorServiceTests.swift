import Testing
@testable import PerformanceDashboard

struct AcceleratorMonitorServiceTests {
    @Test @MainActor func service_canBeInstantiated() {
        let service = AcceleratorMonitorService()
        // Verify it conforms to MetricMonitorProtocol; no crash on init.
        let _: any MetricMonitorProtocol<AcceleratorSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = AcceleratorMonitorService()
        _ = service.stream()
        service.stop() // Should not crash.
    }

    @Test func acceleratorSnapshot_nilUsage_representsUnavailable() {
        let snapshot = AcceleratorSnapshot(aneUsage: nil)
        #expect(snapshot.aneUsage == nil)
    }

    @Test func acceleratorSnapshot_storesUsage() {
        let snapshot = AcceleratorSnapshot(aneUsage: 0.3)
        #expect(snapshot.aneUsage == 0.3)
    }
}
