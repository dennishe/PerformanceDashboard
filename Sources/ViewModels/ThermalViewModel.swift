import SwiftUI

/// Threshold levels for CPU temperature.
@MainActor
@Observable
public final class ThermalViewModel: MonitorViewModelBase<ThermalSnapshot> {
    public private(set) var cpuCelsius: Double?
    public private(set) var gpuCelsius: Double?

    /// Normalised CPU temperature using 100 °C as the reference maximum.
    private static let maxCelsius = 100.0

    public var gaugeValue: Double? {
        cpuCelsius.map { min(1.0, max(0.0, $0 / ThermalViewModel.maxCelsius)) }
    }

    public var cpuLabel: String {
        cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "—"
    }

    public var gpuLabel: String? {
        gpuCelsius.map { String(format: "GPU %.1f°C", $0) }
    }

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
        appendHistory(normalized)
    }
}
