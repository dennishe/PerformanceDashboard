#if !arch(arm64)
import Foundation

/// Reads total system power from the `PSTR` SMC key (Intel Macs only).
struct IntelSMCPowerStrategy: PowerStrategy {
    private let bridge: SMCBridge?

    init() {
        bridge = SMCBridge()
    }

    mutating func nextWatts() -> Double? {
        guard let result = bridge?.readBytes(key: "PSTR") else { return nil }
        guard let watts = SMCBridge.sp78(result.bytes), watts > 0 else { return nil }
        return watts
    }
}
#endif
