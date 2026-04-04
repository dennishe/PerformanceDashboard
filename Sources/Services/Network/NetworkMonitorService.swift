import Darwin
import Foundation

/// Snapshot of network throughput at a point in time.
public struct NetworkSnapshot: Sendable {
    /// Bytes received per second across all active interfaces.
    public let bytesInPerSecond: Double
    /// Bytes sent per second across all active interfaces.
    public let bytesOutPerSecond: Double
}

/// Monitors network throughput by diffing `getifaddrs` byte counters.
public final class NetworkMonitorService: PollingMonitorBase<NetworkSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<NetworkSnapshot>.Continuation) async {
        var previous = NetworkMonitorService.counters()
        while !Task.isCancelled {
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
            let current = NetworkMonitorService.counters()
            let inBytes  = Double(max(0, Int64(bitPattern: current.0) - Int64(bitPattern: previous.0)))
            let outBytes = Double(max(0, Int64(bitPattern: current.1) - Int64(bitPattern: previous.1)))
            continuation.yield(NetworkSnapshot(bytesInPerSecond: inBytes, bytesOutPerSecond: outBytes))
            previous = current
        }
    }

    /// Returns (totalBytesIn, totalBytesOut) across all non-loopback interfaces.
    nonisolated static func counters() -> (UInt64, UInt64) {
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let head = ifaddrPointer else { return (0, 0) }
        defer { freeifaddrs(head) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        while let iface = cursor {
            let name = String(cString: iface.pointee.ifa_name)
            // Include only physical / VPN interfaces; skip loopback and others.
            if (name.hasPrefix("en") || name.hasPrefix("utun")) &&
                iface.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                if let data = iface.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    bytesIn += UInt64(networkData.pointee.ifi_ibytes)
                    bytesOut += UInt64(networkData.pointee.ifi_obytes)
                }
            }
            cursor = iface.pointee.ifa_next
        }
        return (bytesIn, bytesOut)
    }
}
