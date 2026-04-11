import Testing
@testable import PerformanceDashboard

struct ThermalMonitorServiceTests {
    private func sp78Bytes(_ value: Double) -> [UInt8] {
        let raw = UInt16(value * 256)
        return [UInt8(raw >> 8), UInt8(raw & 0xFF)]
    }

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

    @Test func sample_readsCpuTemperature_fromInjectedReader() {
        let sp78Type = SMCBridge.fourCC("sp78") ?? 0
        let reader = MockSMCReader(readings: [
            "Tp2b": (dataType: sp78Type, bytes: sp78Bytes(72))
        ])

        let snapshot = ThermalMonitorService.sample(reader)

        #expect(snapshot.cpuCelsius == 72)
        #expect(snapshot.sensorReadings == [ThermalReading(label: "P-Cluster 0", celsius: 72)])
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
