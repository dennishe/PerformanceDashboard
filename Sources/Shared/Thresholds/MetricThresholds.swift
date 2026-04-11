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

public enum MetricThresholds {
    private static let standard = LinearThreshold(normalUpperBound: 0.6, warningUpperBound: 0.85)
    private static let relaxed = LinearThreshold(normalUpperBound: 0.7, warningUpperBound: 0.9)

    public static let cpu: any ThresholdEvaluating = standard
    public static let gpu: any ThresholdEvaluating = standard
    public static let accelerator: any ThresholdEvaluating = standard
    public static let power: any ThresholdEvaluating = standard
    public static let mediaEngine: any ThresholdEvaluating = standard
    public static let memory: any ThresholdEvaluating = relaxed
    public static let fan: any ThresholdEvaluating = relaxed
    public static let thermal: any ThresholdEvaluating =
        LinearThreshold(normalUpperBound: 0.7, warningUpperBound: 0.85)
    public static let disk: any ThresholdEvaluating =
        LinearThreshold(normalUpperBound: 0.75, warningUpperBound: 0.9)
    public static let battery: any ThresholdEvaluating =
        InverseThreshold(normalLowerBound: 0.2, warningLowerBound: 0.1)
    public static let network: any ThresholdEvaluating = NetworkThreshold()
    public static let wireless: any ThresholdEvaluating = WirelessThreshold()
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
