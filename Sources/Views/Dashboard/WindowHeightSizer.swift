import AppKit
import SwiftUI

/// Keeps the dashboard window height aligned with the measured content height.
@MainActor
struct WindowHeightSizer: NSViewRepresentable {
	let contentHeight: CGFloat
	var minContentHeight: CGFloat = Constants.dashboardMinimumContentHeight

	func makeCoordinator() -> Coordinator {
		Coordinator(minContentHeight: minContentHeight)
	}

	func makeNSView(context: Context) -> NSView {
		let view = NSView(frame: .zero)
		DispatchQueue.main.async { @MainActor in
			context.coordinator.updateWindow(from: view, contentHeight: contentHeight)
		}
		return view
	}

	func updateNSView(_ nsView: NSView, context: Context) {
		context.coordinator.minContentHeight = minContentHeight
		context.coordinator.updateWindow(from: nsView, contentHeight: contentHeight)
	}

	@MainActor
	final class Coordinator: NSObject {
		var minContentHeight: CGFloat

		private weak var window: NSWindow?

		init(minContentHeight: CGFloat) {
			self.minContentHeight = minContentHeight
		}

		func updateWindow(from view: NSView, contentHeight: CGFloat) {
			guard contentHeight > 0 else { return }

			guard let window = window ?? view.window else {
				DispatchQueue.main.async { @MainActor [weak view] in
					guard let view else { return }
					self.updateWindow(from: view, contentHeight: contentHeight)
				}
				return
			}

			self.window = window

			let targetContentHeight = max(
				minContentHeight,
				contentHeight.rounded(.up) + verticalInsets(for: window)
			)
			let currentContentRect = window.contentRect(forFrameRect: window.frame)
			let targetContentRect = CGRect(
				x: 0,
				y: 0,
				width: currentContentRect.width,
				height: targetContentHeight
			)
			lockWindowHeight(window, targetContentHeight: targetContentHeight)
			let targetFrameHeight = window.frameRect(forContentRect: targetContentRect).height
			let currentFrame = window.frame

			guard abs(currentFrame.height - targetFrameHeight) > 0.5 else { return }

			let targetFrame = CGRect(
				x: currentFrame.origin.x,
				y: currentFrame.maxY - targetFrameHeight,
				width: currentFrame.width,
				height: targetFrameHeight
			)
			window.setFrame(targetFrame, display: true, animate: false)
		}

		private func verticalInsets(for window: NSWindow) -> CGFloat {
			let contentHeight = window.contentRect(forFrameRect: window.frame).height
			let layoutHeight = window.contentLayoutRect.height
			return max(0, (contentHeight - layoutHeight).rounded(.up))
		}

		private func lockWindowHeight(_ window: NSWindow, targetContentHeight: CGFloat) {
			window.contentMinSize = NSSize(
				width: Constants.dashboardMinimumWindowWidth,
				height: targetContentHeight
			)
			window.contentMaxSize = NSSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: targetContentHeight
			)
		}
	}
}
