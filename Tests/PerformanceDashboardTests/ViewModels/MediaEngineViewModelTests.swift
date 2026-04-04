import Testing
@testable import PerformanceDashboard

@MainActor
struct MediaEngineViewModelTests {

    @Test func encodeAndDecodeMilliwatts_updateFromStream() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 4.0, decodeMilliwatts: 54.0)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.encodeMilliwatts == 4.0)
        #expect(viewModel.decodeMilliwatts == 54.0)
    }

    @Test func gaugeValue_isNil_whenBothAreNil() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_usesCombinedValue() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 30.0, decodeMilliwatts: 20.0)]  // 50/100 = 0.5
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func gaugeValue_usesEncodeOnly_whenDecodeIsNil() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 50.0, decodeMilliwatts: nil)]  // 50/100 = 0.5
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func gaugeValue_usesDecodeOnly_whenEncodeIsNil() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: 50.0)]  // 50/100 = 0.5
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func adaptiveMax_growsWhenCombinedExceedsDefault() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 60.0, decodeMilliwatts: 80.0)]  // 140 > 100
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        // adaptiveMax grows to 140; gaugeValue = 140/140 = 1.0
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func encodeLabel_formatsMilliwatts() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 12.0, decodeMilliwatts: nil)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.encodeLabel == "Enc: 12 mW")
    }

    @Test func encodeLabel_showsDash_whenNil() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.encodeLabel == "Enc: —")
    }

    @Test func decodeLabel_formatsMilliwatts() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: 54.0)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.decodeLabel == "Dec: 54 mW")
    }

    @Test func decodeLabel_showsDash_whenNil() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.decodeLabel == "Dec: —")
    }

    @Test func combinedLabel_showsSum() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 30.0, decodeMilliwatts: 20.0)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.combinedLabel == "50 mW")
    }

    @Test func combinedLabel_showsDash_whenBothNil() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.combinedLabel == "—")
    }

    @Test func thresholdLevel_normal_forLowLoad() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 20.0, decodeMilliwatts: 20.0)]  // 40/100 = 0.4 < 0.6
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func history_appendsNormalizedCombined() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 30.0, decodeMilliwatts: 20.0)]  // 50/100 = 0.5
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.history.count == 1)
        #expect(abs(viewModel.history[0] - 0.5) < 0.001)
    }

    @Test func stop_haltsUpdates() async {
        let monitor = MockMonitor<MediaEngineSnapshot>()
        monitor.snapshots = [MediaEngineSnapshot(encodeMilliwatts: 4.0, decodeMilliwatts: 54.0)]
        let viewModel = MediaEngineViewModel(monitor: monitor)
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(50))
        let encBeforeStop = viewModel.encodeMilliwatts
        viewModel.stop()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.encodeMilliwatts == encBeforeStop)
    }
}
