import AppKit

@MainActor
final class AtlasRingGaugeHostingView: NSView, RingGaugeAnimationTicking {
    private let imageLayer = CALayer()
    private let animationDriver: RingGaugeAnimationDriver
    private let currentTimestamp: () -> CFTimeInterval

    private var currentAtlasKey: RingGaugeAtlasKey?
    private var atlas: RingGaugeAtlas?
    private var displayedFrameIndex = 0
    private var startFrameIndex = 0
    private var targetFrameIndex = 0
    private var animationStartTime: CFTimeInterval = 0
    private var isAnimating = false

    override convenience init(frame frameRect: NSRect) {
        self.init(
            frame: frameRect,
            animationDriver: .shared,
            currentTimestamp: CACurrentMediaTime
        )
    }

    init(
        frame frameRect: NSRect,
        animationDriver: RingGaugeAnimationDriver,
        currentTimestamp: @escaping () -> CFTimeInterval
    ) {
        self.animationDriver = animationDriver
        self.currentTimestamp = currentTimestamp
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()

        imageLayer.actions = [
            "bounds": NSNull(),
            "contents": NSNull(),
            "contentsRect": NSNull(),
            "contentsScale": NSNull(),
            "position": NSNull()
        ]
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .linear
        layer?.addSublayer(imageLayer)
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
        imageLayer.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopAnimation()
        }
    }

    func update(value: Double, style: RingGaugeStyle) {
        let clampedValue = CGFloat(min(max(value, 0), 1))
        let atlas = loadAtlasIfNeeded(for: style)
        let nextFrameIndex = atlas.frameIndex(for: clampedValue)

        guard nextFrameIndex != targetFrameIndex || !isAnimating else { return }

        if nextFrameIndex == displayedFrameIndex {
            targetFrameIndex = nextFrameIndex
            stopAnimation()
            return
        }

        startFrameIndex = displayedFrameIndex
        targetFrameIndex = nextFrameIndex
        animationStartTime = currentTimestamp()
        isAnimating = true
        animationDriver.add(self)
    }

    func ringGaugeAnimationDidTick(at timestamp: CFTimeInterval) {
        guard isAnimating, let atlas else {
            stopAnimation()
            return
        }

        let progress = min(max((timestamp - animationStartTime) / RingGaugeLayerSupport.animationDuration, 0), 1)
        let interpolated = Double(startFrameIndex)
            + Double(targetFrameIndex - startFrameIndex) * progress
        let nextFrameIndex = Int(interpolated.rounded())

        if nextFrameIndex != displayedFrameIndex {
            applyFrame(index: nextFrameIndex, atlas: atlas)
        }

        if progress >= 1 {
            stopAnimation()
            if displayedFrameIndex != targetFrameIndex {
                applyFrame(index: targetFrameIndex, atlas: atlas)
            }
        }
    }

    private func loadAtlasIfNeeded(for style: RingGaugeStyle) -> RingGaugeAtlas {
        let atlasKey = RingGaugeAtlasKey(style: style)
        if atlas == nil || currentAtlasKey != atlasKey {
            currentAtlasKey = atlasKey
            atlas = RingGaugeAtlasCache.shared.atlas(for: atlasKey)
            imageLayer.contents = atlas?.image
            imageLayer.contentsScale = style.displayScale
            if let atlas {
                imageLayer.contentsRect = atlas.contentsRect(for: displayedFrameIndex)
            }
        }

        guard let atlas else {
            preconditionFailure("Ring gauge atlas was not created")
        }

        return atlas
    }

    private func applyFrame(index: Int, atlas: RingGaugeAtlas) {
        imageLayer.contentsRect = atlas.contentsRect(for: index)
        displayedFrameIndex = index
    }

    private func stopAnimation() {
        isAnimating = false
        animationDriver.remove(self)
    }

    var renderedFrameIndex: Int {
        displayedFrameIndex
    }

    var destinationFrameIndex: Int {
        targetFrameIndex
    }

    var isAnimatingForTesting: Bool {
        isAnimating
    }
}
