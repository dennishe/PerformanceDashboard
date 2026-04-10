import Testing
@testable import PerformanceDashboard

struct MediaEngineMonitorServiceTests {

    // MARK: - MediaEngineSnapshot

    @Test func mediaEngineSnapshot_storesBothValues() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: 4.0, decodeMilliwatts: 54.0)
        #expect(snapshot.encodeMilliwatts == 4.0)
        #expect(snapshot.decodeMilliwatts == 54.0)
    }

    @Test func mediaEngineSnapshot_allowsBothNil() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
        #expect(snapshot.encodeMilliwatts == nil)
        #expect(snapshot.decodeMilliwatts == nil)
    }

    @Test func mediaEngineSnapshot_encodeOnly_isValid() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: 12.5, decodeMilliwatts: nil)
        #expect(snapshot.encodeMilliwatts == 12.5)
        #expect(snapshot.decodeMilliwatts == nil)
    }

    @Test func mediaEngineSnapshot_decodeOnly_isValid() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: 30.0)
        #expect(snapshot.encodeMilliwatts == nil)
        #expect(snapshot.decodeMilliwatts == 30.0)
    }

    @Test func mediaEngineSnapshot_storesZeroValues() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: 0.0, decodeMilliwatts: 0.0)
        #expect(snapshot.encodeMilliwatts == 0.0)
        #expect(snapshot.decodeMilliwatts == 0.0)
    }

    @Test func mediaEngineSnapshot_storesLargeValues() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: 5000.0, decodeMilliwatts: 10000.0)
        #expect(snapshot.encodeMilliwatts == 5000.0)
        #expect(snapshot.decodeMilliwatts == 10000.0)
    }

    @Test func mediaEngineSnapshot_asymmetric() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: 1.0, decodeMilliwatts: 100.0)
        #expect(snapshot.encodeMilliwatts == 1.0)
        #expect(snapshot.decodeMilliwatts == 100.0)
    }

    @Test func mediaEngineSnapshot_allFourCombinations() {
        let s1 = MediaEngineSnapshot(encodeMilliwatts: 10.0, decodeMilliwatts: 20.0)
        let s2 = MediaEngineSnapshot(encodeMilliwatts: 10.0, decodeMilliwatts: nil)
        let s3 = MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: 20.0)
        let s4 = MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
        #expect(s1.encodeMilliwatts == 10.0 && s1.decodeMilliwatts == 20.0)
        #expect(s2.encodeMilliwatts == 10.0 && s2.decodeMilliwatts == nil)
        #expect(s3.encodeMilliwatts == nil && s3.decodeMilliwatts == 20.0)
        #expect(s4.encodeMilliwatts == nil && s4.decodeMilliwatts == nil)
    }

    @Test func mediaEngineSnapshot_isSendable() {
        let snapshot = MediaEngineSnapshot(encodeMilliwatts: 10.0, decodeMilliwatts: 20.0)
        let _: any Sendable = snapshot
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = MediaEngineMonitorService()
        let _: any MetricMonitorProtocol<MediaEngineSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = MediaEngineMonitorService()
        _ = service.stream()
        service.stop()
    }

    @Test @MainActor func stream_canBeRestartedAfterStop() {
        let service = MediaEngineMonitorService()
        _ = service.stream()
        service.stop()
        _ = service.stream()
        service.stop()
    }

    @Test @MainActor func service_stop_isIdempotent() {
        let service = MediaEngineMonitorService()
        _ = service.stream()
        service.stop()
        service.stop()
    }
}
