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
}
