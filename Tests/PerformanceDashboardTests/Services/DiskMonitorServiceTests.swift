import Testing
import Foundation
@testable import PerformanceDashboard

struct DiskMonitorServiceTests {
    @Test func sample_returnsNonNil_forBootVolume() {
        let snapshot = DiskMonitorService.sample()
        #expect(snapshot != nil)
    }

    @Test func sample_usage_isBetweenZeroAndOne() {
        guard let snapshot = DiskMonitorService.sample() else { return }
        #expect(snapshot.usage >= 0)
        #expect(snapshot.usage <= 1)
    }

    @Test func sample_totalBytes_isPositive() {
        guard let snapshot = DiskMonitorService.sample() else { return }
        #expect(snapshot.total > 0)
    }

    @Test func sample_availableBytes_isNonNegative() {
        guard let snapshot = DiskMonitorService.sample() else { return }
        #expect(snapshot.available >= 0)
    }

    @Test func sample_availableBytes_isLessThanTotal() {
        guard let snapshot = DiskMonitorService.sample() else { return }
        #expect(snapshot.available <= snapshot.total)
    }

    @Test func sample_usage_isConsistentWithBytes() {
        guard let snapshot = DiskMonitorService.sample() else { return }
        let used = snapshot.total - snapshot.available
        let expectedUsage = Double(used) / Double(snapshot.total)
        #expect(abs(snapshot.usage - expectedUsage) < 0.001)
    }

    @Test func diskSnapshot_storesValues() {
        let snapshot = DiskSnapshot(usage: 0.6, total: 500_000_000_000, available: 200_000_000_000)
        #expect(snapshot.usage == 0.6)
        #expect(snapshot.total == 500_000_000_000)
        #expect(snapshot.available == 200_000_000_000)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = DiskMonitorService()
        let _: any MetricMonitorProtocol<DiskSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = DiskMonitorService()
        _ = service.stream()
        service.stop()
    }

    // MARK: - Snapshot edge cases

    @Test func diskSnapshot_withZeroUsage() {
        let snapshot = DiskSnapshot(usage: 0, total: 1_000_000_000, available: 1_000_000_000)
        #expect(snapshot.usage == 0)
        #expect(snapshot.available == 1_000_000_000)
    }

    @Test func diskSnapshot_withFullUsage() {
        let snapshot = DiskSnapshot(usage: 1.0, total: 1_000_000_000, available: 0)
        #expect(snapshot.usage == 1.0)
        #expect(snapshot.available == 0)
    }

    @Test func diskSnapshot_withZeroTotal() {
        let snapshot = DiskSnapshot(usage: 0, total: 0, available: 0)
        #expect(snapshot.total == 0)
        #expect(snapshot.available == 0)
    }

    @Test func diskSnapshot_withPartialUsage() {
        let snapshot = DiskSnapshot(usage: 0.33, total: 1_000_000_000, available: 670_000_000)
        #expect(snapshot.usage == 0.33)
        #expect(snapshot.available == 670_000_000)
    }

    @Test func diskSnapshot_isSendable() {
        let snapshot = DiskSnapshot(usage: 0.5, total: 500_000_000, available: 250_000_000)
        let _: Sendable = snapshot
    }

    @Test func diskSnapshot_multipleInstances_independent() {
        let a = DiskSnapshot(usage: 0.3, total: 100, available: 70)
        let b = DiskSnapshot(usage: 0.8, total: 200, available: 40)
        #expect(a.usage == 0.3)
        #expect(b.usage == 0.8)
    }

    @Test func sample_usedBytesCalculation() {
        guard let snapshot = DiskMonitorService.sample() else { return }
        let used = snapshot.total - snapshot.available
        #expect(used >= 0)
    }
}
