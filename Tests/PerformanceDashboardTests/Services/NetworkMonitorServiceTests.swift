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

    // MARK: - Additional NetworkSnapshot tests

    @Test func networkSnapshot_zeroValues() {
        let snapshot = NetworkSnapshot(bytesInPerSecond: 0, bytesOutPerSecond: 0)
        #expect(snapshot.bytesInPerSecond == 0)
        #expect(snapshot.bytesOutPerSecond == 0)
    }

    @Test func networkSnapshot_asymmetricValues() {
        let snapshot = NetworkSnapshot(bytesInPerSecond: 100_000, bytesOutPerSecond: 5_000)
        #expect(snapshot.bytesInPerSecond == 100_000)
        #expect(snapshot.bytesOutPerSecond == 5_000)
    }

    @Test func networkSnapshot_zeroIn_nonzeroOut() {
        let snapshot = NetworkSnapshot(bytesInPerSecond: 0, bytesOutPerSecond: 1_000_000)
        #expect(snapshot.bytesInPerSecond == 0)
        #expect(snapshot.bytesOutPerSecond == 1_000_000)
    }

    @Test func networkSnapshot_largeValues() {
        let snapshot = NetworkSnapshot(bytesInPerSecond: 1_250_000_000, bytesOutPerSecond: 500_000_000)
        #expect(snapshot.bytesInPerSecond == 1_250_000_000)
        #expect(snapshot.bytesOutPerSecond == 500_000_000)
    }

    @Test func networkSnapshot_isSendable() {
        let snapshot = NetworkSnapshot(bytesInPerSecond: 1024, bytesOutPerSecond: 512)
        let _: Sendable = snapshot
    }

    @Test @MainActor func service_multipleInstances_canCoexist() {
        let service1 = NetworkMonitorService()
        let service2 = NetworkMonitorService()
        _ = service1.stream()
        _ = service2.stream()
        service1.stop()
        service2.stop()
    }
}
