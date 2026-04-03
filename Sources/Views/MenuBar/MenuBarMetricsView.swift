import SwiftUI

/// Compact metrics popover displayed via the menu-bar extra.
struct MenuBarMetricsView: View {
    let cpuViewModel: CPUViewModel
    let gpuViewModel: GPUViewModel
    let memoryViewModel: MemoryViewModel
    let networkViewModel: NetworkViewModel
    let diskViewModel: DiskViewModel
    let acceleratorViewModel: AcceleratorViewModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            metricRows
            Divider()
            actionBar
        }
        .frame(width: 240)
    }

    // MARK: - Sections

    private var sectionHeader: some View {
        HStack {
            Text("PERFORMANCE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(1.0)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var metricRows: some View {
        metricRow("cpu", "CPU", cpuViewModel.usageLabel)
        Divider().padding(.leading, 40)
        metricRow("display", "GPU", gpuViewModel.usageLabel)
        Divider().padding(.leading, 40)
        metricRow("memorychip", "Memory", memoryViewModel.usageLabel)
        Divider().padding(.leading, 40)
        metricRow("arrow.down.circle", "Net In", networkViewModel.inLabel)
        Divider().padding(.leading, 40)
        metricRow("arrow.up.circle", "Net Out", networkViewModel.outLabel)
        Divider().padding(.leading, 40)
        metricRow("internaldrive", "Disk", diskViewModel.usageLabel)
        #if arch(arm64)
        Divider().padding(.leading, 40)
        metricRow("brain", "ANE", acceleratorViewModel.usageLabel)
        #endif
    }

    private var actionBar: some View {
        HStack {
            Button("Open Dashboard") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Row builder

    private func metricRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
