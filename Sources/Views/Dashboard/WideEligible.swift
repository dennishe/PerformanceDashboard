import SwiftUI

struct WideEligibleKey: LayoutValueKey {
    static let defaultValue = true
}

extension View {
    /// Marks a tile as ineligible to grow to two columns.
    func wideIneligible() -> some View {
        layoutValue(key: WideEligibleKey.self, value: false)
    }
}
