import Foundation
import Testing
@testable import PerformanceDashboard

struct AcceleratorMonitorServiceTests {
    #if arch(arm64)
    @MonitorActor
    private final class MockPMPSampler: PMPSampling {
        private(set) var setUpCallCount = 0
        private var deltas: [CFDictionary?]

        init(deltas: [CFDictionary?]) {
            self.deltas = deltas
        }

        func setUp() {
            setUpCallCount += 1
        }

        func nextDelta() -> CFDictionary? {
            guard !deltas.isEmpty else { return nil }
            return deltas.removeFirst()
        }
    }

    @MonitorActor
    private func makeSampler(deltas: [CFDictionary?]) -> MockPMPSampler {
        MockPMPSampler(deltas: deltas)
    }
    #endif

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

    #if arch(arm64)
    @Test @MainActor func sample_beforeSetUp_returnsUnavailableSnapshot() async {
        let service = AcceleratorMonitorService()

        let snapshot = await service.sample()

        #expect(snapshot == AcceleratorSnapshot(aneUsage: nil))
    }

    @Test @MainActor func sample_usesInjectedSamplerAndExtractor() async {
        let delta = ["IOReportChannels": []] as CFDictionary
        let sampler = await makeSampler(deltas: [delta, nil])
        let service = AcceleratorMonitorService(
            makeSampler: { sampler },
            extractUsage: { _, currentMaxDelta in (0.75, currentMaxDelta + 1) }
        )

        await service.setUp()
        let first = await service.sample()
        let second = await service.sample()
        let setUpCallCount = await sampler.setUpCallCount

        #expect(setUpCallCount == 1)
        #expect(first == AcceleratorSnapshot(aneUsage: 0.75))
        #expect(second == AcceleratorSnapshot(aneUsage: nil))
    }

    @Test @MainActor func sample_withDefaultExtractor_parsesSyntheticDelta() async {
        let delta = [
            "IOReportChannels": [
                ["LegendChannel": [0, 0, "ANE"], "SimpleValue": 6]
            ]
        ] as NSDictionary
        let sampler = await makeSampler(deltas: [delta as CFDictionary])
        let service = AcceleratorMonitorService(makeSampler: { sampler })

        await service.setUp()
        let snapshot = await service.sample()

        #expect(snapshot == AcceleratorSnapshot(aneUsage: 1.0))
    }
    #endif
}
