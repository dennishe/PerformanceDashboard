import AppKit

@MainActor
final class HostedBatteryPrimaryMeterView: NSView {
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private let borderLayer = CAShapeLayer()
    private let capLayer = CALayer()

    private var currentFraction = -1.0
    private var currentLevel: ThresholdLevel = .inactive
    private var lastLaidOutBounds: CGRect = .null

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()

        trackLayer.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull()]
        fillLayer.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull()]
        capLayer.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull()]
        borderLayer.actions = ["bounds": NSNull(), "path": NSNull(), "strokeColor": NSNull()]

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
        layer?.addSublayer(borderLayer)
        layer?.addSublayer(capLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let integralBounds = bounds.integral
        guard integralBounds != lastLaidOutBounds else { return }
        lastLaidOutBounds = integralBounds
        layoutLayers()
    }

    func update(fraction: Double, thresholdLevel: ThresholdLevel) {
        let clampedFraction = min(max(fraction, 0), 1)
        guard currentFraction != clampedFraction || currentLevel != thresholdLevel else { return }

        currentFraction = clampedFraction
        currentLevel = thresholdLevel
        fillLayer.backgroundColor = LayerColorComponents.threshold(thresholdLevel).cgColor()
        layoutLayers()
    }
}

private extension HostedBatteryPrimaryMeterView {
    func layoutLayers() {
        let insetBounds = bounds.insetBy(dx: 0, dy: 1).integral
        let trackFrame = CGRect(
            x: 0,
            y: 0,
            width: max(0, insetBounds.width - 6),
            height: insetBounds.height
        )
        let fillWidth = currentFraction > 0 ? max(6, trackFrame.width * currentFraction) : 0

        setFrameIfNeeded(trackLayer, frame: trackFrame)
        trackLayer.cornerRadius = 8
        trackLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor

        setFrameIfNeeded(
            fillLayer,
            frame: CGRect(
                x: 2,
                y: 2,
                width: max(0, fillWidth - 4),
                height: max(0, trackFrame.height - 4)
            )
        )
        fillLayer.cornerRadius = 6

        borderLayer.frame = trackFrame
        borderLayer.path = CGPath(roundedRect: trackFrame, cornerWidth: 8, cornerHeight: 8, transform: nil)
        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        borderLayer.lineWidth = 1

        setFrameIfNeeded(
            capLayer,
            frame: CGRect(
                x: trackFrame.maxX + 3,
                y: (trackFrame.height - 10) / 2,
                width: 4,
                height: 10
            )
        )
        capLayer.cornerRadius = 2
        capLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.22).cgColor
    }
}
