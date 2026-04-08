import Darwin

/// Per-process CPU usage from the last poll interval.
public struct ProcessCPUStat: Sendable {
    public let name: String
    /// Fraction of one core [0, 1].
    public let fraction: Double
    public var percentLabel: String { String(format: "%.1f%%", fraction * 100) }
}

/// Snapshot of overall CPU utilisation at a point in time.
public struct CPUSnapshot: Sendable {
    /// Overall usage as a fraction in [0, 1].
    public let usage: Double
    /// Top processes by CPU usage, sorted descending. Empty on the first tick.
    public let topProcesses: [ProcessCPUStat]

    public init(usage: Double, topProcesses: [ProcessCPUStat] = []) {
        self.usage = usage
        self.topProcesses = topProcesses
    }
}

/// Monitors CPU utilisation by computing deltas between `host_processor_info` samples.
public final class CPUMonitorService: PollingMonitorBase<CPUSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<CPUSnapshot>.Continuation) async {
        var previous: [processor_cpu_load_info] = []
        var prevPidTicks: [Int32: UInt64] = [:]
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            let (current, usage) = CPUMonitorService.sample(previous: previous)
            let (newPidTicks, topProcesses) = CPUMonitorService.sampleProcesses(previous: prevPidTicks)
            previous = current
            prevPidTicks = newPidTicks
            continuation.yield(CPUSnapshot(usage: usage, topProcesses: topProcesses))
            nextPoll = PollingCadence.nextDeadline(after: nextPoll)
            do { try await PollingCadence.sleep(until: nextPoll) } catch { break }
        }
    }

    // MARK: - Private sampling

    /// Returns the current per-core tick array and the computed usage delta.
    nonisolated static func sample(
        previous: [processor_cpu_load_info]
    ) -> ([processor_cpu_load_info], Double) {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount = mach_msg_type_number_t()
        var processorCount = natural_t()

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfo,
            &cpuInfoCount
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return (previous, 0) }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(cpuInfoCount))
        }

        let current = loadInfoArray(from: info, processorCount: Int(processorCount))
        guard !previous.isEmpty, previous.count == current.count else {
            return (current, 0)
        }
        return (current, computeUsage(current: current, previous: previous))
    }

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
    nonisolated static func sampleProcesses(
        previous: [Int32: UInt64]
    ) -> ([Int32: UInt64], [ProcessCPUStat]) {
        let pidCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard pidCount > 0 else { return ([:], []) }
        var pids = [Int32](repeating: 0, count: Int(pidCount))
        proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, pidCount * Int32(MemoryLayout<Int32>.size))

        var current: [Int32: UInt64] = [:]
        var deltas: [(name: String, delta: UInt64)] = []
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)

        for pid in pids where pid > 0 {
            var info = proc_taskinfo()
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, taskSize) > 0 else { continue }
            let ticks = info.pti_total_user + info.pti_total_system
            current[pid] = ticks
            if let prev = previous[pid], ticks > prev {
                var buf = [CChar](repeating: 0, count: 64)
                proc_name(pid, &buf, UInt32(buf.count))
                let name = String(cString: buf)
                deltas.append((name.isEmpty ? "pid \(pid)" : name, ticks - prev))
            }
        }

        // pti_total_user/system are in nanoseconds; 1s polling interval = 1_000_000_000 ns.
        let top = deltas.sorted { $0.delta > $1.delta }.prefix(5).map {
            ProcessCPUStat(name: $0.name, fraction: min(1.0, Double($0.delta) / 1_000_000_000))
        }
        return (current, Array(top))
    }
}
