import SwiftUI

/// Threshold levels for CPU temperature.
@MainActor
@Observable
public final class ThermalViewModel: MonitorViewModelBase<ThermalSnapshot> {
    private var lastSnapshot = ThermalSnapshot(cpuCelsius: nil, gpuCelsius: nil, sensorReadings: [])

    public var cpuCelsius: Double? { lastSnapshot.cpuCelsius }
    public var gpuCelsius: Double? { lastSnapshot.gpuCelsius }
    public var gaugeValue: Double? { cpuCelsius.map(Self.normalizedCelsius) }
    public var cpuLabel: String { cpuCelsius.map { $0.celsiusFormatted() } ?? "—" }
    public var gpuLabel: String? { gpuCelsius.map { "GPU \($0.celsiusFormatted())" } }

    /// Normalised CPU temperature using 100 °C as the reference maximum.
    private static let maxCelsius = 100.0

    private static func normalizedCelsius(_ value: Double) -> Double {
        min(1.0, max(0.0, value / maxCelsius))
    }

    public var thresholdLevel: ThresholdLevel {
        guard let gaugeValue else { return .inactive }
        return MetricThresholds.thermal.level(for: gaugeValue)
    }

    override public func receive(_ snapshot: ThermalSnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.cpuCelsius.map(Self.normalizedCelsius) ?? 0)
    }

    override public func makeTileModel() -> MetricTileModel {
        let thresholdLevel = gaugeValue.map(MetricThresholds.thermal.level(for:)) ?? .inactive
        return MetricTileModel(
            title: "Temp",
            value: cpuLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: gpuLabel,
            unavailableReason: gaugeValue == nil ? "Temperature sensor unavailable" : nil,
            systemImage: "thermometer.medium"
        )
    }

    public var detailModel: DetailModel {
        let stats = lastSnapshot.sensorReadings.map {
            DetailModel.Stat(label: $0.label, value: $0.celsius.celsiusFormatted())
        }
        return DetailModel(
            title: "Temperature",
            systemImage: "thermometer.medium",
            primaryValue: cpuLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }
}
