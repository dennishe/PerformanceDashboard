#if arch(arm64)
import Foundation

/// Abstracts the IOReport PMP sampler so `AcceleratorMonitorService` and
/// `MediaEngineMonitorService` can be tested without real IOReport hardware.
@MonitorActor
protocol PMPSamplerProtocol: AnyObject {
    /// Must be called once before `nextDelta()` is used. Idempotent.
    func setUp()

    /// Returns the current energy-counter delta dictionary, or `nil` when unavailable.
    func nextDelta() -> CFDictionary?
}

// Make the concrete singleton conform.
extension PMPSampler: PMPSamplerProtocol {}
#endif
