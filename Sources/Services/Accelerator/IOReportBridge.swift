#if arch(arm64)
import Darwin
import Foundation

/// Opaque reference to an active IOReport subscription.
typealias IOReportSubscriptionRef = OpaquePointer

/// Namespace for dynamically resolved symbols from the private IOReport.framework.
///
/// All symbols are resolved lazily via `dlsym`. Every function returns its natural
/// nil-or-zero failure value if the framework or symbol is unavailable.
enum IOReport {

    // MARK: – Private framework handle

    // nonisolated(unsafe): the handle is set once at launch and never mutated.
    nonisolated(unsafe) private static let lib: UnsafeMutableRawPointer? = dlopen(
        "libIOReport.dylib",  // lives in the dyld shared cache on macOS 26+
        RTLD_LAZY
    )

    private static func resolve(_ symbol: String) -> UnsafeMutableRawPointer? {
        guard let lib else { return nil }
        return symbol.withCString { dlsym(lib, $0) }
    }

    // MARK: – Cached function pointers
    // `channelName` is called for every channel inside each `sampleDelta` loop;
    // re-resolving via dlsym on every call showed up as 4 M+ cycles in profiling.
    nonisolated(unsafe) private static let channelNamePtr: UnsafeMutableRawPointer? =
        resolve("IOReportChannelGetChannelName")

    // MARK: – Public API

    /// Returns a mutable channel-list dictionary for `group` (and optionally `subgroup`).
    /// The returned value is a retained CF object.
    static func copyChannels(group: String, subgroup: String? = nil) -> CFMutableDictionary? {
        typealias FnPtr = @convention(c) (CFString, CFString?, UInt64, UInt64) -> Unmanaged<CFMutableDictionary>?
        guard let ptr = resolve("IOReportCopyChannelsInGroup") else { return nil }
        return unsafeBitCast(ptr, to: FnPtr.self)(
            group as CFString,
            subgroup.map { $0 as CFString },
            0, 0
        )?.takeRetainedValue()
    }

    /// Subscribes to `channels`, returning an opaque subscription handle and the
    /// narrowed channel dict actually subscribed, or `nil` on failure.
    static func subscribe(
        channels: CFMutableDictionary
    ) -> (ref: IOReportSubscriptionRef, subscribedChannels: CFMutableDictionary)? {
        typealias FnPtr = @convention(c) (
            UnsafeRawPointer?,
            CFMutableDictionary,
            UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>?,
            UInt64,
            CFDictionary?
        ) -> IOReportSubscriptionRef?
        guard let ptr = resolve("IOReportCreateSubscription") else { return nil }
        var outChannels: Unmanaged<CFMutableDictionary>?
        guard
            let ref = unsafeBitCast(ptr, to: FnPtr.self)(nil, channels, &outChannels, 0, nil),
            let subCh = outChannels?.takeRetainedValue()
        else { return nil }
        return (ref, subCh)
    }

    /// Takes an instantaneous sample for the given subscription.
    static func takeSample(
        _ sub: IOReportSubscriptionRef,
        channels: CFMutableDictionary
    ) -> CFDictionary? {
        typealias FnPtr = @convention(c) (
            IOReportSubscriptionRef, CFMutableDictionary, CFDictionary?
        ) -> Unmanaged<CFDictionary>?
        guard let ptr = resolve("IOReportCreateSamples") else { return nil }
        return unsafeBitCast(ptr, to: FnPtr.self)(sub, channels, nil)?.takeRetainedValue()
    }

    /// Computes the element-wise delta between two consecutive samples.
    static func sampleDelta(prev: CFDictionary, curr: CFDictionary) -> CFDictionary? {
        typealias FnPtr = @convention(c) (
            CFDictionary, CFDictionary, CFDictionary?
        ) -> Unmanaged<CFDictionary>?
        guard let ptr = resolve("IOReportCreateSamplesDelta") else { return nil }
        return unsafeBitCast(ptr, to: FnPtr.self)(prev, curr, nil)?.takeRetainedValue()
    }

    /// Returns the channel name for a single channel dictionary.
    /// Uses `IOReportChannelGetChannelName` ("Get" convention — no extra retain).
    /// Falls back to `LegendChannel[2]` if the symbol is absent.
    static func channelName(_ channel: CFDictionary) -> String? {
        typealias FnPtr = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
        if let ptr = channelNamePtr {
            return unsafeBitCast(ptr, to: FnPtr.self)(channel)?.takeUnretainedValue() as String?
        }
        // Fallback: Apple stores the name at LegendChannel[2]
        let nsDict = channel as NSDictionary
        if let legend = nsDict["LegendChannel"] as? [Any], legend.count > 2 {
            return legend[2] as? String
        }
        return nil
    }

    /// Reads the integer value from a simple-format channel dictionary.
    /// Returns 0 if the symbol is unavailable or the channel is not simple-format.
    static func integerValue(_ channel: CFDictionary) -> Int64 {
        typealias FnPtr = @convention(c) (CFDictionary, UnsafeMutablePointer<Int32>?) -> Int64
        guard let ptr = resolve("IOReportSimpleGetIntegerValue") else { return 0 }
        return unsafeBitCast(ptr, to: FnPtr.self)(channel, nil)
    }
}
#endif
