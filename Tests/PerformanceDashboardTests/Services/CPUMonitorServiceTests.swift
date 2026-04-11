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

    @Test func processFraction_convertsMachTicks_usingTimebase() {
        let fraction = CPUMonitorService.processFraction(
            deltaTaskTicks: 24_000_000,
            elapsedNanoseconds: 1_000_000_000,
            timebaseNumerator: 125,
            timebaseDenominator: 3
        )

        #expect(abs(fraction - 1.0) < 0.001)
    }

    @Test func processFraction_canExceedOne_forMultiCoreProcesses() {
        let fraction = CPUMonitorService.processFraction(
            deltaTaskTicks: 48_000_000,
            elapsedNanoseconds: 1_000_000_000,
            timebaseNumerator: 125,
            timebaseDenominator: 3
        )

        #expect(abs(fraction - 2.0) < 0.001)
    }

    @Test func processFraction_returnsZero_whenElapsedIsZero() {
        let fraction = CPUMonitorService.processFraction(
            deltaTaskTicks: 1_000,
            elapsedNanoseconds: 0,
            timebaseNumerator: 1,
            timebaseDenominator: 1
        )

        #expect(fraction == 0)
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

    // MARK: - ProcessCPUStat

    @Test func processCPUStat_storesName() {
        let stat = ProcessCPUStat(name: "finder", fraction: 0.5)
        #expect(stat.name == "finder")
    }

    @Test func processCPUStat_storesFraction() {
        let stat = ProcessCPUStat(name: "chrome", fraction: 0.75)
        #expect(stat.fraction == 0.75)
    }

    @Test func processCPUStat_percentLabel_formats25Percent() {
        let stat = ProcessCPUStat(name: "test", fraction: 0.25)
        #expect(stat.percentLabel == "25.0%")
    }

    @Test func processCPUStat_percentLabel_formats100Percent() {
        let stat = ProcessCPUStat(name: "test", fraction: 1.0)
        #expect(stat.percentLabel == "100.0%")
    }

    @Test func processCPUStat_percentLabel_formatsAbove100Percent() {
        let stat = ProcessCPUStat(name: "test", fraction: 1.5)
        #expect(stat.percentLabel == "150.0%")
    }

    @Test func processCPUStat_percentLabel_formatsZero() {
        let stat = ProcessCPUStat(name: "test", fraction: 0.0)
        #expect(stat.percentLabel == "0.0%")
    }

    @Test func processCPUStat_percentLabel_formatsDecimal() {
        let stat = ProcessCPUStat(name: "test", fraction: 0.333)
        #expect(stat.percentLabel == "33.3%")
    }

    // MARK: - CPUSnapshot with processes

    @Test func cpuSnapshot_storesMultipleProcesses() {
        let procs = [
            ProcessCPUStat(name: "proc1", fraction: 0.8),
            ProcessCPUStat(name: "proc2", fraction: 0.4)
        ]
        let cores = [CPUCoreStat(index: 0, usage: 0.6, kind: "Performance")]
        let snapshot = CPUSnapshot(usage: 0.5, cores: cores, topProcesses: procs)
        #expect(snapshot.cores.count == 1)
        #expect(snapshot.cores[0].kind == "Performance")
        #expect(snapshot.topProcesses.count == 2)
        #expect(snapshot.topProcesses[0].name == "proc1")
        #expect(snapshot.topProcesses[1].fraction == 0.4)
    }

    @Test func cpuSnapshot_defaultsToEmptyProcesses() {
        let snapshot = CPUSnapshot(usage: 0.55)
        #expect(snapshot.topProcesses.isEmpty)
    }

    @Test func cpuSnapshot_isSendable() {
        let snapshot = CPUSnapshot(usage: 0.5, topProcesses: [])
        let _: Sendable = snapshot
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
