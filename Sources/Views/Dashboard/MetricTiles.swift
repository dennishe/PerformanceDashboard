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
        MetricTileView(model: viewModel.tileModel)
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

// MARK: - Network tile (combined ↓ / ↑ in one tile)

/// Single network tile that shows both download and upload throughput.
/// Uses `NetworkViewModel.tileModel` for the ring gauge and sparkline,
/// and overlays separate ↓/↑ labels with direction-coded colours.
struct NetworkTileView: View {
    let viewModel: NetworkViewModel

    private var color: Color { .threshold(viewModel.tileModel.thresholdLevel) }
    private var layerColor: LayerColorComponents { .threshold(viewModel.tileModel.thresholdLevel) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            tileHeader
            directionRow(label: "↓", value: viewModel.inLabel, color: .green)
            directionRow(label: "↑", value: viewModel.outLabel, color: .blue)
            Spacer(minLength: 0)
            ZStack {
                SparklineView(
                    history: viewModel.historyInGauge,
                    color: .normal,
                    accessibilityLabel: "Download history",
                    accessibilityValue: viewModel.inLabel
                )
                SparklineView(
                    history: viewModel.historyOutGauge,
                    color: .blue,
                    showFill: false,
                    accessibilityLabel: "Upload history",
                    accessibilityValue: viewModel.outLabel
                )
            }
            .frame(height: SparklineGeometry.displayHeight)
        }
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .background {
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .fill(Color.tileSurface)
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            RoundedRectangle(cornerRadius: MetricTileLayoutMetrics.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var tileHeader: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: "network")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text("NETWORK")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer(minLength: 0)
            RingGaugeView(
                value: viewModel.tileModel.gaugeValue ?? 0,
                color: layerColor,
                accessibilityLabel: "Network gauge",
                accessibilityValue: viewModel.tileModel.value
            )
            .frame(width: 34, height: 34)
        }
    }

    private func directionRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14, alignment: .leading)
            Text(verbatim: value)
                .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label == "↓" ? "Download" : "Upload")
        .accessibilityValue(value)
    }
}
