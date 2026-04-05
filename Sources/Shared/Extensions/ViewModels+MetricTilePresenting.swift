// Maps each view model to the `MetricTilePresenting` protocol so the generic
// `MonitorTileView` in the dashboard can render any metric tile uniformly.

// MARK: - CPU

extension CPUViewModel: MetricTilePresenting {}

// MARK: - GPU

extension GPUViewModel: MetricTilePresenting {}

// MARK: - Memory

extension MemoryViewModel: MetricTilePresenting {}

// MARK: - Disk

extension DiskViewModel: MetricTilePresenting {}

// MARK: - Power

extension PowerViewModel: MetricTilePresenting {}

// MARK: - Thermal

extension ThermalViewModel: MetricTilePresenting {}

// MARK: - Fan

extension FanViewModel: MetricTilePresenting {}

// MARK: - Battery

extension BatteryViewModel: MetricTilePresenting {}

// MARK: - Wireless

extension WirelessViewModel: MetricTilePresenting {}

// MARK: - Accelerator / Media Engine (Apple Silicon only)

#if arch(arm64)
extension AcceleratorViewModel: MetricTilePresenting {}

extension MediaEngineViewModel: MetricTilePresenting {}
#endif
