import SwiftUI

/// Swaps the heavy dashboard view graph out when the main window is closed.
struct DashboardSceneView: View {
    let services: ServiceContainer
    @Binding var isWindowVisible: Bool

    var body: some View {
        Group {
            if isWindowVisible {
                DashboardView(services: services)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: Constants.dashboardMinimumWindowWidth)
        .background(
            DashboardWindowObserver(isWindowVisible: $isWindowVisible)
                .frame(width: 0, height: 0)
        )
    }
}
