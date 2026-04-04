import Foundation

/// Snapshot of CPU and GPU die temperatures.
public struct ThermalSnapshot: Sendable {
    /// CPU temperature in °C, or `nil` when unavailable.
    public let cpuCelsius: Double?
    /// GPU temperature in °C, or `nil` when unavailable.
    public let gpuCelsius: Double?
}

/// Reads CPU and GPU temperatures from the SMC.
///
/// CPU key priority:
/// - `TC0D` (Intel die diode)
/// - `Tp0D` (Apple Silicon representative die temp)
/// - `Tp01` (Apple Silicon P-core 0 fallback)
///
/// GPU key: `TG0D` (Intel/AMD discrete).
/// Apple Silicon GPU temperature is not reliably exposed in the SMC;
/// `gpuCelsius` will be `nil` on those machines.
public final class ThermalMonitorService: PollingMonitorBase<ThermalSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<ThermalSnapshot>.Continuation) async {
        let smc = SMCBridge()
        defer { smc?.close() }
        while !Task.isCancelled {
            continuation.yield(ThermalMonitorService.sample(smc))
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    // MARK: - Private sampling

    nonisolated static func sample(_ bridge: SMCBridge?) -> ThermalSnapshot {
        ThermalSnapshot(
            cpuCelsius: readCPU(bridge),
            gpuCelsius: readGPU(bridge)
        )
    }

    nonisolated private static func readCPU(_ bridge: SMCBridge?) -> Double? {
        // Priority order: Intel die → Apple Silicon die → Apple Silicon heat-exchanger fallback
        for key in ["TC0D", "Tp0D", "Tp01", "TH0x", "TH1x", "TH0a", "TW0P", "TCXC"] {
            if let result = bridge?.readBytes(key: key),
               let value = SMCBridge.decodeFloat(result),
               value > 0 {
                return value
            }
        }
        return nil
    }

    nonisolated private static func readGPU(_ bridge: SMCBridge?) -> Double? {
        for key in ["TG0D", "TG0P", "TGDD", "TG0x"] {
            if let result = bridge?.readBytes(key: key),
               let value = SMCBridge.decodeFloat(result),
               value > 0 {
                return value
            }
        }
        return nil
    }
}
