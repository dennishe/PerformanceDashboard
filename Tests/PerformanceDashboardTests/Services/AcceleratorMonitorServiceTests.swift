import Testing
@testable import PerformanceDashboard

struct AcceleratorMonitorServiceTests {
    @Test @MainActor func service_canBeInstantiated() {
        let service = AcceleratorMonitorService()
        let _: any MetricMonitorProtocol<AcceleratorSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = AcceleratorMonitorService()
        _ = service.stream()
        service.stop()
    }

    @Test @MainActor func stream_canBeRestartedAfterStop() {
        let service = AcceleratorMonitorService()
        _ = service.stream()
        service.stop()
        _ = service.stream()
        service.stop()
    }

    @Test @MainActor func multipleServices_canCoexist() {
        let s1 = AcceleratorMonitorService()
        let s2 = AcceleratorMonitorService()
        _ = s1.stream()
        _ = s2.stream()
        s1.stop()
        s2.stop()
    }

    // MARK: - AcceleratorSnapshot

    @Test func acceleratorSnapshot_nilUsage_representsUnavailable() {
        let snapshot = AcceleratorSnapshot(aneUsage: nil)
        #expect(snapshot.aneUsage == nil)
    }

    @Test func acceleratorSnapshot_storesUsage() {
        let snapshot = AcceleratorSnapshot(aneUsage: 0.3)
        #expect(snapshot.aneUsage == 0.3)
    }

    @Test func acceleratorSnapshot_storesZeroUsage() {
        let snapshot = AcceleratorSnapshot(aneUsage: 0.0)
        #expect(snapshot.aneUsage == 0.0)
    }

    @Test func acceleratorSnapshot_storesFullUsage() {
        let snapshot = AcceleratorSnapshot(aneUsage: 1.0)
        #expect(snapshot.aneUsage == 1.0)
    }

    @Test func acceleratorSnapshot_nilVsValue_areDifferent() {
        let nilSnap = AcceleratorSnapshot(aneUsage: nil)
        let valSnap = AcceleratorSnapshot(aneUsage: 0.5)
        #expect(nilSnap.aneUsage == nil)
        #expect(valSnap.aneUsage != nil)
    }

    @Test func acceleratorSnapshot_multipleValues() {
        let zero = AcceleratorSnapshot(aneUsage: 0.0)
        let one = AcceleratorSnapshot(aneUsage: 1.0)
        let mid = AcceleratorSnapshot(aneUsage: 0.5)
        #expect(zero.aneUsage == 0.0)
        #expect(one.aneUsage == 1.0)
        #expect(mid.aneUsage == 0.5)
    }

    @Test func acceleratorSnapshot_isSendable() {
        let snapshot = AcceleratorSnapshot(aneUsage: 0.42)
        let _: any Sendable = snapshot
    }
}
