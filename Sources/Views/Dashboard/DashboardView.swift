import SwiftUI
import AppKit

private enum DashboardDetailSelection: Hashable {
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
        .task(id: detailSelection) {
            guard detailSelection == .battery else { return }
            await services.battery.refreshConnectedDeviceBatteries()
        }
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        DashboardLayout(
            spacing: 12,
            minTileWidth: settings.densityPreset.minTileWidth,
            onContentHeightChange: updateContentHeight
        ) {
            if settings.isVisible(.cpu) {
                ObservedMetricTileButton(
                    modelProvider: { services.cpu.tileModel },
                    action: { detailSelection = .cpu }
                )
            }
            if settings.isVisible(.gpu) {
                ObservedMetricTileButton(
                    modelProvider: { services.gpu.tileModel },
                    action: { detailSelection = .gpu }
                )
            }
            if settings.isVisible(.memory) {
                ObservedMetricTileButton(
                    modelProvider: { services.memory.tileModel },
                    action: { detailSelection = .memory }
                )
            }
            if settings.isVisible(.network) {
                ObservedNetworkTileButton(
                    viewModel: services.network,
                    action: { detailSelection = .network }
                )
            }
            if settings.isVisible(.disk) {
                ObservedMetricTileButton(
                    modelProvider: { services.disk.tileModel },
                    action: { detailSelection = .disk }
                )
            }
            #if arch(arm64)
            if settings.isVisible(.ane) {
                ObservedMetricTileButton(
                    modelProvider: { services.accelerator.tileModel },
                    action: { detailSelection = .ane }
                )
            }
            if settings.isVisible(.mediaEngine) {
                ObservedMetricTileButton(
                    modelProvider: { services.mediaEngine.tileModel },
                    action: { detailSelection = .mediaEngine }
                )
            }
            #endif
            if settings.isVisible(.power) {
                ObservedMetricTileButton(
                    modelProvider: { services.power.tileModel },
                    action: { detailSelection = .power }
                )
            }
            if settings.isVisible(.thermal) {
                ObservedMetricTileButton(
                    modelProvider: { services.thermal.tileModel },
                    action: { detailSelection = .thermal }
                )
            }
            if settings.isVisible(.fan) {
                ObservedMetricTileButton(
                    modelProvider: { services.fan.tileModel },
                    action: { detailSelection = .fan }
                )
            }
            if settings.isVisible(.battery) {
                ObservedBatteryTileButton(
                    viewModel: services.battery,
                    action: { detailSelection = .battery }
                )
            }
            if settings.isVisible(.wireless) {
                ObservedMetricTileButton(
                    modelProvider: { services.wireless.tileModel },
                    action: { detailSelection = .wireless }
                )
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
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(DashboardDesign.Opacity.modalScrim)
                    .ignoresSafeArea()
                    .onTapGesture { closeDetail() }
                if let detailModel {
                    MetricDetailView(
                        model: detailModel,
                        availableHeight: max(0, proxy.size.height - 88),
                        onDismiss: closeDetail
                    )
                    .frame(minWidth: 420, maxWidth: 560)
                    .padding(44)
                    .transition(.scale(scale: 0.94, anchor: .center).combined(with: .opacity))
                }
            }
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
