import SwiftUI

extension View {
    /// Marks a view as an interactive button tile:
    /// adds the `.isButton` accessibility trait and registers a tap action.
    func tileButton(action: @escaping @MainActor () -> Void) -> some View {
        onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Open detail view")
    }
}
