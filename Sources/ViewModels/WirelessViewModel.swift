import SwiftUI

/// Presents combined Wi-Fi and Bluetooth state.
/// Consumes `WiFiMonitorService` and `BluetoothMonitorService` independently (SRP).
@MainActor
@Observable
public final class WirelessViewModel {
    public private(set) var tileModel = MetricTileModel(
        title: "Wireless",
        value: "Wi-Fi Off",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        subtitle: "BT Off",
        systemImage: "wifi"
    )

    @ObservationIgnored
    public private(set) var wifiSSID: String?
    @ObservationIgnored
    public private(set) var wifiRSSI: Int?
    @ObservationIgnored
    public private(set) var wifiOn: Bool = false
    @ObservationIgnored
    public private(set) var bluetoothConnectedCount: Int = 0
    @ObservationIgnored
    public private(set) var bluetoothOn: Bool = false
    @ObservationIgnored
    public private(set) var history: [Double] = Constants.prefilledHistory
    @ObservationIgnored
    public private(set) var gaugeValue: Double?
    @ObservationIgnored
    public private(set) var signalLabel: String = "Wi-Fi Off"
    @ObservationIgnored
    public private(set) var bluetoothLabel: String = "BT Off"

    /// Normalises RSSI from [−100, −30] dBm → [0, 1].
    private static func normaliseRSSI(_ rssi: Int) -> Double {
        min(1.0, max(0.0, Double(rssi + 100) / 70.0))
    }

    public var ssidLabel: String? { wifiSSID }

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
        wifiTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in wifiMonitor.stream() {
                DashboardUpdateBatcher.shared.enqueue(owner: self, lane: "wifi") { [weak self] in
                    self?.receiveWiFi(snapshot)
                }
            }
        }
        btTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in btMonitor.stream() {
                DashboardUpdateBatcher.shared.enqueue(owner: self, lane: "bluetooth") { [weak self] in
                    self?.receiveBluetooth(snapshot)
                }
            }
        }
    }

    public func stop() {
        wifiTask?.cancel()
        btTask?.cancel()
        DashboardUpdateBatcher.shared.cancel(owner: self)
        wifiMonitor.stop()
        btMonitor.stop()
    }

    private func receiveWiFi(_ snapshot: WiFiSnapshot) {
        wifiSSID = snapshot.ssid
        wifiRSSI = snapshot.rssi
        wifiOn   = snapshot.on
        let normalized = snapshot.rssi.map { WirelessViewModel.normaliseRSSI($0) } ?? 0
        gaugeValue = snapshot.on ? (snapshot.rssi.map { WirelessViewModel.normaliseRSSI($0) } ?? 0) : nil
        signalLabel = Self.makeSignalLabel(wifiOn: snapshot.on, rssi: snapshot.rssi)
        history = updatedHistory(from: history, adding: normalized)
        let newTileModel = Self.makeTileModel(
            signalLabel: signalLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            bluetoothLabel: bluetoothLabel
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private func receiveBluetooth(_ snapshot: BluetoothSnapshot) {
        bluetoothConnectedCount = snapshot.connectedCount
        bluetoothOn             = snapshot.on
        bluetoothLabel = Self.makeBluetoothLabel(on: snapshot.on, connectedCount: snapshot.connectedCount)
        let newTileModel = Self.makeTileModel(
            signalLabel: signalLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            bluetoothLabel: bluetoothLabel
        )
        if tileModel != newTileModel {
            tileModel = newTileModel
        }
    }

    private static func makeTileModel(
        signalLabel: String,
        gaugeValue: Double?,
        history: [Double],
        thresholdLevel: ThresholdLevel,
        bluetoothLabel: String
    ) -> MetricTileModel {
        MetricTileModel(
            title: "Wireless",
            value: signalLabel,
            gaugeValue: gaugeValue,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: bluetoothLabel,
            systemImage: "wifi"
        )
    }

    private func updatedHistory(from history: [Double], adding value: Double) -> [Double] {
        var updatedHistory = history
        updatedHistory.append(value)
        if updatedHistory.count > Constants.historySamples {
            updatedHistory.removeFirst(updatedHistory.count - Constants.historySamples)
        }
        return updatedHistory
    }

    private static func makeSignalLabel(wifiOn: Bool, rssi: Int?) -> String {
        guard wifiOn else { return "Wi-Fi Off" }
        guard let rssi else { return "Disconnected" }
        return "\(rssi) dBm"
    }

    private static func makeBluetoothLabel(on: Bool, connectedCount: Int) -> String {
        guard on else { return "BT Off" }
        return "BT: \(connectedCount) connected"
    }
}
