import Foundation

/// Snapshot of ANE accelerator load.
public struct AcceleratorSnapshot: MetricSnapshot {
    /// ANE utilisation as a fraction in [0, 1]. `nil` if not available (Intel or IOReport unavailable).
    public let aneUsage: Double?
}

/// Monitors Apple ANE load via the private IOReport framework.
/// Uses two-sample delta energy-model data; only meaningful on Apple Silicon.
public final class AcceleratorMonitorService: PollingMonitorBase<AcceleratorSnapshot> {
    #if arch(arm64)
    private let makeSampler: @MonitorActor @Sendable () -> any PMPSampling
    private let extractUsage: @Sendable (CFDictionary, Double) -> (usage: Double?, maxDelta: Double)

    @MonitorActor private var sampler: (any PMPSampling)?
    @MonitorActor private var maxDelta = 1.0

    override public init() {
        makeSampler = { PMPSampler.shared }
        extractUsage = ANEUsageExtractor.extract(from:currentMaxDelta:)
        super.init()
    }

    init(
        makeSampler: @escaping @MonitorActor @Sendable () -> any PMPSampling,
        extractUsage: @escaping @Sendable (CFDictionary, Double) -> (usage: Double?, maxDelta: Double) =
            ANEUsageExtractor.extract(from:currentMaxDelta:)
    ) {
        self.makeSampler = makeSampler
        self.extractUsage = extractUsage
        super.init()
    }
    #endif

    @MonitorActor
    override public func setUp() {
        #if arch(arm64)
        let sampler = makeSampler()
        sampler.setUp()
        self.sampler = sampler
        maxDelta = 1.0
        #endif
    }

    @MonitorActor
    override public func sample() async -> AcceleratorSnapshot? {
        #if arch(arm64)
        guard let delta = sampler?.nextDelta() else {
            return AcceleratorSnapshot(aneUsage: nil)
        }
        let result = extractUsage(delta, maxDelta)
        maxDelta = result.maxDelta
        return AcceleratorSnapshot(aneUsage: result.usage)
        #else
        return AcceleratorSnapshot(aneUsage: nil)
        #endif
    }
}

// MARK: – IOReport state (ARM64 only)

#if arch(arm64)
struct ANEChannelSample: Sendable, Equatable {
    let name: String?
    let value: Int64
}

enum ANEUsageExtractor {
    static func extract(
        from delta: CFDictionary,
        currentMaxDelta: Double
    ) -> (usage: Double?, maxDelta: Double) {
        extract(from: channelSamples(from: delta), currentMaxDelta: currentMaxDelta)
    }

    static func channelSamples(from delta: CFDictionary) -> [ANEChannelSample] {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else { return [] }

        return array.map { channel in
            ANEChannelSample(
                name: channelName(from: channel),
                value: integerValue(from: channel)
            )
        }
    }

    static func extract(
        from samples: [ANEChannelSample],
        currentMaxDelta: Double
    ) -> (usage: Double?, maxDelta: Double) {
        var total: Int64 = 0
        var found = false
        for channel in samples {
            guard channel.name == "ANE" else { continue }
            let raw = channel.value
            // INT64_MIN is the sentinel for "privileged / unavailable".
            guard raw != Int64.min, raw >= 0 else { continue }
            total += raw
            found = true
        }
        guard found else { return (nil, currentMaxDelta) }
        let value = Double(total)
        let maxDelta = max(currentMaxDelta, value)
        let usage = maxDelta > 0 ? min(1.0, max(0.0, value / maxDelta)) : nil
        return (usage, maxDelta)
    }

    private static func channelName(from channel: NSDictionary) -> String? {
        if let legend = channel["LegendChannel"] as? [Any], legend.count > 2 {
            return legend[2] as? String
        }

        return IOReport.channelName(channel as CFDictionary)
    }

    private static func integerValue(from channel: NSDictionary) -> Int64 {
        if let number = channel["SimpleValue"] as? NSNumber {
            return number.int64Value
        }

        if let number = channel["Value"] as? NSNumber {
            return number.int64Value
        }

        return IOReport.integerValue(channel as CFDictionary)
    }
}
#endif
