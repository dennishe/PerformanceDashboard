import SwiftUI

/// Threshold levels for power draw.
@MainActor
@Observable
public final class PowerViewModel: MonitorViewModelBase<PowerSnapshot> {
    public private(set) var watts: Double?

    private var adaptiveMax: Double = 20.0  // Start at 20 W; grows with observed values

    public var gaugeValue: Double? {
        guard let watts else { return nil }
        return min(1.0, max(0.0, watts / adaptiveMax))
    }

    public var wattsLabel: String {
        guard let watts else { return "—" }
        return String(format: "%.1f W", watts)
    }

    public var thresholdLevel: ThresholdLevel {
        PowerThreshold().level(for: gaugeValue ?? 0)
    }

    override public func receive(_ snapshot: PowerSnapshot) {
        watts = snapshot.watts
        if let newWatts = snapshot.watts, newWatts > adaptiveMax { adaptiveMax = newWatts }
        let normalized = snapshot.watts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        appendHistory(normalized)
    }
}
