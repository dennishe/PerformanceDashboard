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

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DashboardLayout(spacing: 12, minTileWidth: 220) {
                CPUTileView(viewModel: cpuViewModel).wideEligible()
                GPUTileView(viewModel: gpuViewModel).wideEligible()
                MemoryTileView(viewModel: memoryViewModel).wideEligible()
                NetworkInTileView(viewModel: networkViewModel)
                NetworkOutTileView(viewModel: networkViewModel)
                DiskTileView(viewModel: diskViewModel)
                #if arch(arm64)
                ANETileView(viewModel: acceleratorViewModel)
                MediaEngineTileView(viewModel: mediaEngineViewModel)
                #endif
                PowerTileView(viewModel: powerViewModel)
                ThermalTileView(viewModel: thermalViewModel)
                FanTileView(viewModel: fanViewModel)
                BatteryTileView(viewModel: batteryViewModel)
                WirelessTileView(viewModel: wirelessViewModel)
            }
        }
        .background(Color.dashboardBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            Text("Performance")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: .green.opacity(0.7), radius: 4)
                .opacity(isPulsing ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
