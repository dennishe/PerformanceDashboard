import Foundation
import CoreWLAN

struct WiFiInterfaceState: Sendable, Equatable {
    let ssid: String?
    let rssi: Int
    let on: Bool
}

protocol WiFiStateProviding: Sendable {
    func currentState() -> WiFiInterfaceState?
}

private struct LiveWiFiStateProvider: WiFiStateProviding {
    func currentState() -> WiFiInterfaceState? {
        guard let iface = CWWiFiClient.shared().interface() else {
            return nil
        }

        return WiFiInterfaceState(ssid: iface.ssid(), rssi: iface.rssiValue(), on: iface.powerOn())
    }
}

/// Snapshot of Wi-Fi interface state at a point in time.
public struct WiFiSnapshot: MetricSnapshot {
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
    private let provider: any WiFiStateProviding

    override public init() {
        provider = LiveWiFiStateProvider()
        super.init()
    }

    init(provider: any WiFiStateProviding) {
        self.provider = provider
        super.init()
    }

    @MonitorActor
    override public func sample() async -> WiFiSnapshot? {
        WiFiMonitorService.sample(provider: provider)
    }

    nonisolated static func sample(provider: some WiFiStateProviding) -> WiFiSnapshot {
        snapshot(state: provider.currentState())
    }

    nonisolated static func snapshot(state: WiFiInterfaceState?) -> WiFiSnapshot {
        guard let state else {
            return WiFiSnapshot(ssid: nil, rssi: nil, on: false)
        }

        guard state.on, let ssid = state.ssid else {
            return WiFiSnapshot(ssid: nil, rssi: nil, on: state.on)
        }

        let rssi = state.rssi != 0 ? state.rssi : nil
        return WiFiSnapshot(ssid: ssid, rssi: rssi, on: true)
    }
}
