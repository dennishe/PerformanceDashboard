import Testing
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
}
