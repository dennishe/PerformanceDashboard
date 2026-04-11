import Darwin

struct CPUUsageSample {
    let loadInfo: [processor_cpu_load_info]
    let usage: Double
    let cores: [CPUCoreStat]
}

extension CPUMonitorService {
    /// Returns the current per-core tick array and the computed usage delta.
    nonisolated static func sample(
        previous: [processor_cpu_load_info]
    ) -> CPUUsageSample {
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
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return CPUUsageSample(loadInfo: previous, usage: 0, cores: [])
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(cpuInfoCount))
        }

        let current = loadInfoArray(from: info, processorCount: Int(processorCount))
        guard !previous.isEmpty, previous.count == current.count else {
            return CPUUsageSample(loadInfo: current, usage: 0, cores: [])
        }

        let coreUsages = computeCoreUsages(current: current, previous: previous)
        return CPUUsageSample(
            loadInfo: current,
            usage: computeUsage(current: current, previous: previous),
            cores: mapCoreStats(usages: coreUsages)
        )
    }

    nonisolated static func computeCoreUsages(
        current: [processor_cpu_load_info],
        previous: [processor_cpu_load_info]
    ) -> [Double] {
        current.enumerated().map { index, core in
            let previousCore = previous[index]
            let user = Double(core.cpu_ticks.0) - Double(previousCore.cpu_ticks.0)
            let system = Double(core.cpu_ticks.1) - Double(previousCore.cpu_ticks.1)
            let idle = Double(core.cpu_ticks.2) - Double(previousCore.cpu_ticks.2)
            let nice = Double(core.cpu_ticks.3) - Double(previousCore.cpu_ticks.3)
            let total = user + system + idle + nice
            guard total > 0 else { return 0 }
            return (user + system + nice) / total
        }
    }

    nonisolated static func mapCoreStats(
        usages: [Double],
        topology: CPUCoreTopology = coreTopology
    ) -> [CPUCoreStat] {
        usages.enumerated().map { index, usage in
            CPUCoreStat(index: index, usage: usage, kind: topology.kind(for: index))
        }
    }
}
