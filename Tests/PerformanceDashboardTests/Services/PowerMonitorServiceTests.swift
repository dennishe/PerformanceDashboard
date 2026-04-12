import Foundation
import Testing
@testable import PerformanceDashboard

struct PowerMonitorServiceTests {
    private struct MockPowerStrategy: PowerStrategy {
        private var readings: [Double?]

        @MonitorActor
        init(readings: [Double?]) {
            self.readings = readings
        }

        mutating func nextWatts() -> Double? {
            guard !readings.isEmpty else { return nil }
            return readings.removeFirst()
        }
    }

    private final class StrategyFactoryProbe: @unchecked Sendable {
        private var readingsBySetup: [[Double?]]

        init(readingsBySetup: [[Double?]]) {
            self.readingsBySetup = readingsBySetup
        }

        @MonitorActor
        func makeStrategy() -> any PowerStrategy {
            let nextReadings = readingsBySetup.isEmpty ? [] : readingsBySetup.removeFirst()
            return MockPowerStrategy(readings: nextReadings)
        }
    }

    // MARK: - PowerSnapshot

    @Test func powerSnapshot_storesWatts() {
        let snapshot = PowerSnapshot(watts: 15.5)
        #expect(snapshot.watts == 15.5)
    }

    @Test func powerSnapshot_allowsNilWatts() {
        let snapshot = PowerSnapshot(watts: nil)
        #expect(snapshot.watts == nil)
    }

    @Test func powerSnapshot_zeroWatts_isValid() {
        let snapshot = PowerSnapshot(watts: 0)
        #expect(snapshot.watts == 0)
    }

    @Test func powerSnapshot_highWatts_isValid() {
        let snapshot = PowerSnapshot(watts: 250.0)
        #expect(snapshot.watts == 250.0)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = PowerMonitorService()
        let _: any MetricMonitorProtocol<PowerSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = PowerMonitorService()
        _ = service.stream()
        service.stop()
    }

    @Test @MainActor func sample_returnsNilWatts_whenStrategyHasNotBeenSetUp() async {
        let service = PowerMonitorService(makeStrategy: {
            MockPowerStrategy(readings: [15.5])
        })

        let snapshot = await service.sample()

        #expect(snapshot == PowerSnapshot(watts: nil))
    }

    @Test @MainActor func sample_returnsWattsFromInjectedStrategy() async {
        let service = PowerMonitorService(makeStrategy: {
            MockPowerStrategy(readings: [15.5, nil])
        })

        await service.setUp()
        let firstSnapshot = await service.sample()
        let secondSnapshot = await service.sample()

        #expect(firstSnapshot == PowerSnapshot(watts: 15.5))
        #expect(secondSnapshot == PowerSnapshot(watts: nil))
    }

    @Test @MainActor func setUp_replacesStrategyWithFreshFactoryOutput() async {
        let probe = StrategyFactoryProbe(readingsBySetup: [[10.0], [20.0]])
        let service = PowerMonitorService(makeStrategy: {
            probe.makeStrategy()
        })

        await service.setUp()
        let firstSnapshot = await service.sample()
        await service.setUp()
        let secondSnapshot = await service.sample()

        #expect(firstSnapshot == PowerSnapshot(watts: 10.0))
        #expect(secondSnapshot == PowerSnapshot(watts: 20.0))
    }
}
