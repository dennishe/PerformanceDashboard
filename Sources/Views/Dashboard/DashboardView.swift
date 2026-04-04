import SwiftUI

/// Root dashboard view — all metrics visible without scrolling on wide displays.
struct DashboardView: View {
    let services: ServiceContainer

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DashboardLayout(spacing: 12, minTileWidth: 220) {
                CPUTileView(viewModel: services.cpu).wideEligible()
                GPUTileView(viewModel: services.gpu).wideEligible()
                MemoryTileView(viewModel: services.memory).wideEligible()
                NetworkInTileView(viewModel: services.network)
                NetworkOutTileView(viewModel: services.network)
                DiskTileView(viewModel: services.disk)
                #if arch(arm64)
                ANETileView(viewModel: services.accelerator)
                MediaEngineTileView(viewModel: services.mediaEngine)
                #endif
                PowerTileView(viewModel: services.power)
                ThermalTileView(viewModel: services.thermal)
                FanTileView(viewModel: services.fan)
                BatteryTileView(viewModel: services.battery)
                WirelessTileView(viewModel: services.wireless)
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
    let services = ServiceContainer()
    return DashboardView(services: services)
}
