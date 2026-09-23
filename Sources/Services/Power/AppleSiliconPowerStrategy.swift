#if arch(arm64)
import Foundation

/// Reads total system power from the IOReport "Energy Model" group (Apple Silicon only).
struct AppleSiliconPowerStrategy: PowerStrategy {
    private let ref: IOReportSubscriptionRef
    private let channels: CFMutableDictionary
    private var prevSample: CFDictionary?
    private var channelDescriptors: [EnergyChannelDescriptor] = []

    init?() {
        guard let ch = IOReport.copyChannels(group: "Energy Model"),
              let sub = IOReport.subscribe(channels: ch) else { return nil }
        ref = sub.ref
        channels = sub.subscribedChannels
        prevSample = IOReport.takeSample(sub.ref, channels: sub.subscribedChannels)
    }

    mutating func nextWatts() -> Double? {
        nextSnapshot().watts
    }

    mutating func nextSnapshot() -> PowerSnapshot {
        let curr = IOReport.takeSample(ref, channels: channels)
        defer { prevSample = curr }
        guard let prev = prevSample, let curr,
              let delta = IOReport.sampleDelta(prev: prev, curr: curr) else { return PowerSnapshot(watts: nil) }
        return extractSnapshot(from: delta)
    }

    // MARK: - Private

    private mutating func extractSnapshot(from delta: CFDictionary) -> PowerSnapshot {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else { return PowerSnapshot(watts: nil) }

        if channelDescriptors.isEmpty {
            channelDescriptors = EnergyChannelDescriptor.makeDescriptors(from: array)
        }

        guard !channelDescriptors.isEmpty else { return PowerSnapshot(watts: nil) }

        let readings = channelDescriptors.compactMap { descriptor -> (EnergyChannelDescriptor, Int64)? in
            guard descriptor.index < array.count else { return nil }
            return (descriptor, IOReport.integerValue(array[descriptor.index] as CFDictionary))
        }
        return EnergyChannelDescriptor.snapshot(from: readings)
    }
}

struct EnergyChannelDescriptor {
    let index: Int
    let scale: Double
    let component: String

    static func makeDescriptors(from channels: [NSDictionary]) -> [EnergyChannelDescriptor] {
        channels.enumerated().compactMap { index, channel in
            descriptor(name: IOReport.channelName(channel as CFDictionary) ?? "", index: index)
        }
    }

    static func descriptor(name: String, index: Int) -> EnergyChannelDescriptor? {
        // CPU Energy covers the per-core channels; every other *Energy channel uses nanojoules.
        if name == "CPU Energy" {
            return EnergyChannelDescriptor(index: index, scale: 1 / 1_000.0, component: "CPU")
        }
        guard name.hasSuffix("Energy") else { return nil }
        let component = name == "GPU Energy" ? "GPU" : "Other"
        return EnergyChannelDescriptor(index: index, scale: 1 / 1_000_000_000.0, component: component)
    }

    static func snapshot(from readings: [(EnergyChannelDescriptor, Int64)]) -> PowerSnapshot {
        var componentWatts: [String: Double] = [:]
        for (descriptor, value) in readings where value != Int64.min && value >= 0 {
            componentWatts[descriptor.component, default: 0] += Double(value) * descriptor.scale
        }
        guard !componentWatts.isEmpty else { return PowerSnapshot(watts: nil) }
        let components = ["CPU", "GPU", "Other"].compactMap { name -> PowerComponent? in
            componentWatts[name].map { PowerComponent(name: name, watts: $0) }
        }
        return PowerSnapshot(watts: components.reduce(0) { $0 + $1.watts }, components: components)
    }
}
#endif

/// No-op strategy returned when the platform strategy cannot be initialised.
struct NullPowerStrategy: PowerStrategy {
    mutating func nextWatts() -> Double? { nil }
}
