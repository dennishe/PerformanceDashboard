import AppKit

@MainActor
func setFrameIfNeeded(_ view: NSView, frame: CGRect) {
    guard view.frame != frame else { return }
    view.frame = frame
}

@MainActor
func setFrameIfNeeded(_ layer: CALayer, frame: CGRect) {
    guard layer.frame != frame else { return }
    layer.frame = frame
}
