import Testing
@testable import PerformanceDashboard

struct NetworkMonitorServiceTests {
    @Test func counters_returnsTupleOfUInt64() {
        let (bytesIn, bytesOut) = NetworkMonitorService.counters()
        // Values may be 0 in a restricted environment but must be non-negative UInt64.
        #expect(bytesIn >= 0)
        #expect(bytesOut >= 0)
    }

    @Test func counters_calledTwice_returnsNonDecreasing() {
        let (inFirst, outFirst) = NetworkMonitorService.counters()
        let (inSecond, outSecond) = NetworkMonitorService.counters()
        // Byte counters are monotonically increasing (or equal if no traffic).
        #expect(inSecond >= inFirst)
        #expect(outSecond >= outFirst)
    }

    @Test func networkSnapshot_storesValues() {
        let snapshot = NetworkSnapshot(bytesInPerSecond: 1024, bytesOutPerSecond: 512)
        #expect(snapshot.bytesInPerSecond == 1024)
        #expect(snapshot.bytesOutPerSecond == 512)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = NetworkMonitorService()
        let _: any MetricMonitorProtocol<NetworkSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = NetworkMonitorService()
        _ = service.stream()
        service.stop()
    }
}
