import SwiftUI

/// Threshold levels for CPU temperature.
@MainActor
@Observable
public final class ThermalViewModel: MonitorViewModelBase<ThermalSnapshot> {
    private var lastSnapshot = ThermalSnapshot(cpuCelsius: nil, gpuCelsius: nil)

    public private(set) var tileModel = MetricTileModel(
        title: "Temp",
        value: "—",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        systemImage: "thermometer.medium"
    )

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
        return ThermalThreshold().level(for: gaugeValue)
    }

    override public func receive(_ snapshot: ThermalSnapshot) {
        lastSnapshot = snapshot
        appendHistory(snapshot.cpuCelsius.map(Self.normalizedCelsius) ?? 0)
        assignIfChanged(
            &tileModel,
            to: Self.makeTileModel(
                cpuLabel: cpuLabel,
                gaugeValue: gaugeValue,
                history: history,
                gpuLabel: gpuLabel
            )
        )
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
            unavailableReason: gaugeValue == nil ? "Temperature sensor unavailable" : nil,
            systemImage: "thermometer.medium"
        )
    }

    public var detailModel: DetailModel {
        var stats: [DetailModel.Stat] = []
        if let cpu = cpuCelsius { stats.append(.init(label: "CPU", value: cpu.celsiusFormatted())) }
        if let gpu = gpuCelsius { stats.append(.init(label: "GPU", value: gpu.celsiusFormatted())) }
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
