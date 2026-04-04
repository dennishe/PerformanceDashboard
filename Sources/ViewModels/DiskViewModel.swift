import SwiftUI

/// Threshold configuration for disk usage.
@MainActor
@Observable
public final class DiskViewModel: MonitorViewModelBase<DiskSnapshot> {
    public private(set) var usage: Double = 0
    public private(set) var totalBytes: Int64 = 0
    public private(set) var availableBytes: Int64 = 0
    public var thresholdLevel: ThresholdLevel { DiskThreshold().level(for: usage) }
    public var usageLabel: String { String(format: "%.1f%%", usage * 100) }
    public var availableLabel: String { ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file) }
    public var totalLabel: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }

    override public func receive(_ snapshot: DiskSnapshot) {
        usage          = snapshot.usage
        totalBytes     = snapshot.total
        availableBytes = snapshot.available
        appendHistory(snapshot.usage)
    }
}
