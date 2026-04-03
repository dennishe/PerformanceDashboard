import Foundation

/// Snapshot of Apple Silicon Media Engine activity.
public struct MediaEngineSnapshot: Sendable {
    /// Average encoder power in milliwatts over the last sample window; `nil` on Intel.
    public let encodeMilliwatts: Double?
    /// Average decoder power in milliwatts over the last sample window; `nil` on Intel.
    public let decodeMilliwatts: Double?
}

/// Monitors the H.264/HEVC encode and decode engines via IOReport on Apple Silicon.
/// The `AVE` (encoder) and `VDEC` (decoder) channels are in the `PMP / Energy Counters`
/// IOReport group; values are millijoules per sample interval (≈ milliwatts at 1 s/poll).
public final class MediaEngineMonitorService: MetricMonitorProtocol {
    private var continuation: AsyncStream<MediaEngineSnapshot>.Continuation?
    private var task: Task<Void, Never>?

    public init() {}

    @MainActor
    public func stream() -> AsyncStream<MediaEngineSnapshot> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.task = Task { await self.poll(continuation: continuation) }
        }
    }

    @MainActor
    public func stop() {
        task?.cancel()
        continuation?.finish()
    }

    @MonitorActor
    private func poll(continuation: AsyncStream<MediaEngineSnapshot>.Continuation) async {
        #if arch(arm64)
        PMPSampler.shared.setUp()
        let state = MediaEngineState()
        #endif
        while !Task.isCancelled {
            #if arch(arm64)
            let snapshot = state.nextSnapshot()
                ?? MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
            #else
            let snapshot = MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
            #endif
            continuation.yield(snapshot)
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }
}

// MARK: - IOReport state (Apple Silicon only)

#if arch(arm64)
/// Extracts AVE/VDEC power from the shared `PMPSampler` delta.
/// The `AVE` (encoder) and `VDEC` (decoder) channels are in `PMP / Energy Counters`;
/// values are millijoules per sample interval (≈ milliwatts at 1 s/poll).
private struct MediaEngineState {
    @MonitorActor func nextSnapshot() -> MediaEngineSnapshot? {
        guard let delta = PMPSampler.shared.nextDelta() else { return nil }
        return extract(from: delta)
    }

    private func extract(from delta: CFDictionary) -> MediaEngineSnapshot {
        let nsDict = delta as NSDictionary
        guard let array = nsDict["IOReportChannels"] as? [NSDictionary] else {
            return MediaEngineSnapshot(encodeMilliwatts: nil, decodeMilliwatts: nil)
        }
        var encode = Int64.min
        var decode = Int64.min
        for channel in array {
            let name = IOReport.channelName(channel as CFDictionary)
            let val = IOReport.integerValue(channel as CFDictionary)
            guard val != Int64.min else { continue }
            switch name {
            case "AVE":  encode = encode == Int64.min ? val : encode + val
            case "VDEC": decode = decode == Int64.min ? val : decode + val
            default: break
            }
        }
        return MediaEngineSnapshot(
            encodeMilliwatts: encode != Int64.min ? Double(max(0, encode)) : nil,
            decodeMilliwatts: decode != Int64.min ? Double(max(0, decode)) : nil
        )
    }
}
#endif
