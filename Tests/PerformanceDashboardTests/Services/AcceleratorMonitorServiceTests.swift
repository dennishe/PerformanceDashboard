import Testing
@testable import PerformanceDashboard

struct AcceleratorMonitorServiceTests {
    @Test func sample_doesNotCrash() {
        // Returns nil unless an ANE IOKit service is accessible.
        let usage = AcceleratorMonitorService.sample()
        if let usage {
            #expect(usage >= 0)
            #expect(usage <= 1)
        }
    }

    @Test func readANEUsage_returnsNil_forUnknownServiceName() {
        #if arch(arm64)
        let result = AcceleratorMonitorService.readANEUsage(serviceName: "NonExistentService_XYZ")
        #expect(result == nil)
        #else
        // Non-arm64: sample always returns nil
        #expect(AcceleratorMonitorService.sample() == nil)
        #endif
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
