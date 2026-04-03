import Foundation
import CoreWLAN
import IOBluetooth

/// Snapshot of Wi-Fi and Bluetooth state.
public struct WirelessSnapshot: Sendable {
    /// Current Wi-Fi SSID; `nil` when disconnected or off.
    public let wifiSSID: String?
    /// Wi-Fi receive signal strength in dBm; `nil` when disconnected.
    public let wifiRSSI: Int?
    /// `true` while the Wi-Fi radio is powered on.
    public let wifiOn: Bool
    /// Number of currently connected Bluetooth devices.
    public let bluetoothConnectedCount: Int
    /// `true` while Bluetooth is powered on.
    public let bluetoothOn: Bool
}

/// Polls Wi-Fi status via CoreWLAN and Bluetooth via IOBluetooth.
///
/// CoreWLAN reads are thread-safe and run directly on `@MonitorActor`.
/// IOBluetooth reads are dispatched to `@MainActor` as the framework is
/// designed around the main run loop.
public final class WirelessMonitorService: MetricMonitorProtocol {
    private var continuation: AsyncStream<WirelessSnapshot>.Continuation?
    private var task: Task<Void, Never>?

    public init() {}

    @MainActor
    public func stream() -> AsyncStream<WirelessSnapshot> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.task = Task { await self.poll(continuation: continuation) }
        }
    }

    @MainActor
    public func stop() {
        task?.cancel()
        continuation?.finish()
    }

    @MonitorActor
    private func poll(continuation: AsyncStream<WirelessSnapshot>.Continuation) async {
        let wifiClient = CWWiFiClient.shared()
        while !Task.isCancelled {
            let wifi = sampleWiFi(wifiClient)
            let bluetooth = await sampleBluetooth()
            continuation.yield(WirelessSnapshot(
                wifiSSID: wifi.ssid,
                wifiRSSI: wifi.rssi,
                wifiOn: wifi.on,
                bluetoothConnectedCount: bluetooth.connected,
                bluetoothOn: bluetooth.on
            ))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    // MARK: - Wi-Fi (thread-safe CoreWLAN)

    private struct WiFiSample {
        let ssid: String?
        let rssi: Int?
        let on: Bool
    }

    nonisolated private func sampleWiFi(_ client: CWWiFiClient) -> WiFiSample {
        guard let iface = client.interface() else { return WiFiSample(ssid: nil, rssi: nil, on: false) }
        let on = iface.powerOn()
        guard on, let ssid = iface.ssid() else { return WiFiSample(ssid: nil, rssi: nil, on: on) }
        let rssi = iface.rssiValue()
        return WiFiSample(ssid: ssid, rssi: rssi != 0 ? rssi : nil, on: on)
    }

    // MARK: - Bluetooth (main-thread IOBluetooth)

    private func sampleBluetooth() async -> (on: Bool, connected: Int) {
        await MainActor.run {
            let on = IOBluetoothHostController.default()?.powerState
                == kBluetoothHCIPowerStateON
            let connected = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
                .filter { $0.isConnected() }
                .count
            return (on, connected)
        }
    }
}
