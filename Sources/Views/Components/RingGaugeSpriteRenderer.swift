import AppKit

enum RingGaugeSpriteRenderer {
    static func renderFrame(value: CGFloat, style: RingGaugeStyle) -> CGImage? {
        guard let context = makeContext(for: style) else { return nil }

        let diameter = RingGaugeGeometry.displayDiameter
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let radius = diameter / 2 - RingGaugeGeometry.strokeWidth / 2 - RingGaugeGeometry.shadowRadius
        let fullCircle = makeCirclePath(center: center, radius: radius)

        drawTrack(path: fullCircle, style: style, in: context)

        guard value > 0.0005 else {
            return context.makeImage()
        }

        let progressPath = makeProgressPath(value: value, center: center, radius: radius)
        drawGlow(path: progressPath, style: style, in: context)
        drawProgress(path: progressPath, style: style, in: context)
        drawTip(value: value, center: center, radius: radius, style: style, in: context)

        return context.makeImage()
    }
}

private extension RingGaugeSpriteRenderer {
    static func makeContext(for style: RingGaugeStyle) -> CGContext? {
        let pixelSize = Int((RingGaugeGeometry.displayDiameter * style.displayScale).rounded(.up))
        guard pixelSize > 0,
              let context = CGContext(
                  data: nil,
                  width: pixelSize,
                  height: pixelSize,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.scaleBy(x: style.displayScale, y: style.displayScale)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        return context
    }

    static func makeCirclePath(center: CGPoint, radius: CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: -3 * .pi / 2,
            clockwise: true
        )
        return path
    }

    static func drawTrack(path: CGPath, style: RingGaugeStyle, in context: CGContext) {
        context.addPath(path)
        context.setStrokeColor(style.color.cgColor(alphaMultiplier: 0.13))
        context.setLineWidth(RingGaugeGeometry.strokeWidth)
        context.setLineCap(.butt)
        context.strokePath()
    }

    static func makeProgressPath(value: CGFloat, center: CGPoint, radius: CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: (.pi / 2) - (2 * .pi * value),
            clockwise: true
        )
        return path
    }

    static func drawGlow(path: CGPath, style: RingGaugeStyle, in context: CGContext) {
        context.saveGState()
        context.addPath(path)
        context.setLineWidth(RingGaugeGeometry.strokeWidth)
        context.setLineCap(.round)
        context.setShadow(
            offset: .zero,
            blur: RingGaugeGeometry.shadowRadius * 1.35,
            color: style.color.cgColor(alphaMultiplier: 0.75)
        )
        context.setStrokeColor(style.color.cgColor(alphaMultiplier: 0.92))
        context.strokePath()
        context.restoreGState()
    }

    static func drawProgress(path: CGPath, style: RingGaugeStyle, in context: CGContext) {
        context.addPath(path)
        context.setLineWidth(RingGaugeGeometry.strokeWidth)
        context.setLineCap(.butt)
        context.setStrokeColor(style.color.cgColor())
        context.strokePath()
    }

    static func drawTip(
        value: CGFloat,
        center: CGPoint,
        radius: CGFloat,
        style: RingGaugeStyle,
        in context: CGContext
    ) {
        let tipCenter = RingGaugeLayerSupport.point(for: value, center: center, radius: radius)
        let tipRadius = RingGaugeGeometry.strokeWidth / 2
        let tipRect = CGRect(
            x: tipCenter.x - tipRadius,
            y: tipCenter.y - tipRadius,
            width: RingGaugeGeometry.strokeWidth,
            height: RingGaugeGeometry.strokeWidth
        )

        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: RingGaugeGeometry.shadowRadius * 1.6,
            color: style.color.cgColor(alphaMultiplier: 0.8)
        )
        context.setFillColor(style.color.cgColor())
        context.fillEllipse(in: tipRect)
        context.restoreGState()
    }
}
