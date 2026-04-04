import Foundation
import CoreWLAN

/// Snapshot of Wi-Fi interface state at a point in time.
public struct WiFiSnapshot: Sendable {
    /// Current SSID; `nil` when disconnected or the radio is off.
    public let ssid: String?
    /// Receive signal strength in dBm; `nil` when disconnected.
    public let rssi: Int?
    /// `true` while the Wi-Fi radio is powered on.
    public let on: Bool
}

/// Polls Wi-Fi status via CoreWLAN.
/// CoreWLAN reads are thread-safe and run on `@MonitorActor`.
public final class WiFiMonitorService: PollingMonitorBase<WiFiSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<WiFiSnapshot>.Continuation) async {
        let client = CWWiFiClient.shared()
        while !Task.isCancelled {
            continuation.yield(sample(client))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    nonisolated private func sample(_ client: CWWiFiClient) -> WiFiSnapshot {
        guard let iface = client.interface() else {
            return WiFiSnapshot(ssid: nil, rssi: nil, on: false)
        }
        let on = iface.powerOn()
        guard on, let ssid = iface.ssid() else {
            return WiFiSnapshot(ssid: nil, rssi: nil, on: on)
        }
        let rssi = iface.rssiValue()
        return WiFiSnapshot(ssid: ssid, rssi: rssi != 0 ? rssi : nil, on: true)
    }
}
