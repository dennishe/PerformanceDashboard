import Foundation

/// Snapshot of Apple Silicon Media Engine activity.
public struct MediaEngineSnapshot: MetricSnapshot {
    /// Average encoder power in milliwatts over the last sample window; `nil` on Intel.
    public let encodeMilliwatts: Double?
    /// Average decoder power in milliwatts over the last sample window; `nil` on Intel.
    public let decodeMilliwatts: Double?
}

/// Monitors the H.264/HEVC encode and decode engines via IOReport on Apple Silicon.
/// The `AVE` (encoder) and `VDEC` (decoder) channels are in the `PMP / Energy Counters`
/// IOReport group; values are millijoules per sample interval (≈ milliwatts at 1 s/poll).
public final class MediaEngineMonitorService: PollingMonitorBase<MediaEngineSnapshot> {
    #if arch(arm64)
    private let makeSampler: @MonitorActor @Sendable () -> any PMPSampling
    private let extractSnapshot: @Sendable (CFDictionary) -> MediaEngineSnapshot
    @MonitorActor private var sampler: (any PMPSampling)?

    override public init() {
        makeSampler = { PMPSampler.shared }
        extractSnapshot = MediaEngineSnapshotExtractor.snapshot(from:)
        super.init()
    }

    init(
        makeSampler: @escaping @MonitorActor @Sendable () -> any PMPSampling,
        extractSnapshot: @escaping @Sendable (CFDictionary) -> MediaEngineSnapshot =
            MediaEngineSnapshotExtractor.snapshot(from:)
    ) {
        self.makeSampler = makeSampler
        self.extractSnapshot = extractSnapshot
        super.init()
    }
    #endif

    @MonitorActor
    override public func setUp() {
        #if arch(arm64)
        let sampler = makeSampler()
        sampler.setUp()
        self.sampler = sampler
        #endif
    }

    @MonitorActor
    override public func sample() async -> MediaEngineSnapshot? {
        #if arch(arm64)
        guard let delta = sampler?.nextDelta() else {
            return MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
        }
        return extractSnapshot(delta)
        #else
        return MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
        #endif
    }
}

// MARK: - IOReport extraction (Apple Silicon only)

#if arch(arm64)
struct MediaEngineChannelSample: Sendable, Equatable {
    let name: String?
    let value: Int64
}

enum MediaEngineSnapshotExtractor {
    /// Extracts AVE/VDEC power from the shared `PMPSampler` delta.
    /// The `AVE` (encoder) and `VDEC` (decoder) channels are in `PMP / Energy Counters`;
    /// values are millijoules per sample interval (≈ milliwatts at 1 s/poll).
    static func snapshot(from delta: CFDictionary) -> MediaEngineSnapshot {
        snapshot(from: channelSamples(from: delta))
    }

    static func channelSamples(from delta: CFDictionary) -> [MediaEngineChannelSample] {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else {
            return []
        }

        return array.map { channel in
            MediaEngineChannelSample(
                name: channelName(from: channel),
                value: IOReport.integerValue(channel as CFDictionary)
            )
        }
    }

    private static func channelName(from channel: NSDictionary) -> String? {
        if let legend = channel["LegendChannel"] as? [Any], legend.count > 2 {
            return legend[2] as? String
        }

        return IOReport.channelName(channel as CFDictionary)
    }

    static func snapshot(from samples: [MediaEngineChannelSample]) -> MediaEngineSnapshot {
        var encode = Int64.min
        var decode = Int64.min
        for sample in samples {
            guard sample.value != Int64.min else { continue }
            switch sample.name {
            case "AVE":  encode = encode == Int64.min ? sample.value : encode + sample.value
            case "VDEC": decode = decode == Int64.min ? sample.value : decode + sample.value
            default: break
            }
        }
        return MediaEngineSnapshot(
            encodeMilliwatts: encode != Int64.min ? Double(max(0, encode)) : nil,
            decodeMilliwatts: decode != Int64.min ? Double(max(0, decode)) : nil
        )
    }
}
#endif
