import AppKit
import SwiftUI

/// Keeps the dashboard window height aligned with the measured content height.
///
/// Uses `NSWindowDelegate.windowWillResize(_:to:)` to lock the height *synchronously*
/// during every pixel of a live user drag so no empty-space flash ever appears.
/// Programmatic height changes (e.g. when the column count jumps) go through
/// `applyHeight(_:)`, which constrains the resulting frame to the visible screen area.
@MainActor
struct WindowHeightSizer: NSViewRepresentable {
    let contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // view.window is nil at this point; defer until the view enters the hierarchy.
        DispatchQueue.main.async { @MainActor in
            if let window = view.window { context.coordinator.attach(to: window) }
            context.coordinator.applyHeight(context.coordinator.pendingHeight)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { context.coordinator.attach(to: window) }
        context.coordinator.applyHeight(contentHeight)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        /// Height last committed to the window (used by windowWillResize to lock height).
        private(set) var lockedContentHeight: CGFloat = 0
        /// Stores the height until the window is available.
        var pendingHeight: CGFloat = 0
        private(set) weak var window: NSWindow?

        /// Installs the coordinator as the window's delegate (once).
        func attach(to window: NSWindow) {
            guard window !== self.window else { return }
            self.window = window
            window.delegate = self
            // Lock height immediately using the current frame so vertical resize
            // handles are never shown, even before the first layout pass fires.
            let layoutHeight = pendingHeight > 0 ? pendingHeight : window.contentLayoutRect.height
            let inset = Self.chromeInset(for: window)
            let lockedHeight = (layoutHeight + inset).rounded(.up)
            window.contentMinSize = NSSize(width: Constants.dashboardMinimumWindowWidth, height: lockedHeight)
            window.contentMaxSize = NSSize(width: .greatestFiniteMagnitude, height: lockedHeight)
        }

        /// Updates the window height to match `contentHeight`.
        func applyHeight(_ contentHeight: CGFloat) {
            pendingHeight = contentHeight
            guard contentHeight > 0, let window else { return }

            lockedContentHeight = contentHeight

            let inset = Self.chromeInset(for: window)
            let targetContentHeight = (contentHeight + inset).rounded(.up)
            let contentWidth = window.contentRect(forFrameRect: window.frame).width
            let targetContentRect = NSRect(x: 0, y: 0, width: contentWidth, height: targetContentHeight)
            let targetFrameHeight = window.frameRect(forContentRect: targetContentRect).height

            // Prevent manual vertical resizing — height is always driven by content.
            window.contentMinSize = NSSize(
                width: Constants.dashboardMinimumWindowWidth,
                height: targetContentHeight
            )
            window.contentMaxSize = NSSize(
                width: .greatestFiniteMagnitude,
                height: targetContentHeight
            )

            guard abs(window.frame.height - targetFrameHeight) > 0.5 else { return }

            // Anchor to the top edge; clamp to keep the window fully on-screen.
            let current = window.frame
            let proposed = NSRect(
                x: current.minX,
                y: current.maxY - targetFrameHeight,
                width: current.width,
                height: targetFrameHeight
            )
            let constrained = window.constrainFrameRect(proposed, to: window.screen)
            window.setFrame(constrained, display: true, animate: false)
        }

        // MARK: NSWindowDelegate

        /// Called on every pixel of a live user resize.
        /// Locks the frame height to the last committed content height so the
        /// window height tracks the tile layout rather than user drag.
        nonisolated func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            MainActor.assumeIsolated {
                guard lockedContentHeight > 0 else { return frameSize }
                let inset = Self.chromeInset(for: sender)
                let targetContentHeight = (lockedContentHeight + inset).rounded(.up)
                let targetContentRect = NSRect(x: 0, y: 0, width: frameSize.width, height: targetContentHeight)
                let targetFrameHeight = sender.frameRect(forContentRect: targetContentRect).height
                return NSSize(width: frameSize.width, height: targetFrameHeight)
            }
        }

        // MARK: Helpers

        /// The fixed vertical chrome — titlebar + any bottom inset — that must be
        /// added to the SwiftUI layout height to get the correct window frame height.
        /// SwiftUI uses full-size content view, so `contentLayoutRect` is the safe zone.
        nonisolated private static func chromeInset(for window: NSWindow) -> CGFloat {
            max(0, window.frame.height - window.contentLayoutRect.height)
        }
    }
}
