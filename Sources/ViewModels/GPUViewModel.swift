import SwiftUI

/// Threshold configuration for GPU utilisation.
@MainActor
@Observable
public final class GPUViewModel: MonitorViewModelBase<GPUSnapshot> {
    public private(set) var usage: Double?
    public var thresholdLevel: ThresholdLevel { GPUThreshold().level(for: usage ?? 0) }
    public var usageLabel: String {
        guard let usage else { return "N/A" }
        return String(format: "%.1f%%", usage * 100)
    }

    override public func receive(_ snapshot: GPUSnapshot) {
        usage = snapshot.usage
        if let value = snapshot.usage {
            appendHistory(value)
        }
    }
}
