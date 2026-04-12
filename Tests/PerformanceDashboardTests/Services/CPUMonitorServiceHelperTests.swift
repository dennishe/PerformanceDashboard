import Darwin
import Testing
@testable import PerformanceDashboard

struct CPUMonitorServiceHelperTests {
    @Test func processFraction_returnsZero_whenTimebaseDenominatorIsZero() {
        let fraction = CPUMonitorService.processFraction(
            deltaTaskTicks: 1_000,
            elapsedNanoseconds: 1_000_000,
            timebaseNumerator: 1,
            timebaseDenominator: 0
        )

        #expect(fraction == 0)
    }

    @Test func loadInfoArray_mapsTicksForEachProcessor() {
        let values: [integer_t] = [
            10, 20, 30, 40,
            1, 2, 3, 4
        ]

        let result = values.withUnsafeBufferPointer { buffer -> [processor_cpu_load_info] in
            guard let baseAddress = buffer.baseAddress else {
                Issue.record("Expected CPU tick values for loadInfoArray test")
                return []
            }

            return CPUMonitorService.loadInfoArray(
                from: UnsafeMutablePointer(mutating: baseAddress),
                processorCount: 2
            )
        }

        #expect(result.count == 2)
        #expect(result[0].cpu_ticks.0 == 10)
        #expect(result[0].cpu_ticks.1 == 20)
        #expect(result[0].cpu_ticks.2 == 30)
        #expect(result[0].cpu_ticks.3 == 40)
        #expect(result[1].cpu_ticks.0 == 1)
        #expect(result[1].cpu_ticks.1 == 2)
        #expect(result[1].cpu_ticks.2 == 3)
        #expect(result[1].cpu_ticks.3 == 4)
    }
}
