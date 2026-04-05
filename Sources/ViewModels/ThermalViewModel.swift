import SwiftUI

/// Threshold levels for CPU temperature.
@MainActor
@Observable
public final class ThermalViewModel: MonitorViewModelBase<ThermalSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "Temp",
        value: "—",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        systemImage: "thermometer.medium"
    )

    @ObservationIgnored
    public private(set) var cpuCelsius: Double?
    @ObservationIgnored
    public private(set) var gpuCelsius: Double?
    @ObservationIgnored
    public private(set) var gaugeValue: Double?
    @ObservationIgnored
    public private(set) var cpuLabel: String = "—"
    @ObservationIgnored
    public private(set) var gpuLabel: String?

    /// Normalised CPU temperature using 100 °C as the reference maximum.
    private static let maxCelsius = 100.0

    public var thresholdLevel: ThresholdLevel {
        guard let gaugeValue else { return .inactive }
        return ThermalThreshold().level(for: gaugeValue)
    }

    override public func receive(_ snapshot: ThermalSnapshot) {
        cpuCelsius = snapshot.cpuCelsius
        gpuCelsius = snapshot.gpuCelsius
        let normalized = snapshot.cpuCelsius.map {
            min(1.0, max(0.0, $0 / ThermalViewModel.maxCelsius))
        } ?? 0
        gaugeValue = snapshot.cpuCelsius.map {
            min(1.0, max(0.0, $0 / ThermalViewModel.maxCelsius))
        }
        cpuLabel = snapshot.cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "—"
        gpuLabel = snapshot.gpuCelsius.map { String(format: "GPU %.1f°C", $0) }
        appendHistory(normalized)
        let newTileModel = Self.makeTileModel(
            cpuLabel: cpuLabel,
            gaugeValue: gaugeValue,
            history: history,
            gpuLabel: gpuLabel
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        cpuLabel: String,
        gaugeValue: Double?,
        history: [Double],
        gpuLabel: String?
    ) -> MetricTileModel {
        let thresholdLevel = gaugeValue.map(ThermalThreshold().level(for:)) ?? .inactive
        return MetricTileModel(
            title: "Temp",
            value: cpuLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: gpuLabel,
            systemImage: "thermometer.medium"
        )
    }
}
