import SwiftUI

// MARK: - Network tile (combined ↓ / ↑ in one tile)

/// Single network tile that shows both download and upload throughput.
/// Uses `NetworkViewModel.tileModel` for the ring gauge and sparkline,
/// and overlays separate ↓/↑ labels with direction-coded colours.
struct NetworkTileView: View {
    let viewModel: NetworkViewModel

    private var color: Color { .threshold(viewModel.tileModel.thresholdLevel) }
    private var layerColor: LayerColorComponents { .threshold(viewModel.tileModel.thresholdLevel) }

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.xSmall) {
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
        .tileCard()
    }

    private var tileHeader: some View {
        HStack(alignment: .center, spacing: DashboardDesign.Spacing.small) {
            Image(systemName: "network")
                .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .semibold))
                .foregroundStyle(color)
            Text("NETWORK")
                .font(.system(size: DashboardDesign.FontSize.tileCaption, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer(minLength: 0)
            RingGaugeView(
                value: viewModel.tileModel.gaugeValue ?? 0,
                color: layerColor,
                accessibilityLabel: "Network gauge",
                accessibilityValue: viewModel.tileModel.value
            )
            .frame(
                width: MetricTileLayoutMetrics.ringGaugeSize,
                height: MetricTileLayoutMetrics.ringGaugeSize
            )
        }
    }

    private func directionRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: DashboardDesign.Spacing.xSmall) {
            Text(label)
                .font(.system(size: DashboardDesign.FontSize.tileBody, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14, alignment: .leading)
            Text(verbatim: value)
                .font(
                    .system(size: DashboardDesign.FontSize.tileBody, weight: .regular, design: .rounded)
                        .monospacedDigit()
                )
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label == "↓" ? "Download" : "Upload")
        .accessibilityValue(value)
    }
}
