import SwiftUI

/// Threshold levels for Media Engine combined load.
@MainActor
@Observable
public final class MediaEngineViewModel: MonitorViewModelBase<MediaEngineSnapshot> {
    private var lastSnapshot = MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)

    public var encodeMilliwatts: Double? { lastSnapshot.encodeMilliwatts }
    public var decodeMilliwatts: Double? { lastSnapshot.decodeMilliwatts }
    public var gaugeValue: Double? { combinedMilliwatts.map { min(1.0, max(0.0, $0 / adaptiveMax)) } }
    public var encodeLabel: String { encodeMilliwatts.map { "Enc: \($0.milliwattsFormatted())" } ?? "Enc: —" }
    public var decodeLabel: String { decodeMilliwatts.map { "Dec: \($0.milliwattsFormatted())" } ?? "Dec: —" }
    public var combinedLabel: String { combinedMilliwatts.map { $0.milliwattsFormatted() } ?? "—" }

    private var adaptiveMax: Double = 100.0  // mW; grows with observed values

    public var thresholdLevel: ThresholdLevel {
        MetricThresholds.mediaEngine.level(for: gaugeValue ?? 0)
    }

    private var combinedMilliwatts: Double? {
        switch (encodeMilliwatts, decodeMilliwatts) {
        case let (enc?, dec?): return enc + dec
        case let (enc?, nil): return enc
        case let (nil, dec?): return dec
        case (nil, nil): return nil
        }
    }

    override public func receive(_ snapshot: MediaEngineSnapshot) {
        lastSnapshot = snapshot
        let combinedMilliwatts = combinedMilliwatts
        if let combined = combinedMilliwatts, combined > adaptiveMax { adaptiveMax = combined }
        let normalized = combinedMilliwatts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        appendHistory(normalized)
        refreshTileModel()
    }

    override public func makeTileModel() -> MetricTileModel {
        MetricTileModel(
            title: "Media Engine",
            value: combinedLabel,
            gaugeValue: gaugeValue,
            gaugeColorProfile: gaugeValue == nil ? .inactive : .standard,
            history: history,
            thresholdLevel: MetricThresholds.mediaEngine.level(for: gaugeValue ?? 0),
            subtitle: decodeLabel,
            systemImage: "film.stack"
        )
    }

    public var detailModel: DetailModel {
        var stats: [DetailModel.Stat] = []
        if let enc = encodeMilliwatts { stats.append(.init(label: "Encode", value: enc.milliwattsFormatted())) }
        if let dec = decodeMilliwatts { stats.append(.init(label: "Decode", value: dec.milliwattsFormatted())) }
        return DetailModel(
            title: "Media Engine",
            systemImage: "film.stack",
            primaryValue: combinedLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }
}
