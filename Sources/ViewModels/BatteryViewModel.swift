import SwiftUI

@MainActor
@Observable
public final class BatteryViewModel: MonitorViewModelBase<BatterySnapshot> {
    static let maxVisibleTileGaugeRows = 4

    private let peripheralBatteryProvider: any PeripheralBatteryProviding
    private let peripheralRefreshInterval: Duration
    private var peripheralRefreshTask: Task<Void, Never>?

    public private(set) var snapshot = BatterySnapshot(
        isPresent: false, chargeFraction: 0, isCharging: false,
        onAC: true, timeToEmptyMinutes: nil, cycleCount: nil, healthFraction: nil
    )
    public private(set) var connectedDeviceBatteries: [PeripheralBattery] = []
    public private(set) var isLoadingConnectedDeviceBatteries = false

    public init(
        monitor: some MetricMonitorProtocol<BatterySnapshot>,
        batcher: any UpdateScheduling = DashboardUpdateBatcher.shared,
        peripheralBatteryProvider: any PeripheralBatteryProviding = BluetoothPeripheralBatteryProvider(),
        peripheralRefreshInterval: Duration = .seconds(30)
    ) {
        self.peripheralBatteryProvider = peripheralBatteryProvider
        self.peripheralRefreshInterval = peripheralRefreshInterval
        super.init(monitor: monitor, batcher: batcher)
    }

    public var gaugeValue: Double? { snapshot.isPresent ? snapshot.chargeFraction : nil }
    public var chargeLabel: String { Self.makeChargeLabel(from: snapshot) }
    public var statusLabel: String? { Self.makeStatusLabel(from: snapshot) }
    public var cycleLabel: String? { snapshot.cycleCount.map { "\($0) cycles" } }

    public var thresholdLevel: ThresholdLevel {
        guard snapshot.isPresent else { return .inactive }
        return MetricThresholds.battery.level(for: snapshot.chargeFraction)
    }

    override public func receive(_ newSnapshot: BatterySnapshot) {
        snapshot = newSnapshot
        appendHistory(newSnapshot.chargeFraction)
        refreshTileModel()
    }

    override public func makeTileModel() -> MetricTileModel {
        let thresholdLevel: ThresholdLevel = snapshot.isPresent
            ? MetricThresholds.battery.level(for: snapshot.chargeFraction)
            : .inactive
        return MetricTileModel(
            title: "Battery",
            value: chargeLabel,
            gaugeValue: gaugeValue,
            gaugeColorProfile: snapshot.isPresent ? .battery : .inactive,
            history: history,
            thresholdLevel: thresholdLevel,
            subtitle: tileSubtitle,
            unavailableReason: snapshot.isPresent ? nil : "No battery on this Mac",
            systemImage: "battery.100"
        )
    }

    private static func makeChargeLabel(from snapshot: BatterySnapshot) -> String {
        guard snapshot.isPresent else { return "AC Power" }
        return "\(Int((snapshot.chargeFraction * 100).rounded()))%"
    }

    static func makeStatusLabel(from snapshot: BatterySnapshot) -> String? {
        guard snapshot.isPresent else { return nil }
        if snapshot.isCharging { return "Charging" }
        if snapshot.onAC { return "Charged" }
        if let tte = snapshot.timeToEmptyMinutes {
            let hours = tte / 60
            let mins = tte % 60
            return hours > 0 ? "\(hours)h \(mins)m left" : "\(mins)m left"
        }
        return "On battery"
    }

    public func startPeripheralBatteryRefreshLoop() {
        guard peripheralRefreshTask == nil else { return }

        peripheralRefreshTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.refreshConnectedDeviceBatteries()

                do {
                    try await Task.sleep(for: self.peripheralRefreshInterval)
                } catch {
                    break
                }
            }
        }
    }

    public func stopPeripheralBatteryRefreshLoop() {
        peripheralRefreshTask?.cancel()
        peripheralRefreshTask = nil
    }

    public func refreshConnectedDeviceBatteries() async {
        guard !isLoadingConnectedDeviceBatteries else { return }
        isLoadingConnectedDeviceBatteries = true
        refreshTileModel()
        defer {
            isLoadingConnectedDeviceBatteries = false
            refreshTileModel()
        }

        let batteries = await peripheralBatteryProvider.peripheralBatteries()
        connectedDeviceBatteries = Self.disambiguatedDeviceBatteries(from: batteries)
        refreshTileModel()
    }

    public var detailModel: DetailModel {
        var stats: [DetailModel.Stat] = []
        if snapshot.isPresent {
            stats.append(.init(label: "Charge", value: chargeLabel))
            if let cycles = snapshot.cycleCount {
                stats.append(.init(label: "Cycle count", value: "\(cycles)"))
            }
            if let health = snapshot.healthFraction {
                stats.append(.init(label: "Health", value: health.percentFormatted()))
            }
            if let status = statusLabel {
                stats.append(.init(label: "Status", value: status))
            }
        }

        if isLoadingConnectedDeviceBatteries, connectedDeviceBatteries.isEmpty {
            stats.append(.init(label: "Connected devices", value: "Loading..."))
        } else if connectedDeviceBatteries.isEmpty {
            if !snapshot.isPresent {
                stats.append(.init(label: "Connected devices", value: "None reported"))
            }
        } else {
            stats.append(contentsOf: connectedDeviceBatteries.map {
                .init(label: $0.name, value: "\($0.percent)%")
            })
        }

        return DetailModel(
            title: "Battery",
            systemImage: "battery.100",
            primaryValue: chargeLabel,
            thresholdLevel: thresholdLevel,
            history: extendedHistory,
            stats: stats
        )
    }

    static func disambiguatedDeviceBatteries(
        from batteries: [PeripheralBattery]
    ) -> [PeripheralBattery] {
        let sorted = batteries.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        var seenCounts: [String: Int] = [:]

        return sorted.map { battery in
            let count = seenCounts[battery.name, default: 0] + 1
            seenCounts[battery.name] = count

            guard count > 1 else { return battery }
            return PeripheralBattery(name: battery.name + " (\(count))", percent: battery.percent)
        }
    }
}
