import Darwin

struct ProcessTickSample: Sendable, Equatable {
    let pid: Int32
    let name: String
    let totalTicks: UInt64
}

@MonitorActor
protocol CPUProcessSamplingControlling: AnyObject, Sendable {
    func setProcessSamplingEnabled(_ enabled: Bool)
}

extension CPUMonitorService {
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
