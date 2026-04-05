import AppKit

enum RingGaugeLayerSupport {
    static let animationDuration: CFTimeInterval = 0.3

    static func setStrokeEnd(on layer: CAShapeLayer, to newValue: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.strokeEnd = newValue
        CATransaction.commit()
    }

    static func configureTipLayer(_ tipLayer: CALayer) {
        tipLayer.actions = [
            "backgroundColor": NSNull(),
            "bounds": NSNull(),
            "contentsScale": NSNull(),
            "cornerRadius": NSNull(),
            "hidden": NSNull(),
            "position": NSNull(),
            "shadowColor": NSNull(),
            "shadowOpacity": NSNull(),
            "shadowRadius": NSNull()
        ]
        tipLayer.isHidden = true
        tipLayer.shadowOffset = .zero
        tipLayer.shadowOpacity = 1
    }

    static func currentStrokeEnd(for layer: CAShapeLayer) -> CGFloat {
        (layer.presentation() as? CAShapeLayer)?.strokeEnd ?? layer.strokeEnd
    }

    static func animateStrokeEnd(on layer: CAShapeLayer, from current: CGFloat, to newValue: CGFloat) {
        setStrokeEnd(on: layer, to: newValue)

        guard abs(current - newValue) > 0.0005 else { return }

        layer.removeAnimation(forKey: "strokeEnd")

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = current
        animation.toValue = newValue
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "strokeEnd")
    }

    static func updateTip(
        layer: CALayer,
        from currentValue: CGFloat,
        to newValue: CGFloat,
        center: CGPoint,
        radius: CGFloat
    ) {
        guard radius > 0 else { return }

        let isVisible = newValue > 0.0005
        let newPosition = point(for: newValue, center: center, radius: radius)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.isHidden = !isVisible
        layer.position = newPosition
        CATransaction.commit()

        guard isVisible, currentValue > 0.0005 else { return }

        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = point(for: currentValue, center: center, radius: radius)
        animation.toValue = newPosition
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "position")
    }

    static func setTip(layer: CALayer, value: CGFloat, center: CGPoint, radius: CGFloat) {
        guard radius > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.isHidden = value <= 0.0005
        layer.position = point(for: value, center: center, radius: radius)
        CATransaction.commit()
    }

    static func point(for value: CGFloat, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = .pi / 2 - 2 * .pi * value
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}
