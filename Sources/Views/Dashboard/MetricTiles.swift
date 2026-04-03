import SwiftUI

// Individual tile views for each metric.
//
// Wrapping each metric in its own `View` struct ensures SwiftUI's `@Observable`
// dependency tracking is scoped per-tile: only the tile whose view model changed
// re-renders, leaving all other tiles untouched.

// MARK: - CPU / GPU / Memory

struct CPUTileView: View {
    let viewModel: CPUViewModel
    var body: some View {
        MetricTileView(
            title: "CPU", value: viewModel.usageLabel,
            gaugeValue: viewModel.usage, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel, systemImage: "cpu"
        )
    }
}

struct GPUTileView: View {
    let viewModel: GPUViewModel
    var body: some View {
        MetricTileView(
            title: "GPU", value: viewModel.usageLabel,
            gaugeValue: viewModel.usage, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel, systemImage: "display"
        )
    }
}

struct MemoryTileView: View {
    let viewModel: MemoryViewModel
    var body: some View {
        MetricTileView(
            title: "Memory", value: viewModel.usageLabel,
            gaugeValue: viewModel.usage, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: "\(viewModel.usedLabel) / \(viewModel.totalLabel)",
            systemImage: "memorychip"
        )
    }
}

// MARK: - Network

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

// MARK: - Disk

struct DiskTileView: View {
    let viewModel: DiskViewModel
    var body: some View {
        MetricTileView(
            title: "Disk", value: viewModel.usageLabel,
            gaugeValue: viewModel.usage, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: viewModel.availableLabel + " free",
            systemImage: "internaldrive"
        )
    }
}

// MARK: - Accelerator (Apple Silicon only)

#if arch(arm64)
struct ANETileView: View {
    let viewModel: AcceleratorViewModel
    var body: some View {
        MetricTileView(
            title: "ANE", value: viewModel.usageLabel,
            gaugeValue: viewModel.aneUsage, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel, systemImage: "brain"
        )
    }
}

struct MediaEngineTileView: View {
    let viewModel: MediaEngineViewModel
    var body: some View {
        MetricTileView(
            title: "Media Engine", value: viewModel.combinedLabel,
            gaugeValue: viewModel.gaugeValue, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: viewModel.decodeLabel, systemImage: "film.stack"
        )
    }
}
#endif

// MARK: - Power / Thermal / Fan

struct PowerTileView: View {
    let viewModel: PowerViewModel
    var body: some View {
        MetricTileView(
            title: "Power", value: viewModel.wattsLabel,
            gaugeValue: viewModel.gaugeValue, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel, systemImage: "bolt"
        )
    }
}

struct ThermalTileView: View {
    let viewModel: ThermalViewModel
    var body: some View {
        MetricTileView(
            title: "Temp", value: viewModel.cpuLabel,
            gaugeValue: viewModel.gaugeValue, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: viewModel.gpuLabel, systemImage: "thermometer.medium"
        )
    }
}

struct FanTileView: View {
    let viewModel: FanViewModel
    var body: some View {
        MetricTileView(
            title: "Fans", value: viewModel.primaryLabel,
            gaugeValue: viewModel.gaugeValue, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: viewModel.subtitle, systemImage: "fan"
        )
    }
}

// MARK: - Battery / Wireless

struct BatteryTileView: View {
    let viewModel: BatteryViewModel
    var body: some View {
        MetricTileView(
            title: "Battery", value: viewModel.chargeLabel,
            gaugeValue: viewModel.gaugeValue, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: viewModel.statusLabel, systemImage: "battery.100"
        )
    }
}

struct WirelessTileView: View {
    let viewModel: WirelessViewModel
    var body: some View {
        MetricTileView(
            title: "Wireless", value: viewModel.signalLabel,
            gaugeValue: viewModel.gaugeValue, history: viewModel.history,
            thresholdLevel: viewModel.thresholdLevel,
            subtitle: viewModel.bluetoothLabel, systemImage: "wifi"
        )
    }
}
