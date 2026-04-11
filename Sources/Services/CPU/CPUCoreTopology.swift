import Foundation

public struct CPUCoreStat: Sendable, Equatable {
    public let index: Int
    public let usage: Double
    public let kind: String

    public init(index: Int, usage: Double, kind: String) {
        self.index = index
        self.usage = usage
        self.kind = kind
    }

    public var label: String { "CPU \(index + 1)" }
}

struct CPUCoreTopology: Sendable {
    struct Core: Sendable {
        let index: Int
        let kind: String
    }

    let cores: [Core]

    static let current = detect()

    func kind(for index: Int) -> String {
        cores.first(where: { $0.index == index })?.kind ?? "Core"
    }

    private static func detect(
        intReader: (String) -> Int? = readIntSysctl,
        stringReader: (String) -> String? = readStringSysctl
    ) -> CPUCoreTopology {
        let perfLevelCount = intReader("hw.nperflevels") ?? 0
        guard perfLevelCount > 0 else {
            let logicalCPUCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
            return CPUCoreTopology(
                cores: (0..<logicalCPUCount).map { Core(index: $0, kind: "Core") }
            )
        }

        var cores: [Core] = []
        var nextCoreIndex = 0

        for perfLevel in 0..<perfLevelCount {
            let prefix = "hw.perflevel\(perfLevel)"
            let logicalCPUCount = intReader(prefix + ".logicalcpu") ?? 0
            guard logicalCPUCount > 0 else { continue }

            let kind = stringReader(prefix + ".name") ?? "Core"
            for coreOffset in 0..<logicalCPUCount {
                cores.append(Core(index: nextCoreIndex + coreOffset, kind: kind))
            }
            nextCoreIndex += logicalCPUCount
        }

        guard !cores.isEmpty else {
            let logicalCPUCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
            return CPUCoreTopology(
                cores: (0..<logicalCPUCount).map { Core(index: $0, kind: "Core") }
            )
        }

        return CPUCoreTopology(cores: cores)
    }
}

private func readIntSysctl(_ name: String) -> Int? {
    var value = Int32(0)
    var size = MemoryLayout<Int32>.size

    let status = name.withCString { key in
        sysctlbyname(key, &value, &size, nil, 0)
    }
    guard status == 0 else { return nil }
    return Int(value)
}

private func readStringSysctl(_ name: String) -> String? {
    var size = 0
    let firstStatus = name.withCString { key in
        sysctlbyname(key, nil, &size, nil, 0)
    }
    guard firstStatus == 0, size > 1 else { return nil }

    var buffer = [CChar](repeating: 0, count: size)
    let secondStatus = name.withCString { key in
        sysctlbyname(key, &buffer, &size, nil, 0)
    }
    guard secondStatus == 0 else { return nil }
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(bytes: bytes, encoding: .utf8)
}
