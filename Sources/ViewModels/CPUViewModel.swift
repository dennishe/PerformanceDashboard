import SwiftUI

/// Threshold configuration for CPU utilisation.
@MainActor
@Observable
public final class CPUViewModel: MonitorViewModelBase<CPUSnapshot> {
    public private(set) var usage: Double = 0
    public var thresholdLevel: ThresholdLevel { CPUThreshold().level(for: usage) }
    public var usageLabel: String { String(format: "%.1f%%", usage * 100) }

    override public func receive(_ snapshot: CPUSnapshot) {
        usage = snapshot.usage
        appendHistory(snapshot.usage)
    }
}
