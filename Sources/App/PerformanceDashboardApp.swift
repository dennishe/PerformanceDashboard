import SwiftUI

@main
struct PerformanceDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var services = ServiceContainer()
    @State private var isDashboardWindowVisible = true
    @State private var monitorsStarted = false

    var body: some Scene {
        Window("Performance Dashboard", id: "main") {
            DashboardSceneView(
                services: services,
                isWindowVisible: $isDashboardWindowVisible
            )
                .task {
                    guard !monitorsStarted else { return }
                    monitorsStarted = true
                    services.startAll()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(
            width: Constants.dashboardDefaultWindowWidth,
            height: Constants.dashboardDefaultWindowHeight
        )

        MenuBarExtra("Performance Dashboard", systemImage: "gauge") {
            MenuBarMetricsView(
                cpuViewModel: services.cpu,
                gpuViewModel: services.gpu,
                memoryViewModel: services.memory,
                networkViewModel: services.network,
                diskViewModel: services.disk,
                acceleratorViewModel: services.accelerator,
                openDashboard: { NSApp.activate(ignoringOtherApps: true) },
                quit: { NSApp.terminate(nil) }
            )
        }
        .menuBarExtraStyle(.window)
    }
}
