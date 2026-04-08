import Foundation

public struct LinearThreshold: ThresholdEvaluating {
    private let normalUpperBound: Double
    private let warningUpperBound: Double

    public init(normalUpperBound: Double, warningUpperBound: Double) {
        self.normalUpperBound = normalUpperBound
        self.warningUpperBound = warningUpperBound
    }

    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<normalUpperBound: return .normal
        case ..<warningUpperBound: return .warning
        default: return .critical
        }
    }
}

public struct InverseThreshold: ThresholdEvaluating {
    private let normalLowerBound: Double
    private let warningLowerBound: Double

    public init(normalLowerBound: Double, warningLowerBound: Double) {
        self.normalLowerBound = normalLowerBound
        self.warningLowerBound = warningLowerBound
    }

    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case normalLowerBound...: return .normal
        case warningLowerBound...: return .warning
        default: return .critical
        }
    }
}

private func linearThresholdLevel(
    _ value: Double,
    normalUpperBound: Double,
    warningUpperBound: Double
) -> ThresholdLevel {
    LinearThreshold(normalUpperBound: normalUpperBound, warningUpperBound: warningUpperBound)
        .level(for: value)
}

// MARK: - CPU

/// Threshold configuration for CPU utilisation.
public struct CPUThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.6, warningUpperBound: 0.85)
    }
}

// MARK: - GPU

/// Threshold configuration for GPU utilisation.
public struct GPUThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.6, warningUpperBound: 0.85)
    }
}

// MARK: - Memory

/// Threshold configuration for memory pressure.
public struct MemoryThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.7, warningUpperBound: 0.9)
    }
}

// MARK: - Network

/// Threshold configuration for network throughput (based on inbound bytes).
public struct NetworkThreshold: ThresholdEvaluating {
    /// Warn above 50 MB/s, critical above 100 MB/s.
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<50_000_000:  return .normal
        case ..<100_000_000: return .warning
        default:             return .critical
        }
    }
}

// MARK: - Disk

/// Threshold configuration for disk usage.
public struct DiskThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.75, warningUpperBound: 0.9)
    }
}

// MARK: - Accelerator (ANE)

/// Threshold configuration for ANE utilisation.
public struct AcceleratorThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.6, warningUpperBound: 0.85)
    }
}

// MARK: - Power

/// Threshold levels for power draw (normalised via adaptive maximum).
public struct PowerThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.6, warningUpperBound: 0.85)
    }
}

// MARK: - Fan

/// Threshold levels for fan speed usage.
public struct FanThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.7, warningUpperBound: 0.9)
    }
}

// MARK: - Thermal

/// Threshold levels for CPU temperature.
public struct ThermalThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.7, warningUpperBound: 0.85)
    }
}

// MARK: - Battery

/// Threshold levels for battery charge (inverted — low charge is critical).
public struct BatteryThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        InverseThreshold(normalLowerBound: 0.2, warningLowerBound: 0.1).level(for: value)
    }
}

// MARK: - Media Engine

/// Threshold levels for Media Engine combined load.
public struct MediaEngineThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        linearThresholdLevel(value, normalUpperBound: 0.6, warningUpperBound: 0.85)
    }
}

// MARK: - Wireless (Wi-Fi signal quality)

/// Threshold levels for Wi-Fi signal quality (higher = better).
public struct WirelessThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case 0.5...:  return .normal    // RSSI ≥ −65 dBm
        case 0.36...: return .warning   // RSSI ~ −72 dBm
        default:      return .critical  // Disconnected or very weak
        }
    }
}
