import Foundation
import Testing
@testable import PerformanceDashboard

#if arch(arm64)
struct MediaEngineSnapshotExtractorTests {
    @Test func extractor_accumulatesEncodeAndDecodeChannels() {
        let snapshot = MediaEngineSnapshotExtractor.snapshot(from: [
            MediaEngineChannelSample(name: "AVE", value: 12),
            MediaEngineChannelSample(name: "AVE", value: 8),
            MediaEngineChannelSample(name: "VDEC", value: 5),
            MediaEngineChannelSample(name: "Other", value: 99)
        ])

        #expect(snapshot == MediaEngineSnapshot(encodeMilliwatts: 20, decodeMilliwatts: 5))
    }

    @Test func extractor_clampsNegativeChannelsToZero() {
        let snapshot = MediaEngineSnapshotExtractor.snapshot(from: [
            MediaEngineChannelSample(name: "AVE", value: -20),
            MediaEngineChannelSample(name: "VDEC", value: -5)
        ])

        #expect(snapshot == MediaEngineSnapshot(encodeMilliwatts: 0, decodeMilliwatts: 0))
    }

    @Test func extractor_ignoresUnknownAndInvalidChannels() {
        let snapshot = MediaEngineSnapshotExtractor.snapshot(from: [
            MediaEngineChannelSample(name: "ANE", value: 50),
            MediaEngineChannelSample(name: "AVE", value: Int64.min),
            MediaEngineChannelSample(name: nil, value: 40)
        ])

        #expect(snapshot == MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil))
    }

    @Test func extractor_returnsSingleEncodeOrDecodeChannelWhenOnlyOneExists() {
        let encodeOnly = MediaEngineSnapshotExtractor.snapshot(from: [
            MediaEngineChannelSample(name: "AVE", value: 25)
        ])
        let decodeOnly = MediaEngineSnapshotExtractor.snapshot(from: [
            MediaEngineChannelSample(name: "VDEC", value: 10)
        ])

        #expect(encodeOnly == MediaEngineSnapshot(encodeMilliwatts: 25, decodeMilliwatts: nil))
        #expect(decodeOnly == MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: 10))
    }

    @Test func extractor_returnsUnavailableSnapshotForEmptySamples() {
        let snapshot = MediaEngineSnapshotExtractor.snapshot(from: [])

        #expect(snapshot == MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil))
    }

    @Test func extractor_snapshotFromDelta_usesFallbackChannelNames() {
        let delta = [
            "IOReportChannels": [
                ["LegendChannel": [0, 0, "AVE"]],
                ["LegendChannel": [0, 0, "VDEC"]]
            ]
        ] as NSDictionary

        let snapshot = MediaEngineSnapshotExtractor.snapshot(from: delta as CFDictionary)

        #expect(snapshot == MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil))
    }
}
#endif
