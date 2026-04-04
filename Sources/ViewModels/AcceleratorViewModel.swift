import SwiftUI

/// Threshold configuration for ANE utilisation.
@MainActor
@Observable
public final class AcceleratorViewModel: MonitorViewModelBase<AcceleratorSnapshot> {
    public private(set) var aneUsage: Double?
    public var thresholdLevel: ThresholdLevel { AcceleratorThreshold().level(for: aneUsage ?? 0) }
    public var usageLabel: String {
        guard let aneUsage else { return "N/A" }
        return String(format: "%.1f%%", aneUsage * 100)
    }

    override public func receive(_ snapshot: AcceleratorSnapshot) {
        aneUsage = snapshot.aneUsage
        if let value = snapshot.aneUsage {
            appendHistory(value)
        }
    }
}
