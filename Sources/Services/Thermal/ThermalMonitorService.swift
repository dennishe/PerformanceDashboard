import Foundation

/// A named temperature reading from a single sensor cluster.
public struct ThermalReading: Sendable {
    public let label: String
    public let celsius: Double
}

/// Snapshot of CPU and GPU die temperatures.
public struct ThermalSnapshot: Sendable {
    /// Hottest CPU cluster reading in °C, or `nil` when unavailable.
    public let cpuCelsius: Double?
    /// GPU temperature in °C, or `nil` on Apple Silicon.
    public let gpuCelsius: Double?
    /// Per-cluster readings in display order (empty when SMC is unreadable).
    public let sensorReadings: [ThermalReading]
}

/// Reads CPU and GPU temperatures from the SMC.
///
/// Key naming differs by generation:
///  - M1 era:  `Tp01`/`Tp05`/`Tp09`/`Tp0D`, `Te01`/`Te05`/`Te09`
///  - M2+ era: `Tp2b`/`Tp3b`/`Tp4b`…,       `Te0b`/`Te3b`…
///  - Intel:   `TC0D` / `TCXC`
///
/// GPU sensor (`TG0D`) is typically only readable on Intel Macs.
public final class ThermalMonitorService: PollingMonitorBase<ThermalSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<ThermalSnapshot>.Continuation) async {
        let smc = SMCBridge()
        defer { smc?.close() }
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            continuation.yield(ThermalMonitorService.sample(smc))
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
    }

    // MARK: - Sampling

    nonisolated static func sample(_ bridge: SMCBridge?) -> ThermalSnapshot {
        let readings = readSensorGroups(bridge)
        let cpuCelsius = readings
            .filter { $0.label.hasPrefix("P-Cluster") || $0.label.hasPrefix("E-Cluster") || $0.label == "CPU Die" }
            .map(\.celsius).max()
        let gpuCelsius = readings.first { $0.label == "GPU" }?.celsius
        return ThermalSnapshot(cpuCelsius: cpuCelsius, gpuCelsius: gpuCelsius, sensorReadings: readings)
    }

    /// One entry per sensor group. Keys are tried in order; the first readable
    /// value ≥ 20 °C wins. Groups with no readable sensor are omitted.
    ///
    /// M1 machines fall back to their older die-diode key variants;
    /// M2+ machines match the earlier keys in each tuple.
    // swiftlint:disable:next large_tuple
    nonisolated(unsafe) private static let sensorGroups: [(label: String, keys: [String])] = [
        ("P-Cluster 0",    ["Tp2b", "Tp2x", "Tp2a", "Tp0D"]),
        ("P-Cluster 1",    ["Tp3b", "Tp3x", "Tp3a", "Tp09"]),
        ("P-Cluster 2",    ["Tp4b", "Tp4x", "Tp4a", "Tp05"]),
        ("P-Cluster 3",    ["Tp5b", "Tp5x", "Tp5a", "Tp01"]),
        ("P-Cluster 4",    ["Tp7b", "Tp7x", "Tp7a"]),
        ("P-Cluster 5",    ["Tp8b", "Tp8x", "Tp8a"]),
        ("P-Cluster 6",    ["Tp9b", "Tp9x", "Tp9a"]),
        ("E-Cluster 0",    ["Te0b", "Te0x", "Te0a", "Te05", "Te01"]),
        ("E-Cluster 1",    ["Te3b", "Te3x", "Te3a", "Te09"]),
        ("Heat Exchanger", ["TH0x", "TH0a", "TH1x"]),
        ("GPU",            ["TG0D", "TG0P", "Tg05", "Tg0D", "TG0x"]),
        ("CPU Die",        ["TC0D", "TC0E", "TCXC"]),
    ]

    nonisolated private static func readSensorGroups(_ bridge: SMCBridge?) -> [ThermalReading] {
        sensorGroups.compactMap { group in
            for key in group.keys {
                if let result = bridge?.readBytes(key: key),
                   let value = SMCBridge.decodeFloat(result),
                   value > 20 {
                    return ThermalReading(label: group.label, celsius: value)
                }
            }
            return nil
        }
    }
}
