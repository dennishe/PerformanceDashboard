import Testing
import Foundation
@testable import PerformanceDashboard

struct MemoryMonitorServiceTests {
    @Test func sample_returnsNonNil_onRealSystem() {
        let snapshot = MemoryMonitorService.sample()
        #expect(snapshot != nil)
    }

    @Test func sample_usage_isBetweenZeroAndOne() {
        guard let snapshot = MemoryMonitorService.sample() else { return }
        #expect(snapshot.usage >= 0)
        #expect(snapshot.usage <= 1)
    }

    @Test func sample_total_matchesPhysicalMemory() {
        guard let snapshot = MemoryMonitorService.sample() else { return }
        let physical = ProcessInfo.processInfo.physicalMemory
        #expect(snapshot.total == physical)
    }

    @Test func sample_usedBytes_isLessThanTotal() {
        guard let snapshot = MemoryMonitorService.sample() else { return }
        #expect(snapshot.used <= snapshot.total)
    }

    @Test func memorySnapshot_storesValues() {
        let snapshot = MemorySnapshot(usage: 0.5, total: 8_000_000_000, used: 4_000_000_000)
        #expect(snapshot.usage == 0.5)
        #expect(snapshot.total == 8_000_000_000)
        #expect(snapshot.used == 4_000_000_000)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = MemoryMonitorService()
        let _: any MetricMonitorProtocol<MemorySnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = MemoryMonitorService()
        _ = service.stream()
        service.stop()
    }
}
