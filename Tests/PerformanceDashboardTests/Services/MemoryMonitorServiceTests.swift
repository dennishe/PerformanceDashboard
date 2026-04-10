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

    // MARK: - Snapshot edge cases

    @Test func memorySnapshot_withZeroUsage() {
        let snapshot = MemorySnapshot(usage: 0, total: 8_000_000_000, used: 0)
        #expect(snapshot.usage == 0)
        #expect(snapshot.used == 0)
    }

    @Test func memorySnapshot_withFullUsage() {
        let snapshot = MemorySnapshot(usage: 1.0, total: 8_000_000_000, used: 8_000_000_000)
        #expect(snapshot.usage == 1.0)
        #expect(snapshot.used == snapshot.total)
    }

    @Test func memorySnapshot_withZeroTotal() {
        let snapshot = MemorySnapshot(usage: 0, total: 0, used: 0)
        #expect(snapshot.usage == 0)
        #expect(snapshot.total == 0)
    }

    @Test func memorySnapshot_isSendable() {
        let snapshot = MemorySnapshot(usage: 0.5, total: 8_000_000_000, used: 4_000_000_000)
        let _: Sendable = snapshot
    }

    @Test func memorySnapshot_highPrecision() {
        let snapshot = MemorySnapshot(usage: 0.987654, total: 16_000_000_000, used: 15_802_464_000)
        #expect(snapshot.usage == 0.987654)
    }

    @Test func sample_usageRatioConsistency() {
        guard let snapshot = MemoryMonitorService.sample() else { return }
        if snapshot.total > 0 {
            let expected = Double(snapshot.used) / Double(snapshot.total)
            #expect(abs(snapshot.usage - expected) < 0.001)
        }
    }

    @Test func sample_usedIsNonNegative() {
        guard let snapshot = MemoryMonitorService.sample() else { return }
        #expect(snapshot.used >= 0)
    }
}
