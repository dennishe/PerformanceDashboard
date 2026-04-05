import Darwin

/// Snapshot of overall CPU utilisation at a point in time.
public struct CPUSnapshot: Sendable {
    /// Overall usage as a fraction in [0, 1].
    public let usage: Double
}

/// Monitors CPU utilisation by computing deltas between `host_processor_info` samples.
public final class CPUMonitorService: PollingMonitorBase<CPUSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<CPUSnapshot>.Continuation) async {
        var previous: [processor_cpu_load_info] = []
        var nextPoll = PollingCadence.clock.now
        while !Task.isCancelled {
            let (current, usage) = CPUMonitorService.sample(previous: previous)
            previous = current
            continuation.yield(CPUSnapshot(usage: usage))
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
}
