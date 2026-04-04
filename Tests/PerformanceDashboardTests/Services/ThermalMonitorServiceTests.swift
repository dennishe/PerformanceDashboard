import Testing
@testable import PerformanceDashboard

struct ThermalMonitorServiceTests {

    // MARK: - ThermalSnapshot

    @Test func thermalSnapshot_storesBothValues() {
        let snapshot = ThermalSnapshot(cpuCelsius: 65.0, gpuCelsius: 45.0)
        #expect(snapshot.cpuCelsius == 65.0)
        #expect(snapshot.gpuCelsius == 45.0)
    }

    @Test func thermalSnapshot_allowsBothNil() {
        let snapshot = ThermalSnapshot(cpuCelsius: nil, gpuCelsius: nil)
        #expect(snapshot.cpuCelsius == nil)
        #expect(snapshot.gpuCelsius == nil)
    }

    @Test func thermalSnapshot_allowsCpuOnlyWithoutGPU() {
        let snapshot = ThermalSnapshot(cpuCelsius: 70.0, gpuCelsius: nil)
        #expect(snapshot.cpuCelsius == 70.0)
        #expect(snapshot.gpuCelsius == nil)
    }

    @Test func thermalSnapshot_allowsHighTemperatureValues() {
        let snapshot = ThermalSnapshot(cpuCelsius: 105.0, gpuCelsius: 95.0)
        #expect(snapshot.cpuCelsius == 105.0)
        #expect(snapshot.gpuCelsius == 95.0)
    }

    // MARK: - Sample with nil bridge

    @Test func sample_returnsBothNil_whenBridgeIsNil() {
        let snapshot = ThermalMonitorService.sample(nil)
        #expect(snapshot.cpuCelsius == nil)
        #expect(snapshot.gpuCelsius == nil)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = ThermalMonitorService()
        let _: any MetricMonitorProtocol<ThermalSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = ThermalMonitorService()
        _ = service.stream()
        service.stop()
    }
}
