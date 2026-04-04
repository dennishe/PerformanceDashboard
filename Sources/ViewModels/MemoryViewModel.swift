import SwiftUI

/// Threshold configuration for memory pressure.
@MainActor
@Observable
public final class MemoryViewModel: MonitorViewModelBase<MemorySnapshot> {
    public private(set) var usage: Double = 0
    public private(set) var usedBytes: UInt64 = 0
    public private(set) var totalBytes: UInt64 = 0
    public var thresholdLevel: ThresholdLevel { MemoryThreshold().level(for: usage) }
    public var usageLabel: String { String(format: "%.1f%%", usage * 100) }
    public var usedLabel: String { ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory) }
    public var totalLabel: String { ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory) }

    override public func receive(_ snapshot: MemorySnapshot) {
        usage      = snapshot.usage
        usedBytes  = snapshot.used
        totalBytes = snapshot.total
        appendHistory(snapshot.usage)
    }
}
