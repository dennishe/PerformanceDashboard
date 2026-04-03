import SwiftUI

/// Threshold levels for CPU temperature.
public struct ThermalThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.7:  return .normal   // < ~70 °C normalised to 100 °C max
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

@MainActor
@Observable
public final class ThermalViewModel {
    public private(set) var cpuCelsius: Double?
    public private(set) var gpuCelsius: Double?
    public private(set) var history: [Double] = []

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

    private let monitor: any MetricMonitorProtocol<ThermalSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<ThermalSnapshot>) {
        self.monitor = monitor
    }

    public func start() {
        task = Task {
            for await snapshot in monitor.stream() {
                update(snapshot)
            }
        }
    }

    public func stop() {
        task?.cancel()
        monitor.stop()
    }

    private func update(_ snapshot: ThermalSnapshot) {
        cpuCelsius = snapshot.cpuCelsius
        gpuCelsius = snapshot.gpuCelsius
        let normalized = snapshot.cpuCelsius.map {
            min(1.0, max(0.0, $0 / ThermalViewModel.maxCelsius))
        } ?? 0
        history.append(normalized)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
