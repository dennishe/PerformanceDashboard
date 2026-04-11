import Foundation

/// Composition root for the dashboard.
///
/// Creates and wires the full service and view-model graph once at app launch.
/// This is intentionally a simple eager environment object, not a DI container.
@MainActor
@Observable
final class ServiceContainer {
    private struct MetricEntry {
        let start: @MainActor () -> Void
        let stop: @MainActor () -> Void
    }

    let settings: DashboardSettings
    let cpu: CPUViewModel
    let gpu: GPUViewModel
    let memory: MemoryViewModel
    let network: NetworkViewModel
    let disk: DiskViewModel
    let accelerator: AcceleratorViewModel
    let power: PowerViewModel
    let fan: FanViewModel
    let thermal: ThermalViewModel
    let battery: BatteryViewModel
    let mediaEngine: MediaEngineViewModel
    let wireless: WirelessViewModel

    private let entries: [MetricEntry]

    init(
        settings: DashboardSettings = DashboardSettings(),
        cpu: CPUViewModel = CPUViewModel(monitor: CPUMonitorService()),
        gpu: GPUViewModel = GPUViewModel(monitor: GPUMonitorService()),
        memory: MemoryViewModel = MemoryViewModel(monitor: MemoryMonitorService()),
        network: NetworkViewModel = NetworkViewModel(monitor: NetworkMonitorService()),
        disk: DiskViewModel = DiskViewModel(monitor: DiskMonitorService()),
        accelerator: AcceleratorViewModel = AcceleratorViewModel(monitor: AcceleratorMonitorService()),
        power: PowerViewModel = PowerViewModel(monitor: PowerMonitorService()),
        fan: FanViewModel = FanViewModel(monitor: FanMonitorService()),
        thermal: ThermalViewModel = ThermalViewModel(monitor: ThermalMonitorService()),
        battery: BatteryViewModel = BatteryViewModel(monitor: BatteryMonitorService()),
        mediaEngine: MediaEngineViewModel = MediaEngineViewModel(monitor: MediaEngineMonitorService()),
        wireless: WirelessViewModel = WirelessViewModel(
            wifiMonitor: WiFiMonitorService(),
            btMonitor: BluetoothMonitorService()
        )
    ) {
        let entries = [
            MetricEntry(start: cpu.start, stop: cpu.stop),
            MetricEntry(start: gpu.start, stop: gpu.stop),
            MetricEntry(start: memory.start, stop: memory.stop),
            MetricEntry(start: network.start, stop: network.stop),
            MetricEntry(start: disk.start, stop: disk.stop),
            MetricEntry(start: accelerator.start, stop: accelerator.stop),
            MetricEntry(start: power.start, stop: power.stop),
            MetricEntry(start: fan.start, stop: fan.stop),
            MetricEntry(start: thermal.start, stop: thermal.stop),
            MetricEntry(
                start: {
                    battery.start()
                    battery.startPeripheralBatteryRefreshLoop()
                },
                stop: {
                    battery.stopPeripheralBatteryRefreshLoop()
                    battery.stop()
                }
            ),
            MetricEntry(start: mediaEngine.start, stop: mediaEngine.stop),
            MetricEntry(start: wireless.start, stop: wireless.stop)
        ]

        self.settings = settings
        self.cpu = cpu
        self.gpu = gpu
        self.memory = memory
        self.network = network
        self.disk = disk
        self.accelerator = accelerator
        self.power = power
        self.fan = fan
        self.thermal = thermal
        self.battery = battery
        self.mediaEngine = mediaEngine
        self.wireless = wireless
        self.entries = entries
    }

    func startAll() {
        entries.forEach { $0.start() }
    }

    func stopAll() {
        entries.forEach { $0.stop() }
    }
}
