import AppKit

struct SparklineStyle: Hashable {
    let color: LayerColorComponents
    let displayScale: CGFloat
}

private struct SparklineSignature: Hashable {
    let historyHash: Int
    let widthPixels: Int
    let heightPixels: Int
    let style: SparklineStyle

    init(history: [Double], size: CGSize, style: SparklineStyle) {
        var hasher = Hasher()
        hasher.combine(history.count)
        for value in history {
            hasher.combine(value.bitPattern)
        }

        historyHash = hasher.finalize()
        widthPixels = max(1, Int((size.width * style.displayScale).rounded()))
        heightPixels = max(1, Int((size.height * style.displayScale).rounded()))
        self.style = style
    }
}

final class SparklineHostingView: NSView {
    private let gradientLayer = CAGradientLayer()
    private let fillMaskLayer = CAShapeLayer()
    private let lineLayer = CAShapeLayer()

    private var history: [Double] = []
    private var style: SparklineStyle?
    private var signature: SparklineSignature?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        layer?.isGeometryFlipped = true

        fillMaskLayer.isGeometryFlipped = true
        lineLayer.isGeometryFlipped = true

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.mask = fillMaskLayer
        gradientLayer.actions = [
            "bounds": NSNull(),
            "contentsScale": NSNull(),
            "frame": NSNull(),
            "position": NSNull()
        ]

        fillMaskLayer.fillColor = NSColor.white.cgColor
        fillMaskLayer.actions = [
            "bounds": NSNull(),
            "frame": NSNull(),
            "path": NSNull(),
            "position": NSNull()
        ]

        lineLayer.fillColor = nil
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        lineLayer.lineWidth = 1.5
        lineLayer.actions = [
            "bounds": NSNull(),
            "contentsScale": NSNull(),
            "frame": NSNull(),
            "path": NSNull(),
            "position": NSNull(),
            "strokeColor": NSNull()
        ]

        layer?.addSublayer(gradientLayer)
        layer?.addSublayer(lineLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: SparklineGeometry.displayHeight)
    }

    override func layout() {
        super.layout()
        updateLayersIfNeeded()
    }

    func update(history: [Double], style: SparklineStyle) {
        let historyChanged = self.history != history
        let styleChanged = self.style != style
        guard historyChanged || styleChanged else { return }

        self.history = history
        if styleChanged {
            self.style = style
            applyStyle(style)
        }
        updateLayersIfNeeded()
    }

    private func applyStyle(_ style: SparklineStyle) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.contentsScale = style.displayScale
        lineLayer.contentsScale = style.displayScale
        gradientLayer.colors = [
            style.color.cgColor(alphaMultiplier: 0.22),
            style.color.cgColor(alphaMultiplier: 0.02)
        ]
        lineLayer.strokeColor = style.color.cgColor()
        CATransaction.commit()
    }

    private func updateLayersIfNeeded() {
        guard let style else { return }

        let size = bounds.size
        guard size.width > 0, size.height > 0, history.count > 1 else {
            signature = nil
            fillMaskLayer.path = nil
            lineLayer.path = nil
            return
        }

        let newSignature = SparklineSignature(history: history, size: size, style: style)
        guard newSignature != signature else { return }
        signature = newSignature

        let paths = makePaths(history: history, size: size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        lineLayer.frame = bounds
        fillMaskLayer.frame = bounds
        fillMaskLayer.path = paths.fillPath
        lineLayer.path = paths.linePath
        CATransaction.commit()
    }

    private func makePaths(history: [Double], size: CGSize) -> (fillPath: CGPath, linePath: CGPath) {
        let maxValue = max(history.max() ?? 1, 0.001)
        let step = size.width / Double(history.count - 1)
        let yScale = size.height * 0.88

        var points: [CGPoint] = []
        points.reserveCapacity(history.count)
        for (index, value) in history.enumerated() {
            points.append(CGPoint(
                x: Double(index) * step,
                y: size.height - (value / maxValue) * yScale
            ))
        }

        let fillPath = CGMutablePath()
        let linePath = CGMutablePath()

        if let first = points.first, let last = points.last {
            fillPath.move(to: CGPoint(x: first.x, y: size.height))
            fillPath.addLine(to: first)

            linePath.move(to: first)
            for point in points.dropFirst() {
                fillPath.addLine(to: point)
                linePath.addLine(to: point)
            }

            fillPath.addLine(to: CGPoint(x: last.x, y: size.height))
            fillPath.closeSubpath()
        }

        return (fillPath, linePath)
    }
}
