import SwiftUI
import AppKit

private enum DashboardDetailSelection {
    case cpu
    case gpu
    case memory
    case network
    case disk
    case ane
    case mediaEngine
    case power
    case thermal
    case fan
    case battery
    case wireless
}

/// Root dashboard view — all metrics visible without scrolling on wide displays.
struct DashboardView: View {
    let services: ServiceContainer

    @State private var contentHeight: CGFloat = 1
    @State private var detailSelection: DashboardDetailSelection?
    @State private var isSettingsVisible = false

    private var settings: DashboardSettings { services.settings }
    private var isDetailOpen: Bool { detailSelection != nil }

    var body: some View {
        ZStack {
            tileGrid
            if isDetailOpen { detailOverlay }
        }
        .animation(DashboardDesign.Animation.detailReveal, value: isDetailOpen)
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        DashboardLayout(
            spacing: 12,
            minTileWidth: settings.densityPreset.minTileWidth,
            onContentHeightChange: updateContentHeight
        ) {
            if settings.isVisible(.cpu) {
                MetricTileView(model: services.cpu.tileModel)
                    .tileButton { detailSelection = .cpu }
            }
            if settings.isVisible(.gpu) {
                MetricTileView(model: services.gpu.tileModel)
                    .tileButton { detailSelection = .gpu }
            }
            if settings.isVisible(.memory) {
                MetricTileView(model: services.memory.tileModel)
                    .tileButton { detailSelection = .memory }
            }
            if settings.isVisible(.network) {
                NetworkTileView(viewModel: services.network)
                    .tileButton { detailSelection = .network }
            }
            if settings.isVisible(.disk) {
                MetricTileView(model: services.disk.tileModel)
                    .tileButton { detailSelection = .disk }
            }
            #if arch(arm64)
            if settings.isVisible(.ane) {
                MetricTileView(model: services.accelerator.tileModel)
                    .tileButton { detailSelection = .ane }
            }
            if settings.isVisible(.mediaEngine) {
                MetricTileView(model: services.mediaEngine.tileModel)
                    .tileButton { detailSelection = .mediaEngine }
            }
            #endif
            if settings.isVisible(.power) {
                MetricTileView(model: services.power.tileModel)
                    .tileButton { detailSelection = .power }
            }
            if settings.isVisible(.thermal) {
                MetricTileView(model: services.thermal.tileModel)
                    .tileButton { detailSelection = .thermal }
            }
            if settings.isVisible(.fan) {
                MetricTileView(model: services.fan.tileModel)
                    .tileButton { detailSelection = .fan }
            }
            if settings.isVisible(.battery) {
                MetricTileView(model: services.battery.tileModel)
                    .tileButton { detailSelection = .battery }
            }
            if settings.isVisible(.wireless) {
                MetricTileView(model: services.wireless.tileModel)
                    .tileButton { detailSelection = .wireless }
            }
        }
        .background(Color.dashboardBackground.ignoresSafeArea())
        .background(TitlebarConfigurator(
            onSettingsTapped: { isSettingsVisible.toggle() },
            isSettingsVisible: $isSettingsVisible,
            settings: settings
        ))
        .background(
            WindowHeightSizer(contentHeight: contentHeight)
        )
    }

    // MARK: - Detail overlay

    @ViewBuilder private var detailOverlay: some View {
        Color.black.opacity(DashboardDesign.Opacity.modalScrim)
            .ignoresSafeArea()
            .onTapGesture { closeDetail() }
        if let detailModel {
            MetricDetailView(model: detailModel, onDismiss: closeDetail)
                .frame(minWidth: 420, maxWidth: 560)
                .padding(44)
                .transition(.scale(scale: 0.94, anchor: .center).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private var detailModel: DetailModel? {
        switch detailSelection {
        case .cpu: services.cpu.detailModel
        case .gpu: services.gpu.detailModel
        case .memory: services.memory.detailModel
        case .network: services.network.detailModel
        case .disk: services.disk.detailModel
        case .ane: services.accelerator.detailModel
        case .mediaEngine: services.mediaEngine.detailModel
        case .power: services.power.detailModel
        case .thermal: services.thermal.detailModel
        case .fan: services.fan.detailModel
        case .battery: services.battery.detailModel
        case .wireless: services.wireless.detailModel
        case nil: nil
        }
    }

    private func closeDetail() {
        withAnimation(DashboardDesign.Animation.detailDismiss) {
            detailSelection = nil
        }
    }

    @MainActor
    private func updateContentHeight(_ height: CGFloat) {
        let rounded = height.rounded(.up)
        guard rounded > 0, abs(contentHeight - rounded) > 0.5 else { return }
        contentHeight = rounded
    }
}

#Preview {
    let services = ServiceContainer()
    return DashboardView(services: services)
}
