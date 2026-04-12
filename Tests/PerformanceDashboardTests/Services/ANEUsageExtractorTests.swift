import Foundation
import Testing
@testable import PerformanceDashboard

#if arch(arm64)
struct ANEUsageExtractorTests {
    @Test func extractor_returnsNil_whenNoANEChannelsExist() {
        let result = ANEUsageExtractor.extract(
            from: [ANEChannelSample(name: "AVE", value: 12)],
            currentMaxDelta: 1
        )

        #expect(result.usage == nil)
        #expect(result.maxDelta == 1)
    }

    @Test func extractor_ignoresInvalidAndNegativeValues() {
        let result = ANEUsageExtractor.extract(
            from: [
                ANEChannelSample(name: "ANE", value: Int64.min),
                ANEChannelSample(name: "ANE", value: -5)
            ],
            currentMaxDelta: 4
        )

        #expect(result.usage == nil)
        #expect(result.maxDelta == 4)
    }

    @Test func extractor_normalizesAgainstRunningMaximum_andGrowsWhenExceeded() {
        let first = ANEUsageExtractor.extract(
            from: [ANEChannelSample(name: "ANE", value: 4)],
            currentMaxDelta: 8
        )
        let second = ANEUsageExtractor.extract(
            from: [ANEChannelSample(name: "ANE", value: 12)],
            currentMaxDelta: first.maxDelta
        )

        #expect(first.usage == 0.5)
        #expect(first.maxDelta == 8)
        #expect(second.usage == 1.0)
        #expect(second.maxDelta == 12)
    }

    @Test func extractor_snapshotFromDelta_usesFallbackLegendChannelAndSimpleValue() {
        let delta = [
            "IOReportChannels": [
                ["LegendChannel": [0, 0, "ANE"], "SimpleValue": 9],
                ["LegendChannel": [0, 0, "Other"], "SimpleValue": 50]
            ]
        ] as NSDictionary

        let result = ANEUsageExtractor.extract(from: delta as CFDictionary, currentMaxDelta: 18)

        #expect(result.usage == 0.5)
        #expect(result.maxDelta == 18)
    }
}
#endif
