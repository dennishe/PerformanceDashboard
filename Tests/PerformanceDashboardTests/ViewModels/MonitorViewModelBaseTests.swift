import Testing
@testable import PerformanceDashboard

@MainActor
struct MonitorViewModelBaseTests {
    private struct TestSnapshot: MetricSnapshot {
        let value: Double
    }

    private final class RecordingViewModel: MonitorViewModelBase<TestSnapshot> {
        var receivedValues: [Double] = []

        override func receive(_ snapshot: TestSnapshot) {
            receivedValues.append(snapshot.value)
            appendHistory(snapshot.value)
            refreshTileModel()
        }

        override func makeTileModel() -> MetricTileModel {
            MetricTileModel(
                title: "Test",
                value: "\(receivedValues.last ?? 0)",
                gaugeValue: receivedValues.last,
                history: history,
                thresholdLevel: .normal,
                systemImage: "checkmark"
            )
        }
    }

    @Test func injectedSynchronousBatcher_appliesSnapshotsWithoutDelay() async {
        let monitor = MockMonitor(snapshots: [
            TestSnapshot(value: 0.25),
            TestSnapshot(value: 0.5)
        ])
        let viewModel = RecordingViewModel(monitor: monitor, batcher: SynchronousBatcher())

        viewModel.start()
        await waitForAsyncUpdates()

        #expect(viewModel.receivedValues == [0.25, 0.5])
        #expect(Array(viewModel.history.suffix(2)) == [0.25, 0.5])
    }
}
