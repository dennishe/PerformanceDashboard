import SwiftUI

@main
struct PerformanceDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var services = ServiceContainer()
    @State private var monitorsStarted = false

    var body: some Scene {
        Window("Performance Dashboard", id: "main") {
            DashboardView(services: services)
                .frame(minWidth: 900, minHeight: 500)
                .task {
                    guard !monitorsStarted else { return }
                    monitorsStarted = true
                    services.startAll()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)

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
