import SwiftUI

/// Compact metrics popover displayed via the menu-bar extra.
struct MenuBarMetricsView: View {
    let cpuViewModel: CPUViewModel
    let gpuViewModel: GPUViewModel
    let memoryViewModel: MemoryViewModel
    let networkViewModel: NetworkViewModel
    let diskViewModel: DiskViewModel
    let acceleratorViewModel: AcceleratorViewModel

    /// Called when the user taps "Open Dashboard". Injected by the caller to keep AppKit
    /// side-effects out of this SwiftUI view.
    let openDashboard: () -> Void
    /// Called when the user taps "Quit". Injected by the caller.
    let quit: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            systemGroup
            groupSeparator
            networkGroup
            groupSeparator
            storageGroup
            Divider().padding(.top, 4)
            footer
        }
        .frame(width: 260)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge")
                .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("Performance")
                .font(.system(size: DashboardDesign.FontSize.tileControl, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, DashboardDesign.Spacing.medium)
        .padding(.top, DashboardDesign.Spacing.regular)
        .padding(.bottom, DashboardDesign.Spacing.xSmall)
    }

    // MARK: - Metric groups

    private var systemGroup: some View {
        Group {
            MetricRow(icon: "cpu", tint: .blue, label: "CPU",
                      value: cpuViewModel.tileModel.value, level: cpuViewModel.tileModel.thresholdLevel)
            MetricRow(icon: "display", tint: .purple, label: "GPU",
                      value: gpuViewModel.tileModel.value, level: gpuViewModel.tileModel.thresholdLevel)
            MetricRow(icon: "memorychip", tint: .indigo, label: "Memory",
                      value: memoryViewModel.tileModel.value, level: memoryViewModel.tileModel.thresholdLevel)
        }
    }

    private var networkGroup: some View {
        Group {
            MetricRow(icon: "arrow.down.circle.fill", tint: .teal, label: "Net In",
                      value: networkViewModel.inTileModel.value, level: .normal)
            MetricRow(icon: "arrow.up.circle.fill", tint: .cyan, label: "Net Out",
                      value: networkViewModel.outTileModel.value, level: .normal)
        }
    }

    private var storageGroup: some View {
        Group {
            MetricRow(icon: "internaldrive", tint: .orange, label: "Disk",
                      value: diskViewModel.tileModel.value, level: diskViewModel.tileModel.thresholdLevel)
            #if arch(arm64)
            MetricRow(icon: "brain", tint: .mint, label: "ANE",
                      value: acceleratorViewModel.tileModel.value, level: acceleratorViewModel.tileModel.thresholdLevel)
            #endif
        }
    }

    private var groupSeparator: some View {
        Color.primary.opacity(DashboardDesign.Opacity.popoverDivider)
            .frame(height: 1)
            .padding(.horizontal, DashboardDesign.Spacing.medium)
            .padding(.vertical, 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Open Dashboard") {
                openWindow(id: "main")
                openDashboard()
            }
            .buttonStyle(PopoverButtonStyle())
            Spacer()
            Button("Quit") { quit() }
                .buttonStyle(PopoverButtonStyle(isDestructive: true))
        }
        .padding(.horizontal, DashboardDesign.Spacing.compact)
        .padding(.vertical, 7)
    }
}

// MARK: - Metric Row

private struct MetricRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    let level: ThresholdLevel

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DashboardDesign.Spacing.compact) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: DashboardDesign.FontSize.tileControl, weight: .medium))
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.system(size: DashboardDesign.FontSize.tileBody))
                .foregroundStyle(.primary)
            Spacer()
            Text(verbatim: value)
                .font(.system(size: DashboardDesign.FontSize.tileBody).monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, DashboardDesign.Spacing.compact)
        .padding(.vertical, DashboardDesign.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isHovered ? DashboardDesign.Opacity.tileChrome : 0))
                .padding(.horizontal, 4)
        )
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var valueColor: Color {
        switch level {
        case .warning:  return .orange
        case .critical: return .red
        default:        return .primary
        }
    }
}

// MARK: - Button Style

private struct PopoverButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PopoverButtonBody(configuration: configuration, isDestructive: isDestructive)
    }

    private struct PopoverButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let isDestructive: Bool
        @State private var isHovered = false

        private var tint: Color { isDestructive ? .red : .accentColor }
        private var fillOpacity: Double {
            if configuration.isPressed { return 0.18 }
            return isHovered ? 0.10 : 0
        }

        var body: some View {
            configuration.label
                .font(.system(size: DashboardDesign.FontSize.tileControl, weight: .medium))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(tint.opacity(fillOpacity)))
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isHovered)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}
