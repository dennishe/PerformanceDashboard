import SwiftUI

@main
struct PerformanceDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var cpuViewModel = CPUViewModel(monitor: CPUMonitorService())
    @State private var gpuViewModel = GPUViewModel(monitor: GPUMonitorService())
    @State private var memoryViewModel = MemoryViewModel(monitor: MemoryMonitorService())
    @State private var networkViewModel = NetworkViewModel(monitor: NetworkMonitorService())
    @State private var diskViewModel = DiskViewModel(monitor: DiskMonitorService())
    @State private var acceleratorViewModel = AcceleratorViewModel(monitor: AcceleratorMonitorService())
    @State private var powerViewModel = PowerViewModel(monitor: PowerMonitorService())
    @State private var fanViewModel = FanViewModel(monitor: FanMonitorService())
    @State private var thermalViewModel = ThermalViewModel(monitor: ThermalMonitorService())
    @State private var batteryViewModel = BatteryViewModel(monitor: BatteryMonitorService())
    @State private var mediaEngineViewModel = MediaEngineViewModel(monitor: MediaEngineMonitorService())
    @State private var wirelessViewModel = WirelessViewModel(monitor: WirelessMonitorService())

    @State private var monitorsStarted = false

    var body: some Scene {
        Window("Performance Dashboard", id: "main") {
            DashboardView(
                cpuViewModel: cpuViewModel,
                gpuViewModel: gpuViewModel,
                memoryViewModel: memoryViewModel,
                networkViewModel: networkViewModel,
                diskViewModel: diskViewModel,
                acceleratorViewModel: acceleratorViewModel,
                powerViewModel: powerViewModel,
                fanViewModel: fanViewModel,
                thermalViewModel: thermalViewModel,
                batteryViewModel: batteryViewModel,
                mediaEngineViewModel: mediaEngineViewModel,
                wirelessViewModel: wirelessViewModel
            )
            .frame(minWidth: 900, minHeight: 500)
            .task {
                guard !monitorsStarted else { return }
                monitorsStarted = true
                startAll()
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Performance Dashboard", systemImage: "gauge") {
            MenuBarMetricsView(
                cpuViewModel: cpuViewModel,
                gpuViewModel: gpuViewModel,
                memoryViewModel: memoryViewModel,
                networkViewModel: networkViewModel,
                diskViewModel: diskViewModel,
                acceleratorViewModel: acceleratorViewModel
            )
        }
        .menuBarExtraStyle(.window)
    }

    private func startAll() {
        cpuViewModel.start()
        gpuViewModel.start()
        memoryViewModel.start()
        networkViewModel.start()
        diskViewModel.start()
        acceleratorViewModel.start()
        powerViewModel.start()
        fanViewModel.start()
        thermalViewModel.start()
        batteryViewModel.start()
        mediaEngineViewModel.start()
        wirelessViewModel.start()
    }
}
