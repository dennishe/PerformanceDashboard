import Testing
@testable import PerformanceDashboard

struct GPUMonitorServiceTests {
    @Test func sample_doesNotCrash() {
        // May return nil if no IOAccelerator is accessible in the test environment.
        let usage = GPUMonitorService.readUsage()
        if let usage {
            #expect(usage >= 0)
            #expect(usage <= 1)
        }
    }

    @Test func gpuSnapshot_nilUsage_representsUnavailable() {
        let snapshot = GPUSnapshot(usage: nil)
        #expect(snapshot.usage == nil)
    }

    @Test func gpuSnapshot_storesUsage() {
        let snapshot = GPUSnapshot(usage: 0.65)
        #expect(snapshot.usage == 0.65)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = GPUMonitorService()
        let _: any MetricMonitorProtocol<GPUSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = GPUMonitorService()
        _ = service.stream()
        service.stop()
    }
}
