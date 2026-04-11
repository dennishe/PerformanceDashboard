import SwiftUI

struct BatteryTileView: View {
    let viewModel: BatteryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if viewModel.snapshot.isPresent {
                primarySummary
                    .padding(.top, DashboardDesign.Spacing.compact)

                Spacer(minLength: DashboardDesign.Spacing.medium)

                accessoryDock(isProminent: false, showsContainer: true)
            } else {
                accessoryHero
                    .padding(.top, DashboardDesign.Spacing.medium)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: MetricTileLayoutMetrics.contentHeight, alignment: .top)
        .padding(MetricTileLayoutMetrics.padding)
        .tileCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery")
    }
}

private extension BatteryTileView {
    var accessoryRows: [BatteryTileGaugeRow] {
        if viewModel.snapshot.isPresent {
            return Array(viewModel.visibleTileGaugeRows.dropFirst())
        }

        return viewModel.visibleTileGaugeRows
    }

    var hiddenAccessoryCount: Int {
        max(0, viewModel.connectedDeviceBatteries.count - accessoryRows.count)
    }

    var header: some View {
        HStack(spacing: DashboardDesign.Spacing.small) {
            Image(systemName: "battery.100")
                .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("BATTERY")
                .font(.system(size: DashboardDesign.FontSize.tileCaption, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: DashboardDesign.Spacing.small)

            if viewModel.snapshot.isPresent {
                Text(verbatim: viewModel.chargeLabel)
                    .font(
                        .system(size: DashboardDesign.FontSize.tileBody, weight: .semibold)
                            .monospacedDigit()
                    )
                    .foregroundStyle(Color.threshold(viewModel.thresholdLevel))
                    .contentTransition(.numericText())
            }
        }
    }

    var primarySummary: some View {
        HStack(alignment: .center, spacing: DashboardDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THIS MAC")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)

                Text(verbatim: viewModel.chargeLabel)
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.threshold(viewModel.thresholdLevel))
                    .contentTransition(.numericText())

                if let status = viewModel.statusLabel {
                    Text(verbatim: status)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            BatteryPrimaryMeter(
                fraction: viewModel.gaugeValue ?? 0,
                thresholdLevel: viewModel.thresholdLevel
            )
        }
    }

    var accessoryHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            BatteryAccessorySectionHeader(
                title: "ACCESSORY POWER",
                connectedCount: viewModel.connectedDeviceBatteries.count,
                fontSize: 10,
                countFontSize: 10
            )

            accessoryContent(isProminent: true, spacing: 9)
            hiddenAccessorySummary(topPadding: 2)
        }
    }

    func accessoryDock(isProminent: Bool, showsContainer: Bool) -> some View {
        VStack(alignment: .leading, spacing: isProminent ? 8 : 7) {
            BatteryAccessorySectionHeader(
                title: viewModel.snapshot.isPresent ? "ACCESSORIES" : "ACCESSORY POWER",
                connectedCount: viewModel.connectedDeviceBatteries.count,
                fontSize: 9,
                countFontSize: 9
            )

            accessoryContent(isProminent: isProminent, spacing: isProminent ? 7 : 6)
            hiddenAccessorySummary(topPadding: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DashboardDesign.Spacing.compact)
        .padding(.top, isProminent ? DashboardDesign.Spacing.compact : 9)
        .padding(.bottom, isProminent ? DashboardDesign.Spacing.compact : 8)
        .background {
            if showsContainer {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(isProminent ? 0.045 : 0.028),
                                Color.primary.opacity(0.012)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    }
            }
        }
    }

    var accessoryEmptyMessage: String {
        if viewModel.isLoadingConnectedDeviceBatteries {
            return "Loading batteries..."
        }

        return viewModel.snapshot.isPresent
            ? "No connected accessory batteries"
            : "No accessory batteries available"
    }

    @ViewBuilder
    func accessoryContent(isProminent: Bool, spacing: CGFloat) -> some View {
        if accessoryRows.isEmpty {
            BatteryAccessoryEmptyStateView(
                message: accessoryEmptyMessage,
                isProminent: isProminent
            )
            .padding(.top, isProminent ? DashboardDesign.Spacing.small : 0)
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(accessoryRows) { row in
                    BatteryAccessoryDockRowView(row: row, isProminent: isProminent)
                }
            }
            .padding(.top, isProminent ? 2 : 0)
        }
    }

    @ViewBuilder
    func hiddenAccessorySummary(topPadding: CGFloat) -> some View {
        if hiddenAccessoryCount > 0 {
            Text(verbatim: "+\(hiddenAccessoryCount) more connected")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, topPadding)
        }
    }
}
