import SwiftUI

/// Threshold levels for Media Engine combined load.
@MainActor
@Observable
public final class MediaEngineViewModel: MonitorViewModelBase<MediaEngineSnapshot> {
    public private(set) var tileModel = MetricTileModel(
        title: "Media Engine",
        value: "—",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .normal,
        subtitle: "Dec: —",
        systemImage: "film.stack"
    )

    @ObservationIgnored
    public private(set) var encodeMilliwatts: Double?
    @ObservationIgnored
    public private(set) var decodeMilliwatts: Double?
    @ObservationIgnored
    public private(set) var gaugeValue: Double?
    @ObservationIgnored
    public private(set) var encodeLabel: String = "Enc: —"
    @ObservationIgnored
    public private(set) var decodeLabel: String = "Dec: —"
    @ObservationIgnored
    public private(set) var combinedLabel: String = "—"

    private var adaptiveMax: Double = 100.0  // mW; grows with observed values

    public var thresholdLevel: ThresholdLevel {
        MediaEngineThreshold().level(for: gaugeValue ?? 0)
    }

    private var combinedMilliwatts: Double? {
        switch (encodeMilliwatts, decodeMilliwatts) {
        case let (enc?, dec?): return enc + dec
        case let (enc?, nil): return enc
        case let (nil, dec): return dec
        }
    }

    override public func receive(_ snapshot: MediaEngineSnapshot) {
        encodeMilliwatts = snapshot.encodeMilliwatts
        decodeMilliwatts = snapshot.decodeMilliwatts
        let combinedMilliwatts = combinedMilliwatts
        if let combined = combinedMilliwatts, combined > adaptiveMax { adaptiveMax = combined }
        let normalized = combinedMilliwatts.map { min(1.0, $0 / adaptiveMax) } ?? 0
        gaugeValue = combinedMilliwatts.map { min(1.0, max(0.0, $0 / adaptiveMax)) }
        encodeLabel = snapshot.encodeMilliwatts.map { String(format: "Enc: %.0f mW", $0) } ?? "Enc: —"
        decodeLabel = snapshot.decodeMilliwatts.map { String(format: "Dec: %.0f mW", $0) } ?? "Dec: —"
        combinedLabel = combinedMilliwatts.map { String(format: "%.0f mW", $0) } ?? "—"
        appendHistory(normalized)
        let newTileModel = Self.makeTileModel(
            combinedLabel: combinedLabel,
            gaugeValue: gaugeValue,
            history: history,
            decodeLabel: decodeLabel
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        combinedLabel: String,
        gaugeValue: Double?,
        history: [Double],
        decodeLabel: String
    ) -> MetricTileModel {
        MetricTileModel(
            title: "Media Engine",
            value: combinedLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: MediaEngineThreshold().level(for: gaugeValue ?? 0),
            subtitle: decodeLabel,
            systemImage: "film.stack"
        )
    }
}
