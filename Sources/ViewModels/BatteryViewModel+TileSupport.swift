import Foundation

extension BatteryViewModel {
    var tileSubtitle: String? {
        Self.makeTileSubtitle(from: snapshot, devices: connectedDeviceBatteries)
    }

    var visibleTileGaugeRows: [BatteryTileGaugeRow] {
        Array(tileGaugeRows.prefix(Self.maxVisibleTileGaugeRows))
    }

    var hiddenTileGaugeRowCount: Int {
        max(0, tileGaugeRows.count - Self.maxVisibleTileGaugeRows)
    }

    var tileGaugeRows: [BatteryTileGaugeRow] {
        var rows: [BatteryTileGaugeRow] = []

        if snapshot.isPresent {
            rows.append(BatteryTileGaugeRow(
                id: "host-battery",
                name: "This Mac",
                fraction: snapshot.chargeFraction,
                thresholdLevel: thresholdLevel,
                isPrimary: true
            ))
        }

        rows.append(contentsOf: connectedDeviceBatteries.map(Self.makeTileGaugeRow(from:)))
        return rows
    }
}
private extension BatteryViewModel {
    static func makeTileSubtitle(
        from snapshot: BatterySnapshot,
        devices: [PeripheralBattery]
    ) -> String? {
        let accessoryLabel = accessoryCountLabel(for: devices.count)

        if snapshot.isPresent {
            if let status = makeStatusLabel(from: snapshot) {
                return devices.isEmpty ? status : status + " · \(accessoryLabel)"
            }
            return devices.isEmpty ? nil : accessoryLabel
        }

        if !devices.isEmpty {
            return "Connected accessory batteries"
        }

        return "No battery on this Mac"
    }

    static func accessoryCountLabel(for count: Int) -> String {
        "\(count) accessor\(count == 1 ? "y" : "ies")"
    }

    static func makeTileGaugeRow(from battery: PeripheralBattery) -> BatteryTileGaugeRow {
        let fraction = Double(battery.percent) / 100
        return BatteryTileGaugeRow(
            id: battery.name,
            name: battery.name,
            fraction: fraction,
            thresholdLevel: MetricThresholds.battery.level(for: fraction)
        )
    }
}
