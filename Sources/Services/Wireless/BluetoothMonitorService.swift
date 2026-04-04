import Foundation
import IOBluetooth

/// Snapshot of Bluetooth controller state at a point in time.
public struct BluetoothSnapshot: Sendable {
    /// Number of currently connected Bluetooth devices.
    public let connectedCount: Int
    /// `true` while Bluetooth is powered on.
    public let on: Bool
}

/// Polls Bluetooth status via IOBluetooth.
/// IOBluetooth requires main-thread access, so sampling is dispatched to `@MainActor`.
public final class BluetoothMonitorService: PollingMonitorBase<BluetoothSnapshot> {
    @MonitorActor
    override public func poll(continuation: AsyncStream<BluetoothSnapshot>.Continuation) async {
        while !Task.isCancelled {
            let snapshot = await sampleOnMain()
            continuation.yield(snapshot)
            do { try await Task.sleep(for: Constants.pollingInterval) } catch { break }
        }
    }

    private func sampleOnMain() async -> BluetoothSnapshot {
        await MainActor.run {
            let on = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
            let connected = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
                .filter { $0.isConnected() }
                .count
            return BluetoothSnapshot(connectedCount: connected, on: on)
        }
    }
}
