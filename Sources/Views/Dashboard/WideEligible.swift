import SwiftUI

struct WideEligibleKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// Marks a tile as eligible to grow to two columns when the layout needs to fill the last row.
    func wideEligible() -> some View {
        layoutValue(key: WideEligibleKey.self, value: true)
    }
}
