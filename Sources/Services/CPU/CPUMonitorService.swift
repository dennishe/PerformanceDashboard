import Darwin

/// Per-process CPU usage from the last poll interval.
public struct ProcessCPUStat: Sendable, Equatable {
    public let name: String
    /// Fraction of one fully utilized core for the sampled interval.
    /// Values can exceed 1.0 when a process saturates multiple cores.
    public let fraction: Double
    public var percentLabel: String { fraction.percentFormatted() }
}

struct ProcessTickSample: Sendable, Equatable {
    let pid: Int32
    let name: String
    let totalTicks: UInt64
}

private struct ProcessSampleBaseline {
    let pidTicks: [Int32: UInt64]
    let uptimeNanoseconds: UInt64
}

/// Snapshot of overall CPU utilisation at a point in time.
public struct CPUSnapshot: MetricSnapshot {
    /// Overall usage as a fraction in [0, 1].
    public let usage: Double
    /// Per-core usage as a fraction in [0, 1].
    public let cores: [CPUCoreStat]
    /// Top processes by CPU usage, sorted descending. Empty on the first tick.
    public let topProcesses: [ProcessCPUStat]

    public init(usage: Double, cores: [CPUCoreStat] = [], topProcesses: [ProcessCPUStat] = []) {
        self.usage = usage
        self.cores = cores
        self.topProcesses = topProcesses
    }
}

/// Monitors CPU utilisation by computing deltas between `host_processor_info` samples.
public final class CPUMonitorService: PollingMonitorBase<CPUSnapshot> {
    private let sampleUsage: @Sendable ([processor_cpu_load_info]) -> CPUUsageSample
    private let sampleProcessInfo: @Sendable () -> [ProcessTickSample]
    private let uptimeNanoseconds: @Sendable () -> UInt64

    @MonitorActor private var previousLoadInfo: [processor_cpu_load_info] = []
    @MonitorActor private var previousProcessSample: ProcessSampleBaseline?
    nonisolated static let coreTopology = CPUCoreTopology.current

    override public init() {
        sampleUsage = Self.sample(previous:)
        sampleProcessInfo = Self.sampleProcessInfo
        uptimeNanoseconds = { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }
        super.init()
    }

    init(
        sampleUsage: @escaping @Sendable ([processor_cpu_load_info]) -> CPUUsageSample,
        sampleProcessInfo: @escaping @Sendable () -> [ProcessTickSample],
        uptimeNanoseconds: @escaping @Sendable () -> UInt64
    ) {
        self.sampleUsage = sampleUsage
        self.sampleProcessInfo = sampleProcessInfo
        self.uptimeNanoseconds = uptimeNanoseconds
        super.init()
    }

    @MonitorActor
    override public func sample() async -> CPUSnapshot? {
        let sample = sampleUsage(previousLoadInfo)
        let currentUptimeNanoseconds = uptimeNanoseconds()
        let elapsedNanoseconds = previousProcessSample.map {
            currentUptimeNanoseconds &- $0.uptimeNanoseconds
        }
        let (newPidTicks, topProcesses) = CPUMonitorService.processStats(
            from: sampleProcessInfo(),
            previous: previousProcessSample?.pidTicks ?? [:],
            elapsedNanoseconds: elapsedNanoseconds
        )
        previousLoadInfo = sample.loadInfo
        previousProcessSample = ProcessSampleBaseline(
            pidTicks: newPidTicks,
            uptimeNanoseconds: currentUptimeNanoseconds
        )
        return CPUSnapshot(usage: sample.usage, cores: sample.cores, topProcesses: topProcesses)
    }

    // MARK: - Private sampling

    nonisolated static func loadInfoArray(
        from info: processor_info_array_t,
        processorCount: Int
    ) -> [processor_cpu_load_info] {
        let stateCount = Int(CPU_STATE_MAX)
        var result: [processor_cpu_load_info] = []
        result.reserveCapacity(processorCount)
        for index in 0..<processorCount {
            let base = index * stateCount
            var load = processor_cpu_load_info()
            load.cpu_ticks.0 = UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])
            load.cpu_ticks.1 = UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])
            load.cpu_ticks.2 = UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            load.cpu_ticks.3 = UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            result.append(load)
        }
        return result
    }

    nonisolated static func computeUsage(
        current: [processor_cpu_load_info],
        previous: [processor_cpu_load_info]
    ) -> Double {
        var totalBusy: Double = 0
        var totalAll: Double = 0
        for index in 0..<current.count {
            let cur = current[index]
            let pre = previous[index]
            let user   = Double(cur.cpu_ticks.0) - Double(pre.cpu_ticks.0)
            let system = Double(cur.cpu_ticks.1) - Double(pre.cpu_ticks.1)
            let idle   = Double(cur.cpu_ticks.2) - Double(pre.cpu_ticks.2)
            let nice   = Double(cur.cpu_ticks.3) - Double(pre.cpu_ticks.3)
            let all = user + system + idle + nice
            totalBusy += user + system + nice
            totalAll += all
        }
        return totalAll > 0 ? totalBusy / totalAll : 0
    }

    /// Samples per-process CPU nanoseconds and returns the top 5 consumers.
    nonisolated static func sampleProcessInfo() -> [ProcessTickSample] {
        let pidCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard pidCount > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(pidCount))
        proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, pidCount * Int32(MemoryLayout<Int32>.size))

        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        var samples: [ProcessTickSample] = []
        samples.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            var info = proc_taskinfo()
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, taskSize) > 0 else { continue }
            var buf = [CChar](repeating: 0, count: 64)
            proc_name(pid, &buf, UInt32(buf.count))
            let nameBytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            let name = String(bytes: nameBytes, encoding: .utf8) ?? ""
            samples.append(ProcessTickSample(
                pid: pid,
                name: name,
                totalTicks: info.pti_total_user + info.pti_total_system
            ))
        }

        return samples
    }

    nonisolated static func processStats(
        from samples: [ProcessTickSample],
        previous: [Int32: UInt64],
        elapsedNanoseconds: UInt64?
    ) -> ([Int32: UInt64], [ProcessCPUStat]) {
        var current: [Int32: UInt64] = [:]
        var deltas: [(name: String, fraction: Double)] = []
        for sample in samples {
            current[sample.pid] = sample.totalTicks
            if let prev = previous[sample.pid], sample.totalTicks > prev,
               let elapsedNanoseconds,
               elapsedNanoseconds > 0 {
                deltas.append((
                    sample.name.isEmpty ? "pid \(sample.pid)" : sample.name,
                    processFraction(
                        deltaTaskTicks: sample.totalTicks - prev,
                        elapsedNanoseconds: elapsedNanoseconds
                    )
                ))
            }
        }

        let top = deltas.sorted { $0.fraction > $1.fraction }.prefix(5).map {
            ProcessCPUStat(name: $0.name, fraction: $0.fraction)
        }
        return (current, Array(top))
    }

    nonisolated static func processFraction(
        deltaTaskTicks: UInt64,
        elapsedNanoseconds: UInt64,
        timebaseNumerator: UInt32 = taskTimebaseInfo.numer,
        timebaseDenominator: UInt32 = taskTimebaseInfo.denom
    ) -> Double {
        guard elapsedNanoseconds > 0, timebaseDenominator > 0 else { return 0 }
        let cpuNanoseconds = Double(deltaTaskTicks) * Double(timebaseNumerator) / Double(timebaseDenominator)
        return cpuNanoseconds / Double(elapsedNanoseconds)
    }

    nonisolated private static let taskTimebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
}
