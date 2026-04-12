import Testing
@testable import PerformanceDashboard

@MainActor
private func makeViewModel(watts: [Double?] = []) -> PowerViewModel {
    let monitor = MockMonitor<PowerSnapshot>(snapshots: watts.map(PowerSnapshot.init(watts:)))
    return PowerViewModel(monitor: monitor, batcher: SynchronousBatcher())
}

@MainActor
private func startAndDrain(_ viewModel: PowerViewModel, passes: Int = 10) async {
    viewModel.start()
    for _ in 0..<passes {
        await Task.yield()
    }
}

@MainActor
struct PowerViewModelTests {

    @Test func watts_updatesFromStream() async {
        let viewModel = makeViewModel(watts: [15.5])
        await startAndDrain(viewModel)
        #expect(viewModel.watts == 15.5)
    }

    @Test func watts_isNilInitially() {
        let viewModel = makeViewModel()
        #expect(viewModel.watts == nil)
    }

    @Test func gaugeValue_isNil_whenWattsIsNil() {
        let viewModel = makeViewModel()
        #expect(viewModel.gaugeValue == nil)
    }

    @Test func gaugeValue_normalisesAgainstDefaultMax() async {
        let viewModel = makeViewModel(watts: [10.0])
        await startAndDrain(viewModel)
        #expect(viewModel.gaugeValue == 0.5)
    }

    @Test func adaptiveMax_growsWhenExceeded() async {
        let viewModel = makeViewModel(watts: [10.0, 50.0])
        await startAndDrain(viewModel)
        #expect(viewModel.gaugeValue == 1.0)
        #expect(viewModel.watts == 50.0)
    }

    @Test func wattsLabel_formatsToOneDecimalPlace() async {
        let viewModel = makeViewModel(watts: [12.3])
        await startAndDrain(viewModel)
        #expect(viewModel.wattsLabel == "12.3 W")
    }

    @Test func wattsLabel_showsDash_whenWattsIsNil() async {
        let viewModel = makeViewModel(watts: [nil])
        await startAndDrain(viewModel)
        #expect(viewModel.wattsLabel == "—")
    }

    @Test func thresholdLevel_normal_forLowDraw() async {
        let viewModel = makeViewModel(watts: [5.0])
        await startAndDrain(viewModel)
        #expect(viewModel.thresholdLevel == .normal)
    }

    @Test func thresholdLevel_critical_forHighDraw() async {
        let viewModel = makeViewModel(watts: [19.0])
        await startAndDrain(viewModel)
        #expect(viewModel.thresholdLevel == .critical)
    }

    @Test func history_appendsNormalizedValue() async {
        let viewModel = makeViewModel(watts: [10.0])
        await startAndDrain(viewModel)
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(abs((viewModel.history.last ?? -1) - 0.5) < 0.001)
    }

    @Test func history_appendsZero_whenWattsIsNil() async {
        let viewModel = makeViewModel(watts: [nil])
        await startAndDrain(viewModel)
        #expect(viewModel.history.count == Constants.historySamples)
        #expect(viewModel.history.last == 0)
    }

    @Test func stop_haltsUpdates() async {
        let viewModel = makeViewModel(watts: [12.5])
        await startAndDrain(viewModel)
        let wattsBeforeStop = viewModel.watts
        viewModel.stop()
        for _ in 0..<10 {
            await Task.yield()
        }
        #expect(viewModel.watts == wattsBeforeStop)
    }

    // MARK: - New coverage tests

    @Test func gaugeValue_clampedToOne_whenWattsExceedsAdaptiveMax() async {
        let viewModel = makeViewModel(watts: [50.0, 50.0])
        await startAndDrain(viewModel)
        #expect(viewModel.gaugeValue == 1.0)
    }

    @Test func gaugeValue_clampedToZero_whenWattsIsNegative() async {
        let viewModel = makeViewModel(watts: [-5.0])
        await startAndDrain(viewModel)
        #expect((viewModel.gaugeValue ?? -1) >= 0)
    }

    @Test func detailModel_showsDrawStat_whenWattsPresent() async {
        let viewModel = makeViewModel(watts: [12.3])
        await startAndDrain(viewModel)
        #expect(viewModel.detailModel.stats.count == 1)
        #expect(viewModel.detailModel.stats[0].label == "Draw")
        #expect(viewModel.detailModel.stats[0].value == "12.30 W")
    }

    @Test func detailModel_noStats_whenWattsNil() async {
        let viewModel = makeViewModel(watts: [nil])
        await startAndDrain(viewModel)
        #expect(viewModel.detailModel.stats.isEmpty)
    }

    @Test func detailModel_hasCorrectMetadata() async {
        let viewModel = makeViewModel(watts: [10.0])
        await startAndDrain(viewModel)
        #expect(viewModel.detailModel.title == "Power")
        #expect(viewModel.detailModel.systemImage == "bolt")
    }

    @Test func adaptiveMax_doesNotDecreaseForLowerValue() async {
        let viewModel = makeViewModel(watts: [40.0, 5.0])
        await startAndDrain(viewModel)
        #expect(viewModel.gaugeValue != nil)
        #expect((viewModel.gaugeValue ?? 1) < 0.2)
    }
}
