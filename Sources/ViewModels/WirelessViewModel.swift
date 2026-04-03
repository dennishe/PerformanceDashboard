import SwiftUI

/// Threshold levels for Wi-Fi signal quality (higher = better).
public struct WirelessThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case 0.5...: return .normal    // RSSI ≥ −65 dBm
        case 0.36...: return .warning  // RSSI ~ −72 dBm
        default:     return .critical  // Disconnected or very weak
        }
    }
}

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

    public var ssidLabel: String? {
        wifiSSID
    }

    public var bluetoothLabel: String {
        guard bluetoothOn else { return "BT Off" }
        return "BT: \(bluetoothConnectedCount) connected"
    }

    public var thresholdLevel: ThresholdLevel {
        guard wifiOn, wifiRSSI != nil else { return .inactive }
        return WirelessThreshold().level(for: gaugeValue ?? 0)
    }

    private let monitor: any MetricMonitorProtocol<WirelessSnapshot>
    private var task: Task<Void, Never>?

    public init(monitor: some MetricMonitorProtocol<WirelessSnapshot>) {
        self.monitor = monitor
    }

    public func start() {
        task = Task {
            for await snapshot in monitor.stream() {
                update(snapshot)
            }
        }
    }

    public func stop() {
        task?.cancel()
        monitor.stop()
    }

    private func update(_ snapshot: WirelessSnapshot) {
        wifiSSID = snapshot.wifiSSID
        wifiRSSI = snapshot.wifiRSSI
        wifiOn = snapshot.wifiOn
        bluetoothConnectedCount = snapshot.bluetoothConnectedCount
        bluetoothOn = snapshot.bluetoothOn
        let normalized = snapshot.wifiRSSI.map {
            WirelessViewModel.normaliseRSSI($0)
        } ?? 0
        history.append(normalized)
        if history.count > Constants.historySamples { history.removeFirst() }
    }
}
