import Foundation

// MARK: - CPU

/// Threshold configuration for CPU utilisation.
public struct CPUThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

// MARK: - GPU

/// Threshold configuration for GPU utilisation.
public struct GPUThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

// MARK: - Memory

/// Threshold configuration for memory pressure.
public struct MemoryThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.7:  return .normal
        case ..<0.9:  return .warning
        default:      return .critical
        }
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
        switch value {
        case ..<0.75: return .normal
        case ..<0.9:  return .warning
        default:      return .critical
        }
    }
}

// MARK: - Accelerator (ANE)

/// Threshold configuration for ANE utilisation.
public struct AcceleratorThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

// MARK: - Power

/// Threshold levels for power draw (normalised via adaptive maximum).
public struct PowerThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

// MARK: - Fan

/// Threshold levels for fan speed usage.
public struct FanThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.7:  return .normal
        case ..<0.9:  return .warning
        default:      return .critical
        }
    }
}

// MARK: - Thermal

/// Threshold levels for CPU temperature.
public struct ThermalThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.7:  return .normal   // < ~70 °C normalised to 100 °C max
        case ..<0.85: return .warning
        default:      return .critical
        }
    }
}

// MARK: - Battery

/// Threshold levels for battery charge (inverted — low charge is critical).
public struct BatteryThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case 0.2...: return .normal
        case 0.1...: return .warning
        default:     return .critical
        }
    }
}

// MARK: - Media Engine

/// Threshold levels for Media Engine combined load.
public struct MediaEngineThreshold: ThresholdEvaluating {
    public func level(for value: Double) -> ThresholdLevel {
        switch value {
        case ..<0.6:  return .normal
        case ..<0.85: return .warning
        default:      return .critical
        }
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
