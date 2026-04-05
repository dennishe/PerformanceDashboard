import AppKit
import SwiftUI

struct DashboardWindowObserver: NSViewRepresentable {
    @Binding var isWindowVisible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isWindowVisible: $isWindowVisible)
    }

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view.window)
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        context.coordinator.updateBinding($isWindowVisible)
        nsView.coordinator = context.coordinator
        context.coordinator.attach(to: nsView.window)
    }
}

final class ObserverView: NSView {
    weak var coordinator: DashboardWindowObserver.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: window)
    }
}

extension DashboardWindowObserver {
    @MainActor
    final class Coordinator: NSObject {
        private var isWindowVisible: Binding<Bool>
        private weak var observedWindow: NSWindow?

        init(isWindowVisible: Binding<Bool>) {
            self.isWindowVisible = isWindowVisible
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func updateBinding(_ binding: Binding<Bool>) {
            isWindowVisible = binding
        }

        func attach(to window: NSWindow?) {
            guard observedWindow !== window else { return }
            observedWindow = window

            guard let window else { return }

            registerWindowNotifications(for: window)
            syncVisibility(with: window)
        }

        private func registerWindowNotifications(for window: NSWindow) {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(windowDidBecomeVisible),
                               name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidBecomeVisible),
                               name: NSWindow.didDeminiaturizeNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidHide),
                               name: NSWindow.willCloseNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidHide),
                               name: NSWindow.didMiniaturizeNotification, object: window)
        }

        private func syncVisibility(with window: NSWindow) {
            setWindowVisible(window.isVisible && !window.isMiniaturized)
        }

        @objc private func windowDidBecomeVisible() {
            setWindowVisible(true)
        }

        @objc private func windowDidHide() {
            setWindowVisible(false)
        }

        private func setWindowVisible(_ isVisible: Bool) {
            guard isWindowVisible.wrappedValue != isVisible else { return }
            isWindowVisible.wrappedValue = isVisible
        }
    }
}
