import Darwin

/// Per-process CPU usage from the last poll interval.
public struct ProcessCPUStat: Sendable, Equatable {
    public let name: String
    /// Fraction of one fully utilized core for the sampled interval.
    /// Values can exceed 1.0 when a process saturates multiple cores.
    public let fraction: Double
    public var percentLabel: String { fraction.percentFormatted() }
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
public final class CPUMonitorService: PollingMonitorBase<CPUSnapshot>, CPUProcessSamplingControlling {
    private let sampleUsage: @Sendable ([processor_cpu_load_info]) -> CPUUsageSample
    private let sampleProcessInfo: @Sendable () -> [ProcessTickSample]
    private let uptimeNanoseconds: @Sendable () -> UInt64

    @MonitorActor private var previousLoadInfo: [processor_cpu_load_info] = []
    @MonitorActor private var previousProcessSample: ProcessSampleBaseline?
    @MonitorActor private var isProcessSamplingEnabled = false
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
        previousLoadInfo = sample.loadInfo
        guard isProcessSamplingEnabled else {
            return CPUSnapshot(usage: sample.usage, cores: sample.cores)
        }
        let currentUptimeNanoseconds = uptimeNanoseconds()
        let elapsedNanoseconds = previousProcessSample.map {
            currentUptimeNanoseconds &- $0.uptimeNanoseconds
        }
        let (newPidTicks, topProcesses) = CPUMonitorService.processStats(
            from: sampleProcessInfo(),
            previous: previousProcessSample?.pidTicks ?? [:],
            elapsedNanoseconds: elapsedNanoseconds
        )
        previousProcessSample = ProcessSampleBaseline(
            pidTicks: newPidTicks,
            uptimeNanoseconds: currentUptimeNanoseconds
        )
        return CPUSnapshot(usage: sample.usage, cores: sample.cores, topProcesses: topProcesses)
    }

    @MonitorActor
    func setProcessSamplingEnabled(_ enabled: Bool) {
        guard isProcessSamplingEnabled != enabled else { return }
        isProcessSamplingEnabled = enabled
        previousProcessSample = nil
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
}
