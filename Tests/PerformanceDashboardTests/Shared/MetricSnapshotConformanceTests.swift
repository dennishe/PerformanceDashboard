import Testing
@testable import PerformanceDashboard

struct MetricSnapshotConformanceTests {
    @Test func allSnapshotsConformToMetricSnapshot() {
        let snapshots: [any MetricSnapshot] = [
            CPUSnapshot(usage: 0.5, topProcesses: [ProcessCPUStat(name: "Safari", fraction: 0.2)]),
            GPUSnapshot(usage: nil),
            MemorySnapshot(usage: 0.5, total: 16_000_000_000, used: 8_000_000_000),
            NetworkSnapshot(bytesInPerSecond: 1_024, bytesOutPerSecond: 2_048),
            DiskSnapshot(usage: 0.5, total: 1_000, available: 500),
            FanSnapshot(fans: [FanReading(current: 2_000, max: 4_000)]),
            ThermalSnapshot(cpuCelsius: 65, gpuCelsius: nil, sensorReadings: [
                ThermalReading(label: "CPU Die", celsius: 65)
            ]),
            BatterySnapshot(
                isPresent: true,
                chargeFraction: 0.8,
                isCharging: false,
                onAC: false,
                timeToEmptyMinutes: 120,
                cycleCount: 10,
                healthFraction: 0.95
            ),
            AcceleratorSnapshot(aneUsage: 0.3),
            PowerSnapshot(watts: 10),
            MediaEngineSnapshot(encodeMilliwatts: 50, decodeMilliwatts: 25),
            WiFiSnapshot(ssid: "TestNet", rssi: -55, on: true),
            BluetoothSnapshot(
                connectedCount: 2,
                on: true,
                peripherals: [PeripheralBattery(name: "Mouse", percent: 90)]
            )
        ]

        #expect(snapshots.count == 13)
    }
}
