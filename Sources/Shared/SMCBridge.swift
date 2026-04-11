import IOKit

protocol SMCReading: AnyObject {
    func readBytes(key: String) -> (dataType: UInt32, bytes: [UInt8])?
}

/// Thin wrapper around the AppleSMC IOKit driver.
/// Create one instance per service; call `close()` (or rely on `deinit`) to release.
/// All reads are synchronous — call on `@MonitorActor`.
final class SMCBridge: SMCReading {
    private var connection: io_connect_t = IO_OBJECT_NULL

    init?() {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            return nil
        }
    }

    deinit { close() }

    func close() {
        guard connection != IO_OBJECT_NULL else { return }
        IOServiceClose(connection)
        connection = IO_OBJECT_NULL
    }

    // MARK: - Key reading

    /// Returns `(dataType, rawBytes)` for a 4-char SMC key, or `nil` if absent / error.
    func readBytes(key: String) -> (dataType: UInt32, bytes: [UInt8])? {
        guard let keyCode = SMCBridge.fourCC(key) else { return nil }

        // Phase 1 — kSMCGetKeyInfo: learn dataType and dataSize
        var msg = SMCMessage()
        msg.key = keyCode
        msg.data8 = 9 // kSMCGetKeyInfo
        guard call(&msg) == kIOReturnSuccess, msg.result == 0 else { return nil }
        let size = msg.keyInfoDataSize
        let type = msg.keyInfoDataType

        // Phase 2 — kSMCReadKey: read the raw value bytes
        msg = SMCMessage()
        msg.key = keyCode
        msg.keyInfoDataSize = size
        msg.data8 = 5 // kSMCReadKey
        guard call(&msg) == kIOReturnSuccess, msg.result == 0 else { return nil }
        return (type, msg.rawBytes(count: Int(size)))
    }

    // MARK: - Decoders

    /// `sp78`: signed 7.8 fixed-point (temperatures in °C, power in W).
    static func sp78(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        return Double(raw) / 256.0
    }

    /// `fpe2`: unsigned 14.2 fixed-point (fan RPM, older Macs).
    static func fpe2(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
    }

    /// `flt`: IEEE 754 single-precision float, little-endian (Apple Silicon Macs).
    static func flt(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        return Double(Float(bitPattern: bits))
    }

    /// `ui8`: unsigned 8-bit integer (fan count, etc.).
    static func ui8(_ bytes: [UInt8]) -> Int? {
        bytes.first.map { Int($0) }
    }

    /// Decodes a numeric SMC reading, dispatching on the stored data type.
    /// Handles `sp78` (signed 7.8 fixed-point) and `flt` (IEEE 754 single, LE).
    /// Falls back to `fpe2` (unsigned 14.2, fan RPM on older hardware).
    static func decodeFloat(_ result: (dataType: UInt32, bytes: [UInt8])) -> Double? {
        let sp78Type = fourCC("sp78") ?? 0
        let fltType  = fourCC("flt ") ?? 0
        let fpe2Type = fourCC("fpe2") ?? 0
        switch result.dataType {
        case sp78Type: return sp78(result.bytes)
        case fltType:  return flt(result.bytes)
        case fpe2Type: return fpe2(result.bytes)
        default:       return nil
        }
    }

    // MARK: - Private

    /// Packs a 4-char ASCII string into a big-endian `UInt32` SMC key code.
    /// Returns 0 if `str` is not exactly 4 ASCII characters; `nil` if used
    /// as a failable instance variant (delegates to the static form).
    static func fourCC(_ str: String) -> UInt32? {
        let scalars = Array(str.unicodeScalars)
        guard scalars.count == 4, scalars.allSatisfy({ $0.value < 128 }) else { return nil }
        return scalars.enumerated().reduce(UInt32(0)) { acc, pair in
            acc | (UInt32(pair.element.value) << UInt32((3 - pair.offset) * 8))
        }
    }

    private func call(_ message: inout SMCMessage) -> IOReturn {
        let input = message // immutable copy for the input pointer
        var outSize = MemoryLayout<SMCMessage>.stride
        return withUnsafeBytes(of: input) { inPtr in
            withUnsafeMutableBytes(of: &message) { outPtr in
                IOConnectCallStructMethod(
                    connection, UInt32(2), // KERNEL_INDEX_SMC = 2
                    inPtr.baseAddress, MemoryLayout<SMCMessage>.stride,
                    outPtr.baseAddress, &outSize
                )
            }
        }
    }
}

// MARK: - SMCMessage

/// 80-byte flat struct matching the C layout of `SMCParamStruct` in the AppleSMC kext.
/// Every field is at its natural-alignment boundary, so Swift inserts no extra padding.
private struct SMCMessage {
    var key: UInt32 = 0              // [0–3]
    var versMajor: UInt8 = 0         // [4]
    var versMinor: UInt8 = 0         // [5]
    var versBuild: UInt8 = 0         // [6]
    var versReserved: UInt8 = 0      // [7]
    var versRelease: UInt16 = 0      // [8–9]
    var pad10: UInt16 = 0            // [10–11]  mirrors C auto-pad before pLimitData
    var pLimitVersion: UInt16 = 0    // [12–13]
    var pLimitLength: UInt16 = 0     // [14–15]
    var pLimitCPU: UInt32 = 0        // [16–19]
    var pLimitGPU: UInt32 = 0        // [20–23]
    var pLimitMem: UInt32 = 0        // [24–27]
    var keyInfoDataSize: UInt32 = 0  // [28–31]
    var keyInfoDataType: UInt32 = 0  // [32–35]
    var keyInfoAttr: UInt8 = 0       // [36]
    var pad37: UInt8 = 0             // [37]  keyInfo tail pad
    var pad38: UInt16 = 0            // [38–39]  "
    var result: UInt8 = 0            // [40]
    var status: UInt8 = 0            // [41]
    var data8: UInt8 = 0             // [42]
    var pad43: UInt8 = 0             // [43]  aligns data32 to offset 44
    var data32: UInt32 = 0           // [44–47]
    // swiftlint:disable:next large_tuple
    var bytes: (                     // [48–79]
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )

    func rawBytes(count: Int) -> [UInt8] {
        withUnsafeBytes(of: self) { ptr in
            Array(ptr[48..<min(80, 48 + count)])
        }
    }
}
