import SwiftUI

// Individual tile views for each metric.
//
// Each type alias preserves SwiftUI's per-tile `@Observable` dependency tracking:
// only the tile whose view model changes re-renders, leaving all others untouched.
// `MonitorTileView` is the single generic implementation; all concrete tile names
// are aliases so call-sites in `DashboardView` remain unchanged.

// MARK: - Generic tile wrapper

/// Renders a `MetricTileView` for any view model conforming to `MetricTilePresenting`.
struct MonitorTileView<VM: MetricTilePresenting>: View {
    let viewModel: VM
    var body: some View {
        MetricTileView(
            title: viewModel.tileTitle,
            value: viewModel.tileValue,
            gaugeValue: viewModel.tileGaugeValue,
            history: viewModel.tileHistory,
            thresholdLevel: viewModel.tileThresholdLevel,
            subtitle: viewModel.tileSubtitle,
            systemImage: viewModel.tileSystemImage
        )
    }
}

// MARK: - Concrete tile type aliases

typealias CPUTileView      = MonitorTileView<CPUViewModel>
typealias GPUTileView      = MonitorTileView<GPUViewModel>
typealias MemoryTileView   = MonitorTileView<MemoryViewModel>
typealias DiskTileView     = MonitorTileView<DiskViewModel>
typealias PowerTileView    = MonitorTileView<PowerViewModel>
typealias ThermalTileView  = MonitorTileView<ThermalViewModel>
typealias FanTileView      = MonitorTileView<FanViewModel>
typealias BatteryTileView  = MonitorTileView<BatteryViewModel>
typealias WirelessTileView = MonitorTileView<WirelessViewModel>

#if arch(arm64)
typealias ANETileView         = MonitorTileView<AcceleratorViewModel>
typealias MediaEngineTileView = MonitorTileView<MediaEngineViewModel>
#endif

// MARK: - Network tiles (two distinct tiles from one view model)

struct NetworkInTileView: View {
    let viewModel: NetworkViewModel
    var body: some View {
        MetricTileView(
            title: "Net In", value: viewModel.inLabel,
            gaugeValue: viewModel.inGauge, history: viewModel.historyInGauge,
            thresholdLevel: viewModel.thresholdLevel, systemImage: "arrow.down.circle"
        )
    }
}

struct NetworkOutTileView: View {
    let viewModel: NetworkViewModel
    var body: some View {
        MetricTileView(
            title: "Net Out", value: viewModel.outLabel,
            gaugeValue: viewModel.outGauge, history: viewModel.historyOutGauge,
            thresholdLevel: viewModel.thresholdLevel, systemImage: "arrow.up.circle"
        )
    }
}
