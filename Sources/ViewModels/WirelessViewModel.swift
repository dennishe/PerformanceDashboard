import SwiftUI

/// Presents combined Wi-Fi and Bluetooth state.
/// Consumes `WiFiMonitorService` and `BluetoothMonitorService` independently (SRP).
@MainActor
@Observable
public final class WirelessViewModel {
    public private(set) var wifiSSID: String?
    public private(set) var wifiRSSI: Int?
    public private(set) var wifiOn: Bool = false
    public private(set) var bluetoothConnectedCount: Int = 0
    public private(set) var bluetoothOn: Bool = false
    public private(set) var history: [Double] = []

    /// Normalises RSSI from [−100, −30] dBm → [0, 1].
    private static func normaliseRSSI(_ rssi: Int) -> Double {
        min(1.0, max(0.0, Double(rssi + 100) / 70.0))
    }

    public var gaugeValue: Double? {
        guard wifiOn, let rssi = wifiRSSI else { return wifiOn ? 0 : nil }
        return WirelessViewModel.normaliseRSSI(rssi)
    }

    public var signalLabel: String {
        guard wifiOn else { return "Wi-Fi Off" }
        guard let rssi = wifiRSSI else { return "Disconnected" }
        return "\(rssi) dBm"
    }

    public var ssidLabel: String? { wifiSSID }

    public var bluetoothLabel: String {
        guard bluetoothOn else { return "BT Off" }
        return "BT: \(bluetoothConnectedCount) connected"
    }

    public var thresholdLevel: ThresholdLevel {
        guard wifiOn, wifiRSSI != nil else { return .inactive }
        return WirelessThreshold().level(for: gaugeValue ?? 0)
    }

    private let wifiMonitor: any MetricMonitorProtocol<WiFiSnapshot>
    private let btMonitor: any MetricMonitorProtocol<BluetoothSnapshot>
    private var wifiTask: Task<Void, Never>?
    private var btTask: Task<Void, Never>?

    public init(
        wifiMonitor: some MetricMonitorProtocol<WiFiSnapshot>,
        btMonitor: some MetricMonitorProtocol<BluetoothSnapshot>
    ) {
        self.wifiMonitor = wifiMonitor
        self.btMonitor = btMonitor
    }

    public func start() {
        wifiTask = Task {
            for await snapshot in wifiMonitor.stream() { receiveWiFi(snapshot) }
        }
        btTask = Task {
            for await snapshot in btMonitor.stream() { receiveBluetooth(snapshot) }
        }
    }

    public func stop() {
        wifiTask?.cancel()
        btTask?.cancel()
        wifiMonitor.stop()
        btMonitor.stop()
    }

    private func receiveWiFi(_ snapshot: WiFiSnapshot) {
        wifiSSID = snapshot.ssid
        wifiRSSI = snapshot.rssi
        wifiOn   = snapshot.on
        let normalized = snapshot.rssi.map { WirelessViewModel.normaliseRSSI($0) } ?? 0
        history.append(normalized)
        if history.count > Constants.historySamples { history.removeFirst() }
    }

    private func receiveBluetooth(_ snapshot: BluetoothSnapshot) {
        bluetoothConnectedCount = snapshot.connectedCount
        bluetoothOn             = snapshot.on
    }
}
