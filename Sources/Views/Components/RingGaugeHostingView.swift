import AppKit

final class RingGaugeHostingView: NSView {
    private let trackLayer = CAShapeLayer()
    private let glowContainerLayer = CALayer()
    private let glowStrokeLayer = CAShapeLayer()
    private let glowMaskLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let tipLayer = CALayer()

    private var style: RingGaugeStyle?
    private var lastBounds: CGRect = .zero
    private var lastValue: CGFloat = 0
    private var ringCenter: CGPoint = .zero
    private var ringRadius: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false

        configureShapeLayer(trackLayer)
        configureShapeLayer(glowStrokeLayer)
        configureShapeLayer(glowMaskLayer)
        configureShapeLayer(progressLayer)
        RingGaugeLayerSupport.configureTipLayer(tipLayer)

        glowStrokeLayer.lineCap = .round
        glowStrokeLayer.shadowOffset = .zero
        glowStrokeLayer.shadowOpacity = 1

        glowContainerLayer.masksToBounds = false
        glowContainerLayer.addSublayer(glowStrokeLayer)
        glowContainerLayer.mask = glowMaskLayer

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(glowContainerLayer)
        layer?.addSublayer(progressLayer)
        layer?.addSublayer(tipLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: RingGaugeGeometry.displayDiameter, height: RingGaugeGeometry.displayDiameter)
    }

    override func layout() {
        super.layout()
        updatePathsIfNeeded()
    }

    func update(value: Double, style: RingGaugeStyle) {
        if self.style != style {
            self.style = style
            applyStyle(style)
        }
        let geometryChanged = updatePathsIfNeeded()
        let clampedValue = CGFloat(min(max(value, 0), 1))

        if geometryChanged {
            RingGaugeLayerSupport.setStrokeEnd(on: progressLayer, to: clampedValue)
            RingGaugeLayerSupport.setStrokeEnd(on: glowMaskLayer, to: clampedValue)
            RingGaugeLayerSupport.setTip(layer: tipLayer, value: clampedValue, center: ringCenter, radius: ringRadius)
            lastValue = clampedValue
            return
        }

        guard abs(lastValue - clampedValue) > 0.0005 else { return }
        updateProgress(from: lastValue, to: clampedValue)
        lastValue = clampedValue
    }

    private func configureShapeLayer(_ shapeLayer: CAShapeLayer) {
        shapeLayer.fillColor = nil
        shapeLayer.lineCap = .butt
        shapeLayer.lineJoin = .round
        shapeLayer.actions = [
            "bounds": NSNull(),
            "contentsScale": NSNull(),
            "lineWidth": NSNull(),
            "path": NSNull(),
            "position": NSNull(),
            "shadowColor": NSNull(),
            "shadowRadius": NSNull(),
            "strokeColor": NSNull(),
            "strokeEnd": NSNull()
        ]
    }

    private func applyStyle(_ style: RingGaugeStyle) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let contentsScale = style.displayScale
        trackLayer.contentsScale = contentsScale
        glowStrokeLayer.contentsScale = contentsScale
        glowMaskLayer.contentsScale = contentsScale
        progressLayer.contentsScale = contentsScale
        tipLayer.contentsScale = contentsScale

        trackLayer.strokeColor = style.color.cgColor(alphaMultiplier: 0.13)
        glowStrokeLayer.strokeColor = style.color.cgColor(alphaMultiplier: 0.92)
        glowStrokeLayer.shadowColor = style.color.cgColor(alphaMultiplier: 0.75)
        glowStrokeLayer.shadowRadius = RingGaugeGeometry.shadowRadius * 1.35
        progressLayer.strokeColor = style.color.cgColor()
        glowMaskLayer.strokeColor = NSColor.white.cgColor
        tipLayer.backgroundColor = style.color.cgColor()
        tipLayer.shadowColor = style.color.cgColor(alphaMultiplier: 0.8)
        tipLayer.shadowRadius = RingGaugeGeometry.shadowRadius * 1.6

        CATransaction.commit()
    }

    private func updatePathsIfNeeded() -> Bool {
        guard bounds.width > 0, bounds.height > 0, bounds != lastBounds else { return false }
        lastBounds = bounds

        let diameter = min(bounds.width, bounds.height)
        let radius = diameter / 2 - RingGaugeGeometry.strokeWidth / 2 - RingGaugeGeometry.shadowRadius
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        ringCenter = center
        ringRadius = radius

        let path = CGMutablePath()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: -3 * .pi / 2,
            clockwise: true
        )

        let maskWidth = RingGaugeGeometry.strokeWidth + RingGaugeGeometry.shadowRadius * 2.8
        let glowShadowPath = path.copy(
            strokingWithWidth: RingGaugeGeometry.strokeWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        applyGeometry(
            path: path,
            glowShadowPath: glowShadowPath,
            maskWidth: maskWidth,
            tipDiameter: RingGaugeGeometry.strokeWidth
        )
        return true
    }

    private func updateProgress(from currentValue: CGFloat, to newValue: CGFloat) {
        RingGaugeLayerSupport.animateStrokeEnd(on: progressLayer, from: currentValue, to: newValue)
        RingGaugeLayerSupport.animateStrokeEnd(on: glowMaskLayer, from: currentValue, to: newValue)
        RingGaugeLayerSupport.updateTip(
            layer: tipLayer,
            from: currentValue,
            to: newValue,
            center: ringCenter,
            radius: ringRadius
        )
    }

    private func applyGeometry(
        path: CGPath,
        glowShadowPath: CGPath,
        maskWidth: CGFloat,
        tipDiameter: CGFloat
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        trackLayer.frame = bounds
        glowContainerLayer.frame = bounds
        glowStrokeLayer.frame = bounds
        glowMaskLayer.frame = bounds
        progressLayer.frame = bounds

        trackLayer.lineWidth = RingGaugeGeometry.strokeWidth
        glowStrokeLayer.lineWidth = RingGaugeGeometry.strokeWidth
        glowMaskLayer.lineWidth = maskWidth
        progressLayer.lineWidth = RingGaugeGeometry.strokeWidth
        tipLayer.bounds = CGRect(x: 0, y: 0, width: tipDiameter, height: tipDiameter)
        tipLayer.cornerRadius = tipDiameter / 2

        trackLayer.path = path
        glowStrokeLayer.path = path
        glowStrokeLayer.shadowPath = glowShadowPath
        glowMaskLayer.path = path
        progressLayer.path = path

        CATransaction.commit()
    }
}
