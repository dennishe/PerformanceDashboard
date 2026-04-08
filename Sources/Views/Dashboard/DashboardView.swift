import SwiftUI
import AppKit

/// Root dashboard view — all metrics visible without scrolling on wide displays.
struct DashboardView: View {
    let services: ServiceContainer

    @State private var contentHeight = Constants.dashboardMinimumContentHeight
    @State private var detailVM: (any DetailPresenting)?
    @State private var isSettingsVisible = false

    private var settings: DashboardSettings { services.settings }
    private var isDetailOpen: Bool { detailVM != nil }

    var body: some View {
        ZStack {
            tileGrid
            if isDetailOpen { detailOverlay }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isDetailOpen)
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        DashboardLayout(
            spacing: 12,
            minTileWidth: settings.densityPreset.minTileWidth,
            onContentHeightChange: updateContentHeight
        ) {
            if settings.isVisible(.cpu) {
                CPUTileView(viewModel: services.cpu).wideEligible()
                    .tileButton { detailVM = services.cpu }
            }
            if settings.isVisible(.gpu) {
                GPUTileView(viewModel: services.gpu).wideEligible()
                    .tileButton { detailVM = services.gpu }
            }
            if settings.isVisible(.memory) {
                MemoryTileView(viewModel: services.memory).wideEligible()
                    .tileButton { detailVM = services.memory }
            }
            if settings.isVisible(.network) {
                NetworkTileView(viewModel: services.network)
                    .tileButton { detailVM = services.network }
            }
            if settings.isVisible(.disk) {
                DiskTileView(viewModel: services.disk)
                    .tileButton { detailVM = services.disk }
            }
            #if arch(arm64)
            if settings.isVisible(.ane) {
                ANETileView(viewModel: services.accelerator)
                    .tileButton { detailVM = services.accelerator }
            }
            if settings.isVisible(.mediaEngine) {
                MediaEngineTileView(viewModel: services.mediaEngine)
                    .tileButton { detailVM = services.mediaEngine }
            }
            #endif
            if settings.isVisible(.power) {
                PowerTileView(viewModel: services.power)
                    .tileButton { detailVM = services.power }
            }
            if settings.isVisible(.thermal) {
                ThermalTileView(viewModel: services.thermal)
                    .tileButton { detailVM = services.thermal }
            }
            if settings.isVisible(.fan) {
                FanTileView(viewModel: services.fan)
                    .tileButton { detailVM = services.fan }
            }
            if settings.isVisible(.battery) {
                BatteryTileView(viewModel: services.battery)
                    .tileButton { detailVM = services.battery }
            }
            if settings.isVisible(.wireless) {
                WirelessTileView(viewModel: services.wireless)
                    .tileButton { detailVM = services.wireless }
            }
        }
        .background(Color.dashboardBackground.ignoresSafeArea())
        .background(TitlebarConfigurator(
            onSettingsTapped: { isSettingsVisible.toggle() },
            isSettingsVisible: $isSettingsVisible,
            settings: settings
        ))
        .background(
            WindowHeightSizer(
                contentHeight: contentHeight,
                minContentHeight: Constants.dashboardMinimumContentHeight
            )
        )
    }

    // MARK: - Detail overlay

    @ViewBuilder private var detailOverlay: some View {
        Color.black.opacity(0.45)
            .ignoresSafeArea()
            .onTapGesture { closeDetail() }
        if let vm = detailVM {
            MetricDetailView(viewModel: vm, onDismiss: closeDetail)
                .frame(minWidth: 420, maxWidth: 560)
                .padding(44)
                .transition(.scale(scale: 0.94, anchor: .center).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func closeDetail() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            detailVM = nil
        }
    }

    @MainActor
    private func updateContentHeight(_ height: CGFloat) {
        let clampedHeight = max(Constants.dashboardMinimumContentHeight, height.rounded(.up))
        guard abs(contentHeight - clampedHeight) > 0.5 else { return }
        contentHeight = clampedHeight
    }
}

#Preview {
    let services = ServiceContainer()
    return DashboardView(services: services)
}
