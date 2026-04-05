import Foundation

@MainActor
final class DashboardUpdateBatcher {
    static let shared = DashboardUpdateBatcher()

    private struct UpdateKey: Hashable {
        let ownerID: ObjectIdentifier
        let lane: String
    }

    private var pendingUpdates: [UpdateKey: [() -> Void]] = [:]
    private var flushTask: Task<Void, Never>?

    private init() {}

    func enqueue(owner: AnyObject, lane: String = "default", update: @escaping () -> Void) {
        let key = UpdateKey(ownerID: ObjectIdentifier(owner), lane: lane)
        pendingUpdates[key, default: []].append(update)

        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Constants.updateCoalescingInterval)
            self?.flush()
        }
    }

    func cancel(owner: AnyObject) {
        let ownerID = ObjectIdentifier(owner)
        pendingUpdates = pendingUpdates.filter { $0.key.ownerID != ownerID }
    }

    private func flush() {
        let updates = pendingUpdates.values.flatMap { $0 }
        pendingUpdates.removeAll()
        flushTask = nil
        updates.forEach { $0() }
    }
}
