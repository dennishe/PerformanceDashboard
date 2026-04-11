import Testing
@testable import PerformanceDashboard

struct MetricThresholdsTests {
    @Test func standardThresholds_shareTheSameBoundaries() {
        let thresholds: [any ThresholdEvaluating] = [
            MetricThresholds.cpu,
            MetricThresholds.gpu,
            MetricThresholds.accelerator,
            MetricThresholds.power,
            MetricThresholds.mediaEngine
        ]

        for threshold in thresholds {
            #expect(threshold.level(for: 0.5) == .normal)
            #expect(threshold.level(for: 0.7) == .warning)
            #expect(threshold.level(for: 0.9) == .critical)
        }
    }

    @Test func relaxedThresholds_shareTheSameBoundaries() {
        let thresholds: [any ThresholdEvaluating] = [
            MetricThresholds.memory,
            MetricThresholds.fan
        ]

        for threshold in thresholds {
            #expect(threshold.level(for: 0.6) == .normal)
            #expect(threshold.level(for: 0.8) == .warning)
            #expect(threshold.level(for: 0.95) == .critical)
        }
    }

    @Test func diskAndThermalThresholds_keepTheirCustomBoundaries() {
        #expect(MetricThresholds.disk.level(for: 0.7) == .normal)
        #expect(MetricThresholds.disk.level(for: 0.8) == .warning)
        #expect(MetricThresholds.disk.level(for: 0.95) == .critical)

        #expect(MetricThresholds.thermal.level(for: 0.6) == .normal)
        #expect(MetricThresholds.thermal.level(for: 0.8) == .warning)
        #expect(MetricThresholds.thermal.level(for: 0.9) == .critical)
    }

    @Test func batteryThreshold_isInverted() {
        #expect(MetricThresholds.battery.level(for: 0.5) == .normal)
        #expect(MetricThresholds.battery.level(for: 0.15) == .warning)
        #expect(MetricThresholds.battery.level(for: 0.05) == .critical)
    }

    @Test func networkThreshold_usesThroughputBands() {
        #expect(MetricThresholds.network.level(for: 10_000_000) == .normal)
        #expect(MetricThresholds.network.level(for: 75_000_000) == .warning)
        #expect(MetricThresholds.network.level(for: 150_000_000) == .critical)
    }

    @Test func wirelessThreshold_tracksSignalQuality() {
        #expect(MetricThresholds.wireless.level(for: 0.6) == .normal)
        #expect(MetricThresholds.wireless.level(for: 0.4) == .warning)
        #expect(MetricThresholds.wireless.level(for: 0.2) == .critical)
    }
}
