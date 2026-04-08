import Foundation

// MARK: - TileID

/// Stable identifier for each dashboard tile, used for visibility and ordering preferences.
enum TileID: String, CaseIterable, Sendable {
    case cpu, gpu, memory, network, disk, power, thermal, fan, battery, wireless
    case ane, mediaEngine

    var displayName: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .network: "Network"
        case .disk: "Disk"
        case .power: "Power"
        case .thermal: "Temperature"
        case .fan: "Fans"
        case .battery: "Battery"
        case .wireless: "Wireless"
        case .ane: "ANE (Neural Engine)"
        case .mediaEngine: "Media Engine"
        }
    }

    /// Tiles supported on the current architecture.
    static var available: [TileID] {
        #if arch(arm64)
        allCases
        #else
        allCases.filter { $0 != .ane && $0 != .mediaEngine }
        #endif
    }
}

// MARK: - DensityPreset

/// Controls minimum tile width, which in turn determines the column count.
enum DensityPreset: String, CaseIterable, Sendable {
    case comfortable
    case compact

    var displayName: String {
        switch self {
        case .comfortable: "Comfortable"
        case .compact: "Compact"
        }
    }

    /// Minimum tile width passed to `DashboardLayout`.
    var minTileWidth: CGFloat {
        switch self {
        case .comfortable: 220
        case .compact: 170
        }
    }
}

// MARK: - DashboardSettings

/// Persists user preferences for tile visibility and layout density.
@Observable
final class DashboardSettings {
    private(set) var hiddenTileIDs: Set<String> {
        didSet { saveHiddenTiles() }
    }
    var densityPreset: DensityPreset {
        didSet { saveDensity() }
    }

    init() {
        hiddenTileIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.hiddenTiles) ?? [])
        densityPreset = DensityPreset(
            rawValue: UserDefaults.standard.string(forKey: Keys.densityPreset) ?? ""
        ) ?? .comfortable
    }

    func isVisible(_ tile: TileID) -> Bool {
        !hiddenTileIDs.contains(tile.rawValue)
    }

    func toggle(_ tile: TileID) {
        if hiddenTileIDs.contains(tile.rawValue) {
            hiddenTileIDs.remove(tile.rawValue)
        } else {
            hiddenTileIDs.insert(tile.rawValue)
        }
    }

    private func saveHiddenTiles() {
        UserDefaults.standard.set(Array(hiddenTileIDs), forKey: Keys.hiddenTiles)
    }

    private func saveDensity() {
        UserDefaults.standard.set(densityPreset.rawValue, forKey: Keys.densityPreset)
    }

    private enum Keys {
        static let hiddenTiles = "pd.hiddenTileIDs"
        static let densityPreset = "pd.densityPreset"
    }
}
