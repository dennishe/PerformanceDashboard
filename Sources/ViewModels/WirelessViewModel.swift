import SwiftUI

public struct WirelessSnapshot: MetricSnapshot {
    public let wifi: WiFiSnapshot
    public let bluetooth: BluetoothSnapshot

    public init(wifi: WiFiSnapshot, bluetooth: BluetoothSnapshot) {
        self.wifi = wifi
        self.bluetooth = bluetooth
    }
}

/// Presents combined Wi-Fi and Bluetooth state.
/// Consumes `WiFiMonitorService` and `BluetoothMonitorService` independently (SRP).
@MainActor
@Observable
public final class WirelessViewModel: MonitorViewModelBase<WirelessSnapshot> {
    private var wifiSnapshot = WiFiSnapshot(ssid: nil, rssi: nil, on: false)
    private var bluetoothSnapshot = BluetoothSnapshot(connectedCount: 0, on: false)

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
        return MetricThresholds.wireless.level(for: gaugeValue ?? 0)
    }

    override public init(
        monitor: some MetricMonitorProtocol<WirelessSnapshot>,
        batcher: any UpdateScheduling = DashboardUpdateBatcher.shared
    ) {
        super.init(monitor: monitor, batcher: batcher)
    }

    public convenience init(
        wifiMonitor: some MetricMonitorProtocol<WiFiSnapshot>,
        btMonitor: some MetricMonitorProtocol<BluetoothSnapshot>,
        batcher: any UpdateScheduling = DashboardUpdateBatcher.shared
    ) {
        self.init(
            monitor: ZipMonitor(left: wifiMonitor, right: btMonitor) { wifi, bluetooth in
                WirelessSnapshot(wifi: wifi, bluetooth: bluetooth)
            },
            batcher: batcher
        )
    }

    override public func receive(_ snapshot: WirelessSnapshot) {
        let didWiFiChange = snapshot.wifi != wifiSnapshot
        wifiSnapshot = snapshot.wifi
        bluetoothSnapshot = snapshot.bluetooth

        if didWiFiChange {
            appendHistory(snapshot.wifi.rssi.map(Self.normaliseRSSI) ?? 0)
        }
    }

    override public func makeTileModel() -> MetricTileModel {
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
