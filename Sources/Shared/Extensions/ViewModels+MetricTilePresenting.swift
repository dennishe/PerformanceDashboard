// Maps each view model to the `MetricTilePresenting` protocol so the generic
// `MonitorTileView` in the dashboard can render any metric tile uniformly.
// Also declares `DetailPresenting` conformances for all view models.

// MARK: - CPU

extension CPUViewModel: MetricTilePresenting {}
extension CPUViewModel: DetailPresenting {}

// MARK: - GPU

extension GPUViewModel: MetricTilePresenting {}
extension GPUViewModel: DetailPresenting {}

// MARK: - Memory

extension MemoryViewModel: MetricTilePresenting {}
extension MemoryViewModel: DetailPresenting {}

// MARK: - Network

extension NetworkViewModel: MetricTilePresenting {}
extension NetworkViewModel: DetailPresenting {}

// MARK: - Disk

extension DiskViewModel: MetricTilePresenting {}
extension DiskViewModel: DetailPresenting {}

// MARK: - Power

extension PowerViewModel: MetricTilePresenting {}
extension PowerViewModel: DetailPresenting {}

// MARK: - Thermal

extension ThermalViewModel: MetricTilePresenting {}
extension ThermalViewModel: DetailPresenting {}

// MARK: - Fan

extension FanViewModel: MetricTilePresenting {}
extension FanViewModel: DetailPresenting {}

// MARK: - Battery

extension BatteryViewModel: MetricTilePresenting {}
extension BatteryViewModel: DetailPresenting {}

// MARK: - Wireless

extension WirelessViewModel: MetricTilePresenting {}
extension WirelessViewModel: DetailPresenting {}

// MARK: - Accelerator / Media Engine (Apple Silicon only)

#if arch(arm64)
extension AcceleratorViewModel: MetricTilePresenting {}
extension AcceleratorViewModel: DetailPresenting {}

extension MediaEngineViewModel: MetricTilePresenting {}
extension MediaEngineViewModel: DetailPresenting {}
#endif
