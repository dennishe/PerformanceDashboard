// Maps each view model to the `MetricTilePresenting` protocol so the generic
// `MonitorTileView` in the dashboard can render any metric tile uniformly.

// MARK: - CPU

extension CPUViewModel: MetricTilePresenting {
    public var tileTitle: String { "CPU" }
    public var tileValue: String { usageLabel }
    public var tileGaugeValue: Double? { usage }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { nil }
    public var tileSystemImage: String { "cpu" }
}

// MARK: - GPU

extension GPUViewModel: MetricTilePresenting {
    public var tileTitle: String { "GPU" }
    public var tileValue: String { usageLabel }
    public var tileGaugeValue: Double? { usage }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { nil }
    public var tileSystemImage: String { "display" }
}

// MARK: - Memory

extension MemoryViewModel: MetricTilePresenting {
    public var tileTitle: String { "Memory" }
    public var tileValue: String { usageLabel }
    public var tileGaugeValue: Double? { usage }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { "\(usedLabel) / \(totalLabel)" }
    public var tileSystemImage: String { "memorychip" }
}

// MARK: - Disk

extension DiskViewModel: MetricTilePresenting {
    public var tileTitle: String { "Disk" }
    public var tileValue: String { usageLabel }
    public var tileGaugeValue: Double? { usage }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { availableLabel + " free" }
    public var tileSystemImage: String { "internaldrive" }
}

// MARK: - Power

extension PowerViewModel: MetricTilePresenting {
    public var tileTitle: String { "Power" }
    public var tileValue: String { wattsLabel }
    public var tileGaugeValue: Double? { gaugeValue }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { nil }
    public var tileSystemImage: String { "bolt" }
}

// MARK: - Thermal

extension ThermalViewModel: MetricTilePresenting {
    public var tileTitle: String { "Temp" }
    public var tileValue: String { cpuLabel }
    public var tileGaugeValue: Double? { gaugeValue }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { gpuLabel }
    public var tileSystemImage: String { "thermometer.medium" }
}

// MARK: - Fan

extension FanViewModel: MetricTilePresenting {
    public var tileTitle: String { "Fans" }
    public var tileValue: String { primaryLabel }
    public var tileGaugeValue: Double? { gaugeValue }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { subtitle }
    public var tileSystemImage: String { "fan" }
}

// MARK: - Battery

extension BatteryViewModel: MetricTilePresenting {
    public var tileTitle: String { "Battery" }
    public var tileValue: String { chargeLabel }
    public var tileGaugeValue: Double? { gaugeValue }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { statusLabel }
    public var tileSystemImage: String { "battery.100" }
}

// MARK: - Wireless

extension WirelessViewModel: MetricTilePresenting {
    public var tileTitle: String { "Wireless" }
    public var tileValue: String { signalLabel }
    public var tileGaugeValue: Double? { gaugeValue }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { bluetoothLabel }
    public var tileSystemImage: String { "wifi" }
}

// MARK: - Accelerator / Media Engine (Apple Silicon only)

#if arch(arm64)
extension AcceleratorViewModel: MetricTilePresenting {
    public var tileTitle: String { "ANE" }
    public var tileValue: String { usageLabel }
    public var tileGaugeValue: Double? { aneUsage }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { nil }
    public var tileSystemImage: String { "brain" }
}

extension MediaEngineViewModel: MetricTilePresenting {
    public var tileTitle: String { "Media Engine" }
    public var tileValue: String { combinedLabel }
    public var tileGaugeValue: Double? { gaugeValue }
    public var tileHistory: [Double] { history }
    public var tileThresholdLevel: ThresholdLevel { thresholdLevel }
    public var tileSubtitle: String? { decodeLabel }
    public var tileSystemImage: String { "film.stack" }
}
#endif
