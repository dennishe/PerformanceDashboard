import SwiftUI

/// Presents combined Wi-Fi and Bluetooth state.
/// Consumes `WiFiMonitorService` and `BluetoothMonitorService` independently (SRP).
@MainActor
@Observable
public final class WirelessViewModel {
    private var wifiSnapshot = WiFiSnapshot(ssid: nil, rssi: nil, on: false)
    private var bluetoothSnapshot = BluetoothSnapshot(connectedCount: 0, on: false)

    public private(set) var tileModel = MetricTileModel(
        title: "Wireless",
        value: "Wi-Fi Off",
        gaugeValue: nil,
        history: Constants.prefilledHistory,
        thresholdLevel: .inactive,
        subtitle: "BT Off",
        systemImage: "wifi"
    )

    public private(set) var history: [Double] = Constants.prefilledHistory
    private var extendedHistory: [Double] = []

    public var wifiSSID: String? { wifiSnapshot.ssid }
    public var wifiRSSI: Int? { wifiSnapshot.rssi }
    public var wifiOn: Bool { wifiSnapshot.on }
    public var bluetoothConnectedCount: Int { bluetoothSnapshot.connectedCount }
    public var bluetoothOn: Bool { bluetoothSnapshot.on }
    public var bluetoothPeripherals: [PeripheralBattery] { bluetoothSnapshot.peripherals }
    public var gaugeValue: Double? { wifiOn ? wifiRSSI.map(Self.normaliseRSSI) ?? 0 : nil }
    public var signalLabel: String { Self.makeSignalLabel(wifiOn: wifiOn, rssi: wifiRSSI) }
    public var bluetoothLabel: String {
        Self.makeBluetoothLabel(on: bluetoothOn, connectedCount: bluetoothConnectedCount)
    }

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
                DashboardUpdateBatcher.shared.enqueue(owner: self, lane: .wifi) { [weak self] in
                    self?.receiveWiFi(snapshot)
                }
            }
        }
        btTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in btMonitor.stream() {
                DashboardUpdateBatcher.shared.enqueue(owner: self, lane: .bluetooth) { [weak self] in
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
        wifiSnapshot = snapshot
        let normalized = snapshot.rssi.map(Self.normaliseRSSI) ?? 0
        history = ringBufferAppending(history, value: normalized, maxCount: Constants.historySamples)
        extendedHistory = ringBufferAppending(extendedHistory, value: normalized,
                                              maxCount: Constants.extendedHistorySamples)
        assignIfChanged(
            &tileModel,
            to: Self.makeTileModel(
                signalLabel: signalLabel,
                gaugeValue: gaugeValue,
                history: history,
                thresholdLevel: thresholdLevel,
                bluetoothLabel: bluetoothLabel
            )
        )
    }

    private func receiveBluetooth(_ snapshot: BluetoothSnapshot) {
        bluetoothSnapshot = snapshot
        assignIfChanged(
            &tileModel,
            to: Self.makeTileModel(
                signalLabel: signalLabel,
                gaugeValue: gaugeValue,
                history: history,
                thresholdLevel: thresholdLevel,
                bluetoothLabel: bluetoothLabel
            )
        )
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

    private static func makeSignalLabel(wifiOn: Bool, rssi: Int?) -> String {
        guard wifiOn else { return "Wi-Fi Off" }
        guard let rssi else { return "Disconnected" }
        return "\(rssi) dBm"
    }

    private static func makeBluetoothLabel(on: Bool, connectedCount: Int) -> String {
        guard on else { return "BT Off" }
        return "BT: \(connectedCount) connected"
    }

    public var detailModel: DetailModel {
        var stats: [DetailModel.Stat] = []
        if let ssid = wifiSSID { stats.append(.init(label: "Network", value: ssid)) }
        if let rssi = wifiRSSI { stats.append(.init(label: "Signal", value: "\(rssi) dBm")) }
        if bluetoothOn {
            if bluetoothPeripherals.isEmpty {
                stats.append(.init(label: "Bluetooth", value: "\(bluetoothConnectedCount) connected"))
            } else {
                for peripheral in bluetoothPeripherals {
                    stats.append(.init(label: peripheral.name, value: "\(peripheral.percent)%"))
                }
            }
        }
        return DetailModel(
            title: "Wireless",
            systemImage: "wifi",
            primaryValue: signalLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }
}
