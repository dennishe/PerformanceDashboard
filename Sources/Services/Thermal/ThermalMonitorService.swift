import Foundation

private let thermalSensorGroups: [(label: String, keys: [String])] = [
    ("P-Cluster 0", ["Tp2b", "Tp2x", "Tp2a", "Tp0D"]),
    ("P-Cluster 1", ["Tp3b", "Tp3x", "Tp3a", "Tp09"]),
    ("P-Cluster 2", ["Tp4b", "Tp4x", "Tp4a", "Tp05"]),
    ("P-Cluster 3", ["Tp5b", "Tp5x", "Tp5a", "Tp01"]),
    ("P-Cluster 4", ["Tp7b", "Tp7x", "Tp7a"]),
    ("P-Cluster 5", ["Tp8b", "Tp8x", "Tp8a"]),
    ("P-Cluster 6", ["Tp9b", "Tp9x", "Tp9a"]),
    ("E-Cluster 0", ["Te0b", "Te0x", "Te0a", "Te05", "Te01"]),
    ("E-Cluster 1", ["Te3b", "Te3x", "Te3a", "Te09"]),
    ("Heat Exchanger", ["TH0x", "TH0a", "TH1x"]),
    ("GPU", ["TG0D", "TG0P", "Tg05", "Tg0D", "TG0x"]),
    ("CPU Die", ["TC0D", "TC0E", "TCXC"])
]

/// A named temperature reading from a single sensor cluster.
public struct ThermalReading: Sendable, Equatable {
    public let label: String
    public let celsius: Double
}

/// Snapshot of CPU and GPU die temperatures.
public struct ThermalSnapshot: MetricSnapshot {
    /// Hottest CPU cluster reading in °C, or `nil` when unavailable.
    public let cpuCelsius: Double?
    /// GPU temperature in °C, or `nil` on Apple Silicon.
    public let gpuCelsius: Double?
    /// Per-cluster readings in display order (empty when SMC is unreadable).
    public let sensorReadings: [ThermalReading]

    public init(
        cpuCelsius: Double?,
        gpuCelsius: Double?,
        sensorReadings: [ThermalReading] = []
    ) {
        self.cpuCelsius = cpuCelsius
        self.gpuCelsius = gpuCelsius
        self.sensorReadings = sensorReadings
    }
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
    @MonitorActor private var smc: SMCBridge?

    @MonitorActor
    override public func setUp() {
        smc = SMCBridge()
    }

    @MonitorActor
    override public func tearDown() {
        smc?.close()
        smc = nil
    }

    @MonitorActor
    override public func sample() async -> ThermalSnapshot? {
        ThermalMonitorService.sample(smc)
    }

    // MARK: - Sampling

    nonisolated static func sample(_ reader: (any SMCReading)?) -> ThermalSnapshot {
        let readings = readSensorGroups(reader)
        let cpuCelsius = readings
            .filter { $0.label.hasPrefix("P-Cluster") || $0.label.hasPrefix("E-Cluster") || $0.label == "CPU Die" }
            .map(\.celsius).max()
        let gpuCelsius = readings.first { $0.label == "GPU" }?.celsius
        return ThermalSnapshot(cpuCelsius: cpuCelsius, gpuCelsius: gpuCelsius, sensorReadings: readings)
    }

    nonisolated private static func readSensorGroups(_ reader: (any SMCReading)?) -> [ThermalReading] {
        thermalSensorGroups.compactMap { group in
            for key in group.keys {
                if let result = reader?.readBytes(key: key),
                   let value = SMCBridge.decodeFloat(result),
                   value > 20 {
                    return ThermalReading(label: group.label, celsius: value)
                }
            }
            return nil
        }
    }
}
