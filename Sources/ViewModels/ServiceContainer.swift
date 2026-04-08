import Foundation

/// Composition root for the dashboard.
///
/// Creates and wires the full service and view-model graph once at app launch.
/// This is intentionally a simple eager environment object, not a DI container.
@MainActor
@Observable
final class ServiceContainer {
    let settings      = DashboardSettings()
    let cpu           = CPUViewModel(monitor: CPUMonitorService())
    let gpu           = GPUViewModel(monitor: GPUMonitorService())
    let memory        = MemoryViewModel(monitor: MemoryMonitorService())
    let network       = NetworkViewModel(monitor: NetworkMonitorService())
    let disk          = DiskViewModel(monitor: DiskMonitorService())
    let accelerator   = AcceleratorViewModel(monitor: AcceleratorMonitorService())
    let power         = PowerViewModel(monitor: PowerMonitorService())
    let fan           = FanViewModel(monitor: FanMonitorService())
    let thermal       = ThermalViewModel(monitor: ThermalMonitorService())
    let battery       = BatteryViewModel(monitor: BatteryMonitorService())
    let mediaEngine   = MediaEngineViewModel(monitor: MediaEngineMonitorService())
    let wireless = WirelessViewModel(
        wifiMonitor: WiFiMonitorService(),
        btMonitor: BluetoothMonitorService()
    )

    func startAll() {
        cpu.start(); gpu.start(); memory.start(); network.start()
        disk.start(); accelerator.start(); power.start(); fan.start()
        thermal.start(); battery.start(); mediaEngine.start(); wireless.start()
    }

    func stopAll() {
        cpu.stop(); gpu.stop(); memory.stop(); network.stop()
        disk.stop(); accelerator.stop(); power.stop(); fan.stop()
        thermal.stop(); battery.stop(); mediaEngine.stop(); wireless.stop()
    }
}
