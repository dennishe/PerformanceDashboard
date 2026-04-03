import SwiftUI

/// Root dashboard view — all metrics visible without scrolling on wide displays.
struct DashboardView: View {
    let cpuViewModel: CPUViewModel
    let gpuViewModel: GPUViewModel
    let memoryViewModel: MemoryViewModel
    let networkViewModel: NetworkViewModel
    let diskViewModel: DiskViewModel
    let acceleratorViewModel: AcceleratorViewModel
    let powerViewModel: PowerViewModel
    let fanViewModel: FanViewModel
    let thermalViewModel: ThermalViewModel
    let batteryViewModel: BatteryViewModel
    let mediaEngineViewModel: MediaEngineViewModel
    let wirelessViewModel: WirelessViewModel

    var body: some View {
        DashboardLayout(spacing: 12, minTileWidth: 220) {
            cpuTile.wideEligible()
            gpuTile.wideEligible()
            memoryTile.wideEligible()
            networkInTile
            networkOutTile
            diskTile
            #if arch(arm64)
            aneTile
            mediaEngineTile
            #endif
            powerTile
            thermalTile
            fanTile
            batteryTile
            wirelessTile
        }
        .background(Color.dashboardBackground)
    }

    // MARK: - Tile builders

    private var cpuTile: some View {
        MetricTileView(title: "CPU", value: cpuViewModel.usageLabel,
                       gaugeValue: cpuViewModel.usage, history: cpuViewModel.history,
                       thresholdLevel: cpuViewModel.thresholdLevel)
    }

    private var gpuTile: some View {
        MetricTileView(title: "GPU", value: gpuViewModel.usageLabel,
                       gaugeValue: gpuViewModel.usage, history: gpuViewModel.history,
                       thresholdLevel: gpuViewModel.thresholdLevel)
    }

    private var memoryTile: some View {
        MetricTileView(title: "Memory", value: memoryViewModel.usageLabel,
                       gaugeValue: memoryViewModel.usage, history: memoryViewModel.history,
                       thresholdLevel: memoryViewModel.thresholdLevel,
                       subtitle: "\(memoryViewModel.usedLabel) / \(memoryViewModel.totalLabel)")
    }

    private var networkInTile: some View {
        MetricTileView(title: "Network In", value: networkViewModel.inLabel,
                       gaugeValue: networkViewModel.inGauge, history: networkViewModel.historyInGauge,
                       thresholdLevel: networkViewModel.thresholdLevel)
    }

    private var networkOutTile: some View {
        MetricTileView(title: "Network Out", value: networkViewModel.outLabel,
                       gaugeValue: networkViewModel.outGauge, history: networkViewModel.historyOutGauge,
                       thresholdLevel: networkViewModel.thresholdLevel)
    }

    private var diskTile: some View {
        MetricTileView(title: "Disk", value: diskViewModel.usageLabel,
                       gaugeValue: diskViewModel.usage, history: diskViewModel.history,
                       thresholdLevel: diskViewModel.thresholdLevel,
                       subtitle: diskViewModel.availableLabel + " free")
    }

    #if arch(arm64)
    private var aneTile: some View {
        MetricTileView(title: "ANE", value: acceleratorViewModel.usageLabel,
                       gaugeValue: acceleratorViewModel.aneUsage, history: acceleratorViewModel.history,
                       thresholdLevel: acceleratorViewModel.thresholdLevel)
    }

    private var mediaEngineTile: some View {
        MetricTileView(title: "Media Eng.", value: mediaEngineViewModel.combinedLabel,
                       gaugeValue: mediaEngineViewModel.gaugeValue, history: mediaEngineViewModel.history,
                       thresholdLevel: mediaEngineViewModel.thresholdLevel,
                       subtitle: mediaEngineViewModel.decodeLabel)
    }
    #endif

    private var powerTile: some View {
        MetricTileView(title: "Power", value: powerViewModel.wattsLabel,
                       gaugeValue: powerViewModel.gaugeValue, history: powerViewModel.history,
                       thresholdLevel: powerViewModel.thresholdLevel)
    }

    private var thermalTile: some View {
        MetricTileView(title: "Temp", value: thermalViewModel.cpuLabel,
                       gaugeValue: thermalViewModel.gaugeValue, history: thermalViewModel.history,
                       thresholdLevel: thermalViewModel.thresholdLevel,
                       subtitle: thermalViewModel.gpuLabel)
    }

    private var fanTile: some View {
        MetricTileView(title: "Fans", value: fanViewModel.primaryLabel,
                       gaugeValue: fanViewModel.gaugeValue, history: fanViewModel.history,
                       thresholdLevel: fanViewModel.thresholdLevel,
                       subtitle: fanViewModel.subtitle)
    }

    private var batteryTile: some View {
        MetricTileView(title: "Battery", value: batteryViewModel.chargeLabel,
                       gaugeValue: batteryViewModel.gaugeValue, history: batteryViewModel.history,
                       thresholdLevel: batteryViewModel.thresholdLevel,
                       subtitle: batteryViewModel.statusLabel)
    }

    private var wirelessTile: some View {
        MetricTileView(title: "Wireless", value: wirelessViewModel.signalLabel,
                       gaugeValue: wirelessViewModel.gaugeValue, history: wirelessViewModel.history,
                       thresholdLevel: wirelessViewModel.thresholdLevel,
                       subtitle: wirelessViewModel.bluetoothLabel)
    }
}

#Preview {
    DashboardView(
        cpuViewModel: CPUViewModel(monitor: MockCPUMonitor()),
        gpuViewModel: GPUViewModel(monitor: MockGPUMonitor()),
        memoryViewModel: MemoryViewModel(monitor: MockMemoryMonitor()),
        networkViewModel: NetworkViewModel(monitor: MockNetworkMonitor()),
        diskViewModel: DiskViewModel(monitor: MockDiskMonitor()),
        acceleratorViewModel: AcceleratorViewModel(monitor: MockAcceleratorMonitor()),
        powerViewModel: PowerViewModel(monitor: MockPowerMonitor()),
        fanViewModel: FanViewModel(monitor: MockFanMonitor()),
        thermalViewModel: ThermalViewModel(monitor: MockThermalMonitor()),
        batteryViewModel: BatteryViewModel(monitor: MockBatteryMonitor()),
        mediaEngineViewModel: MediaEngineViewModel(monitor: MockMediaEngineMonitor()),
        wirelessViewModel: WirelessViewModel(monitor: MockWirelessMonitor())
    )
}
