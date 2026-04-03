import Foundation

// MARK: - Mock helpers shared by Previews and Tests

#if DEBUG

@MainActor
final class MockCPUMonitor: MetricMonitorProtocol {
    var snapshots: [CPUSnapshot] = [CPUSnapshot(usage: 0.42)]
    func stream() -> AsyncStream<CPUSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockGPUMonitor: MetricMonitorProtocol {
    var snapshots: [GPUSnapshot] = [GPUSnapshot(usage: 0.30)]
    func stream() -> AsyncStream<GPUSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockMemoryMonitor: MetricMonitorProtocol {
    var snapshots: [MemorySnapshot] = [MemorySnapshot(usage: 0.65, total: 16_000_000_000, used: 10_400_000_000)]
    func stream() -> AsyncStream<MemorySnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockNetworkMonitor: MetricMonitorProtocol {
    var snapshots: [NetworkSnapshot] = [NetworkSnapshot(bytesInPerSecond: 1_200_000, bytesOutPerSecond: 400_000)]
    func stream() -> AsyncStream<NetworkSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockDiskMonitor: MetricMonitorProtocol {
    var snapshots: [DiskSnapshot] = [DiskSnapshot(usage: 0.55, total: 500_000_000_000, available: 225_000_000_000)]
    func stream() -> AsyncStream<DiskSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockAcceleratorMonitor: MetricMonitorProtocol {
    var snapshots: [AcceleratorSnapshot] = [AcceleratorSnapshot(aneUsage: 0.15)]
    func stream() -> AsyncStream<AcceleratorSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockPowerMonitor: MetricMonitorProtocol {
    var snapshots: [PowerSnapshot] = [PowerSnapshot(watts: 12.5)]
    func stream() -> AsyncStream<PowerSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockFanMonitor: MetricMonitorProtocol {
    var snapshots: [FanSnapshot] = [FanSnapshot(fans: [FanReading(current: 1240, max: 6800)])]
    func stream() -> AsyncStream<FanSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockThermalMonitor: MetricMonitorProtocol {
    var snapshots: [ThermalSnapshot] = [ThermalSnapshot(cpuCelsius: 52.0, gpuCelsius: 45.0)]
    func stream() -> AsyncStream<ThermalSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockBatteryMonitor: MetricMonitorProtocol {
    var snapshots: [BatterySnapshot] = [BatterySnapshot(
        isPresent: true, chargeFraction: 0.78, isCharging: true,
        onAC: true, timeToEmptyMinutes: nil, cycleCount: 42, healthFraction: 0.97
    )]
    func stream() -> AsyncStream<BatterySnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockMediaEngineMonitor: MetricMonitorProtocol {
    var snapshots: [MediaEngineSnapshot] = [MediaEngineSnapshot(encodeMilliwatts: 4.0, decodeMilliwatts: 54.0)]
    func stream() -> AsyncStream<MediaEngineSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

@MainActor
final class MockWirelessMonitor: MetricMonitorProtocol {
    var snapshots: [WirelessSnapshot] = [WirelessSnapshot(
        wifiSSID: "HomeNetwork", wifiRSSI: -58, wifiOn: true,
        bluetoothConnectedCount: 2, bluetoothOn: true
    )]
    func stream() -> AsyncStream<WirelessSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
    func stop() {}
}

#endif
