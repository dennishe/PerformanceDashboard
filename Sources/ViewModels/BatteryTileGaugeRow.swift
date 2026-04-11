import Foundation

struct BatteryTileGaugeRow: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let valueText: String
    let fraction: Double
    let thresholdLevel: ThresholdLevel
    let isPrimary: Bool

    init(
        id: String,
        name: String,
        fraction: Double,
        thresholdLevel: ThresholdLevel,
        isPrimary: Bool = false
    ) {
        let clampedFraction = min(max(fraction, 0), 1)

        self.id = id
        self.name = name
        self.valueText = "\(Int((clampedFraction * 100).rounded()))%"
        self.fraction = clampedFraction
        self.thresholdLevel = thresholdLevel
        self.isPrimary = isPrimary
    }
}
