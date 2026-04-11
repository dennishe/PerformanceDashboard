import Testing
import Darwin
@testable import PerformanceDashboard

struct CPUMonitorCoreSamplingTests {
    @Test func sample_returnsCoresOnRealSystem() {
        let sample = CPUMonitorService.sample(previous: [])
        #expect(!sample.loadInfo.isEmpty)
        #expect(sample.usage == 0)
        #expect(sample.cores.isEmpty)
    }

    @Test func sample_returnsDeltaUsage_onSecondCall() {
        let first = CPUMonitorService.sample(previous: [])
        let second = CPUMonitorService.sample(previous: first.loadInfo)
        #expect(second.usage >= 0)
        #expect(second.usage <= 1)
        #expect(second.cores.count == first.loadInfo.count)
    }

    @Test func computeCoreUsages_returnsPerCoreFractions() {
        let previous = [
            makeCoreLoad(user: 0, system: 0, idle: 0, nice: 0),
            makeCoreLoad(user: 0, system: 0, idle: 100, nice: 0)
        ]
        let current = [
            makeCoreLoad(user: 30, system: 20, idle: 50, nice: 0),
            makeCoreLoad(user: 0, system: 0, idle: 200, nice: 0)
        ]

        let usages = CPUMonitorService.computeCoreUsages(current: current, previous: previous)

        #expect(usages.count == 2)
        #expect(abs(usages[0] - 0.5) < 0.0001)
        #expect(usages[1] == 0)
    }

    @Test func mapCoreStats_assignsCoreKindsFromTopology() {
        let topology = CPUCoreTopology(
            cores: [
                .init(index: 0, kind: "Performance"),
                .init(index: 1, kind: "Efficiency")
            ]
        )

        let stats = CPUMonitorService.mapCoreStats(usages: [0.7, 0.2], topology: topology)

        #expect(stats[0] == CPUCoreStat(index: 0, usage: 0.7, kind: "Performance"))
        #expect(stats[1] == CPUCoreStat(index: 1, usage: 0.2, kind: "Efficiency"))
    }

    private func makeCoreLoad(
        user: UInt32,
        system: UInt32,
        idle: UInt32,
        nice: UInt32
    ) -> processor_cpu_load_info {
        var load = processor_cpu_load_info()
        load.cpu_ticks.0 = user
        load.cpu_ticks.1 = system
        load.cpu_ticks.2 = idle
        load.cpu_ticks.3 = nice
        return load
    }
}
