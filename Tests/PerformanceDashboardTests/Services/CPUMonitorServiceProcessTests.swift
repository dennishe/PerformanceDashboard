import Darwin
import Testing
@testable import PerformanceDashboard

struct CPUMonitorServiceProcessTests {
    @Test func processStats_returnsCurrentTicksWithoutTopProcesses_onFirstSample() {
        let samples = [
            ProcessTickSample(pid: 101, name: "Finder", totalTicks: 1_000),
            ProcessTickSample(pid: 202, name: "Xcode", totalTicks: 2_000)
        ]

        let result = CPUMonitorService.processStats(
            from: samples,
            previous: [:],
            elapsedNanoseconds: 1_000_000_000
        )

        #expect(result.0 == [101: 1_000, 202: 2_000])
        #expect(result.1.isEmpty)
    }

    @Test func processStats_usesFallbackPidName_andSortsDescending() {
        let samples = [
            ProcessTickSample(pid: 11, name: "", totalTicks: 7_000),
            ProcessTickSample(pid: 22, name: "Xcode", totalTicks: 9_000),
            ProcessTickSample(pid: 33, name: "Safari", totalTicks: 6_500)
        ]

        let result = CPUMonitorService.processStats(
            from: samples,
            previous: [11: 5_000, 22: 6_000, 33: 6_000],
            elapsedNanoseconds: 1_000_000_000
        )

        #expect(result.1.count == 3)
        #expect(result.1[0].name == "Xcode")
        #expect(result.1[1].name == "pid 11")
        #expect(result.1[2].name == "Safari")
        #expect(result.1[0].fraction > result.1[1].fraction)
        #expect(result.1[1].fraction > result.1[2].fraction)
    }

    @Test func processStats_limitsResultsToTopFive_andSkipsNonIncreasingTicks() {
        let samples = [
            ProcessTickSample(pid: 1, name: "P1", totalTicks: 110),
            ProcessTickSample(pid: 2, name: "P2", totalTicks: 120),
            ProcessTickSample(pid: 3, name: "P3", totalTicks: 130),
            ProcessTickSample(pid: 4, name: "P4", totalTicks: 140),
            ProcessTickSample(pid: 5, name: "P5", totalTicks: 150),
            ProcessTickSample(pid: 6, name: "P6", totalTicks: 160),
            ProcessTickSample(pid: 7, name: "P7", totalTicks: 100)
        ]

        let result = CPUMonitorService.processStats(
            from: samples,
            previous: [1: 100, 2: 100, 3: 100, 4: 100, 5: 100, 6: 100, 7: 100],
            elapsedNanoseconds: 1_000
        )

        #expect(result.1.count == 5)
        #expect(result.1.map(\.name) == ["P6", "P5", "P4", "P3", "P2"])
    }

    @Test @MainActor func serviceSample_tracksPreviousTicksAcrossCalls() async {
        let loads = [
            CPUUsageSample(loadInfo: [], usage: 0.25, cores: []),
            CPUUsageSample(loadInfo: [], usage: 0.5, cores: [])
        ]
        let processBursts = [
            [ProcessTickSample(pid: 42, name: "Render", totalTicks: 100)],
            [ProcessTickSample(pid: 42, name: "Render", totalTicks: 220)]
        ]
        let timestamps: [UInt64] = [1_000, 2_000]
        let tracker = SamplingTracker(loads: loads, processBursts: processBursts, timestamps: timestamps)
        let service = CPUMonitorService(
            sampleUsage: tracker.nextLoad(previous:),
            sampleProcessInfo: tracker.nextProcessBurst,
            uptimeNanoseconds: tracker.nextTimestamp
        )

        let first = await service.sample()
        let second = await service.sample()

        #expect(first?.usage == 0.25)
        #expect(first?.topProcesses.isEmpty == true)
        #expect(second?.usage == 0.5)
        #expect(second?.topProcesses.count == 1)
        #expect(second?.topProcesses.first?.name == "Render")
        #expect(second?.topProcesses.first?.fraction == 5.0)
    }

    @Test func processFraction_usesDefaultTimebaseArguments() {
        let fraction = CPUMonitorService.processFraction(
            deltaTaskTicks: 1_000,
            elapsedNanoseconds: 1_000_000_000
        )

        #expect(fraction >= 0)
    }
}

private final class SamplingTracker: @unchecked Sendable {
    private var loadIndex = 0
    private var processIndex = 0
    private var timestampIndex = 0
    private let loads: [CPUUsageSample]
    private let processBursts: [[ProcessTickSample]]
    private let timestamps: [UInt64]

    init(loads: [CPUUsageSample], processBursts: [[ProcessTickSample]], timestamps: [UInt64]) {
        self.loads = loads
        self.processBursts = processBursts
        self.timestamps = timestamps
    }

    func nextLoad(previous: [processor_cpu_load_info]) -> CPUUsageSample {
        defer { loadIndex += 1 }
        return loads[min(loadIndex, loads.count - 1)]
    }

    func nextProcessBurst() -> [ProcessTickSample] {
        defer { processIndex += 1 }
        return processBursts[min(processIndex, processBursts.count - 1)]
    }

    func nextTimestamp() -> UInt64 {
        defer { timestampIndex += 1 }
        return timestamps[min(timestampIndex, timestamps.count - 1)]
    }
}
