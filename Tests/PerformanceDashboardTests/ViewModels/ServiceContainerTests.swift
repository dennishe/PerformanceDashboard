import Testing
@testable import PerformanceDashboard

@MainActor
struct ServiceContainerTests {
    @MainActor
    private struct Fixture {
        let cpuMonitor = MockMonitor(snapshots: [CPUSnapshot(usage: 0.1)])
        let gpuMonitor = MockMonitor(snapshots: [GPUSnapshot(usage: 0.1)])
        let memoryMonitor = MockMonitor(snapshots: [MemorySnapshot(usage: 0.1, total: 100, used: 10)])
        let networkMonitor = MockMonitor(
            snapshots: [NetworkSnapshot(bytesInPerSecond: 1, bytesOutPerSecond: 1)]
        )
        let diskMonitor = MockMonitor(snapshots: [DiskSnapshot(usage: 0.1, total: 100, available: 90)])
        let acceleratorMonitor = MockMonitor(snapshots: [AcceleratorSnapshot(aneUsage: 0.1)])
        let powerMonitor = MockMonitor(snapshots: [PowerSnapshot(watts: 10)])
        let fanMonitor = MockMonitor(
            snapshots: [FanSnapshot(fans: [FanReading(current: 1_000, max: 2_000)])]
        )
        let thermalMonitor = MockMonitor(
            snapshots: [ThermalSnapshot(cpuCelsius: 60, gpuCelsius: nil, sensorReadings: [])]
        )
        let batteryMonitor = MockMonitor(snapshots: [BatterySnapshot(
            isPresent: true,
            chargeFraction: 0.8,
            isCharging: false,
            onAC: false,
            timeToEmptyMinutes: 120,
            cycleCount: 10,
            healthFraction: 0.95
        )])
        let peripheralBatteryProvider = MockPeripheralBatteryProvider(batteries: [])
        let mediaEngineMonitor = MockMonitor(
            snapshots: [MediaEngineSnapshot(encodeMilliwatts: 10, decodeMilliwatts: 5)]
        )
        let wifiMonitor = MockMonitor(snapshots: [WiFiSnapshot(ssid: "Net", rssi: -55, on: true)])
        let bluetoothMonitor = MockMonitor(snapshots: [BluetoothSnapshot(connectedCount: 1, on: true)])
        let container: ServiceContainer

        init() {
            let batcher = SynchronousBatcher()
            container = ServiceContainer(
                cpu: CPUViewModel(monitor: cpuMonitor, batcher: batcher),
                gpu: GPUViewModel(monitor: gpuMonitor, batcher: batcher),
                memory: MemoryViewModel(monitor: memoryMonitor, batcher: batcher),
                network: NetworkViewModel(monitor: networkMonitor, batcher: batcher),
                disk: DiskViewModel(monitor: diskMonitor, batcher: batcher),
                accelerator: AcceleratorViewModel(monitor: acceleratorMonitor, batcher: batcher),
                power: PowerViewModel(monitor: powerMonitor, batcher: batcher),
                fan: FanViewModel(monitor: fanMonitor, batcher: batcher),
                thermal: ThermalViewModel(monitor: thermalMonitor, batcher: batcher),
                battery: BatteryViewModel(
                    monitor: batteryMonitor,
                    batcher: batcher,
                    peripheralBatteryProvider: peripheralBatteryProvider,
                    peripheralRefreshInterval: .seconds(3_600)
                ),
                mediaEngine: MediaEngineViewModel(monitor: mediaEngineMonitor, batcher: batcher),
                wireless: WirelessViewModel(
                    wifiMonitor: wifiMonitor,
                    btMonitor: bluetoothMonitor,
                    batcher: batcher
                )
            )
        }
    }

    @Test func startAll_andStopAll_forwardToEveryMonitor() async {
        let fixture = Fixture()

        fixture.container.startAll()
        await waitForAsyncUpdates()
        fixture.container.stopAll()

        #expect(fixture.cpuMonitor.streamCallCount == 1)
        #expect(fixture.gpuMonitor.streamCallCount == 1)
        #expect(fixture.memoryMonitor.streamCallCount == 1)
        #expect(fixture.networkMonitor.streamCallCount == 1)
        #expect(fixture.diskMonitor.streamCallCount == 1)
        #expect(fixture.acceleratorMonitor.streamCallCount == 1)
        #expect(fixture.powerMonitor.streamCallCount == 1)
        #expect(fixture.fanMonitor.streamCallCount == 1)
        #expect(fixture.thermalMonitor.streamCallCount == 1)
        #expect(fixture.batteryMonitor.streamCallCount == 1)
        #expect(fixture.mediaEngineMonitor.streamCallCount == 1)
        #expect(fixture.wifiMonitor.streamCallCount == 1)
        #expect(fixture.bluetoothMonitor.streamCallCount == 1)

        #expect(fixture.cpuMonitor.stopCallCount == 1)
        #expect(fixture.gpuMonitor.stopCallCount == 1)
        #expect(fixture.memoryMonitor.stopCallCount == 1)
        #expect(fixture.networkMonitor.stopCallCount == 1)
        #expect(fixture.diskMonitor.stopCallCount == 1)
        #expect(fixture.acceleratorMonitor.stopCallCount == 1)
        #expect(fixture.powerMonitor.stopCallCount == 1)
        #expect(fixture.fanMonitor.stopCallCount == 1)
        #expect(fixture.thermalMonitor.stopCallCount == 1)
        #expect(fixture.batteryMonitor.stopCallCount == 1)
        #expect(fixture.mediaEngineMonitor.stopCallCount == 1)
        #expect(fixture.wifiMonitor.stopCallCount == 1)
        #expect(fixture.bluetoothMonitor.stopCallCount == 1)
    }
}
