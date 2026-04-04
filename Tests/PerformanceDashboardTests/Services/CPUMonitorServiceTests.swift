import Testing
import Darwin
@testable import PerformanceDashboard

struct CPUMonitorServiceTests {
    // MARK: - computeUsage unit tests

    @Test func computeUsage_returnsZero_whenBothArraysEmpty() {
        let result = CPUMonitorService.computeUsage(current: [], previous: [])
        #expect(result == 0)
    }

    @Test func computeUsage_returnsZero_whenAllTicksAreIdle() {
        let pre = makeCoreLoad(user: 0, system: 0, idle: 100, nice: 0)
        let cur = makeCoreLoad(user: 0, system: 0, idle: 200, nice: 0)
        let result = CPUMonitorService.computeUsage(current: [cur], previous: [pre])
        #expect(result == 0)
    }

    @Test func computeUsage_returnsOne_whenAllTicksAreBusy() {
        let pre = makeCoreLoad(user: 0, system: 0, idle: 0, nice: 0)
        let cur = makeCoreLoad(user: 100, system: 100, idle: 0, nice: 0)
        let result = CPUMonitorService.computeUsage(current: [cur], previous: [pre])
        #expect(result == 1.0)
    }

    @Test func computeUsage_returnsCorrectFraction_withKnownDeltas() {
        // 75 busy ticks out of 100 total => 0.75
        let pre = makeCoreLoad(user: 0, system: 0, idle: 0, nice: 0)
        let cur = makeCoreLoad(user: 50, system: 25, idle: 25, nice: 0)
        let result = CPUMonitorService.computeUsage(current: [cur], previous: [pre])
        #expect(abs(result - 0.75) < 0.0001)
    }

    @Test func computeUsage_averagesAcrossMultipleCores() {
        // Core 0: 100% busy, Core 1: 0% busy → average 50%
        let pre0 = makeCoreLoad(user: 0, system: 0, idle: 0, nice: 0)
        let cur0 = makeCoreLoad(user: 100, system: 0, idle: 0, nice: 0)
        let pre1 = makeCoreLoad(user: 0, system: 0, idle: 0, nice: 0)
        let cur1 = makeCoreLoad(user: 0, system: 0, idle: 100, nice: 0)
        let result = CPUMonitorService.computeUsage(
            current: [cur0, cur1],
            previous: [pre0, pre1]
        )
        #expect(abs(result - 0.5) < 0.0001)
    }

    @Test func computeUsage_niceTicksCountAsBusy() {
        let pre = makeCoreLoad(user: 0, system: 0, idle: 0, nice: 0)
        let cur = makeCoreLoad(user: 0, system: 0, idle: 0, nice: 100)
        let result = CPUMonitorService.computeUsage(current: [cur], previous: [pre])
        #expect(result == 1.0)
    }

    // MARK: - sample integration test

    @Test func sample_returnsCoresOnRealSystem() {
        let (cores, usage) = CPUMonitorService.sample(previous: [])
        #expect(!cores.isEmpty)
        // First call returns 0 usage (no previous baseline)
        #expect(usage == 0)
    }

    @Test func sample_returnsDeltaUsage_onSecondCall() {
        let (first, _) = CPUMonitorService.sample(previous: [])
        let (_, usage) = CPUMonitorService.sample(previous: first)
        #expect(usage >= 0)
        #expect(usage <= 1)
    }

    // MARK: - Snapshot struct

    @Test func cpuSnapshot_storesUsage() {
        let snapshot = CPUSnapshot(usage: 0.42)
        #expect(snapshot.usage == 0.42)
    }

    // MARK: - Service lifecycle

    @Test @MainActor func service_conformsToProtocol() {
        let service = CPUMonitorService()
        let _: any MetricMonitorProtocol<CPUSnapshot> = service
    }

    @Test @MainActor func stream_canBeStartedAndStopped() {
        let service = CPUMonitorService()
        _ = service.stream()
        service.stop()
    }

    // MARK: - Helpers

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
