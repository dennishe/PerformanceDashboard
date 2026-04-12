import Darwin
import Foundation

struct NetworkInterfaceCounter: Sendable, Equatable {
    let name: String
    let bytesIn: UInt64
    let bytesOut: UInt64
}

protocol NetworkInterfaceCounterProviding {
    func interfaceCounters() -> [NetworkInterfaceCounter]?
}

private struct LiveNetworkInterfaceCounterProvider: NetworkInterfaceCounterProviding {
    func interfaceCounters() -> [NetworkInterfaceCounter]? {
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let head = ifaddrPointer else { return nil }
        defer { freeifaddrs(head) }

        var result: [NetworkInterfaceCounter] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        while let iface = cursor {
            let name = String(cString: iface.pointee.ifa_name)
            if iface.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = iface.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self)
                result.append(
                    NetworkInterfaceCounter(
                        name: name,
                        bytesIn: UInt64(networkData.pointee.ifi_ibytes),
                        bytesOut: UInt64(networkData.pointee.ifi_obytes)
                    )
                )
            }
            cursor = iface.pointee.ifa_next
        }

        return result
    }
}

/// Snapshot of network throughput at a point in time.
public struct NetworkSnapshot: MetricSnapshot {
    /// Bytes received per second across all active interfaces.
    public let bytesInPerSecond: Double
    /// Bytes sent per second across all active interfaces.
    public let bytesOutPerSecond: Double
}

/// Monitors network throughput by diffing `getifaddrs` byte counters.
public final class NetworkMonitorService: PollingMonitorBase<NetworkSnapshot> {
    @MonitorActor private var previousCounters: (UInt64, UInt64) = (0, 0)

    @MonitorActor
    override public func setUp() {
        previousCounters = NetworkMonitorService.counters()
    }

    @MonitorActor
    override public func sample() async -> NetworkSnapshot? {
        let current = NetworkMonitorService.counters()
        let snapshot = NetworkMonitorService.snapshot(current: current, previous: previousCounters)
        previousCounters = current
        return snapshot
    }

    /// Returns (totalBytesIn, totalBytesOut) across all non-loopback interfaces.
    nonisolated static func counters() -> (UInt64, UInt64) {
        counters(provider: LiveNetworkInterfaceCounterProvider())
    }

    nonisolated static func counters(
        provider: some NetworkInterfaceCounterProviding
    ) -> (UInt64, UInt64) {
        guard let interfaceCounters = provider.interfaceCounters() else { return (0, 0) }
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        for counter in interfaceCounters {
            // Include only physical / VPN interfaces; skip loopback and others.
            if counter.name.hasPrefix("en") || counter.name.hasPrefix("utun") {
                bytesIn += counter.bytesIn
                bytesOut += counter.bytesOut
            }
        }
        return (bytesIn, bytesOut)
    }

    nonisolated static func snapshot(
        current: (UInt64, UInt64),
        previous: (UInt64, UInt64)
    ) -> NetworkSnapshot {
        let inBytes = Double(max(0, Int64(bitPattern: current.0) - Int64(bitPattern: previous.0)))
        let outBytes = Double(max(0, Int64(bitPattern: current.1) - Int64(bitPattern: previous.1)))
        return NetworkSnapshot(bytesInPerSecond: inBytes, bytesOutPerSecond: outBytes)
    }
}
