import Foundation

@MainActor
public protocol UpdateScheduling: AnyObject {
    func enqueue(owner: AnyObject, update: @escaping () -> Void)
    func cancel(owner: AnyObject)
}

@MainActor
public final class DashboardUpdateBatcher: UpdateScheduling {
    public static let shared = DashboardUpdateBatcher()

    private let flushDelay: Duration
    private var pendingUpdates: [ObjectIdentifier: [() -> Void]] = [:]
    private var flushTask: Task<Void, Never>?

    init(flushDelay: Duration = Constants.updateCoalescingInterval) {
        self.flushDelay = flushDelay
    }

    public func enqueue(owner: AnyObject, update: @escaping () -> Void) {
        let key = ObjectIdentifier(owner)
        pendingUpdates[key, default: []].append(update)

        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.flushDelay ?? Constants.updateCoalescingInterval)
            self?.flush()
        }
    }

    public func cancel(owner: AnyObject) {
        pendingUpdates.removeValue(forKey: ObjectIdentifier(owner))
    }

    private func flush() {
        let updates = pendingUpdates.values.flatMap { $0 }
        pendingUpdates.removeAll()
        flushTask = nil
        updates.forEach { $0() }
    }
}
