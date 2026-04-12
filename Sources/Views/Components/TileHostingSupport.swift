import AppKit

struct TileTextLayerState: Equatable {
    let text: String
    let styleKey: LayerTextStyleKey
    let displayScale: CGFloat
}

@MainActor
struct PreparedTileTextStyle {
    let styleKey: LayerTextStyleKey
    private let attributes: [NSAttributedString.Key: Any]

    init(style: LayerTextStyle, tintKey: TileTintKey? = nil) {
        let resolvedTintKey = tintKey ?? TileTintKey(color: style.color)
        styleKey = LayerTextStyleKey(style: style, colorKey: resolvedTintKey)
        attributes = style.textAttributes()
    }

    func attributedString(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes)
    }
}

struct LayerTextStyleKey: Equatable {
    let fontSize: Int
    let fontWeight: Int
    let colorKey: TileTintKey
    let kerning: Int
    let lineHeight: Int
    let fontKind: LayerTextStyle.FontKind

    init(style: LayerTextStyle) {
        self.init(style: style, colorKey: TileTintKey(color: style.color))
    }

    init(style: LayerTextStyle, colorKey: TileTintKey) {
        fontSize = Int((style.fontSize * 100).rounded())
        fontWeight = Int((style.fontWeight.rawValue * 1_000).rounded())
        self.colorKey = colorKey
        kerning = Int((style.kerning * 100).rounded())
        lineHeight = Int((style.lineHeight * 100).rounded())
        fontKind = style.fontKind
    }
}

struct TileSymbolState: Equatable {
    let systemName: String
    let tintKey: TileTintKey
}

struct TileTintKey: Equatable {
    let red: Int
    let green: Int
    let blue: Int
    let alpha: Int

    static let label = TileTintKey(color: .labelColor)
    static let tertiaryLabel = TileTintKey(color: .tertiaryLabelColor)
    static let secondaryLabel = TileTintKey(color: .secondaryLabelColor)
    static let normal = TileTintKey(color: .systemGreen)
    static let warning = TileTintKey(color: .systemOrange)
    static let critical = TileTintKey(color: .systemRed)
    static let blue = TileTintKey(color: .systemBlue)

    init(color: NSColor) {
        let resolvedColor = color.usingColorSpace(.deviceRGB) ?? color
        red = Int((resolvedColor.redComponent * 255).rounded())
        green = Int((resolvedColor.greenComponent * 255).rounded())
        blue = Int((resolvedColor.blueComponent * 255).rounded())
        alpha = Int((resolvedColor.alphaComponent * 255).rounded())
    }
}

struct RingGaugePlatformComponent {
    let view: NSView
    let update: @MainActor (Double, RingGaugeStyle) -> Void
}

@MainActor
func makeRingGaugePlatformComponent() -> RingGaugePlatformComponent {
    let view = AtlasRingGaugeHostingView()
    return RingGaugePlatformComponent(view: view) { value, style in
        view.update(value: value, style: style)
    }
}

func configureTileTextLayer(_ layer: CATextLayer) {
    layer.actions = [
        "bounds": NSNull(),
        "contentsScale": NSNull(),
        "contents": NSNull(),
        "position": NSNull(),
        "rasterizationScale": NSNull(),
        "string": NSNull()
    ]
    layer.alignmentMode = .left
    layer.drawsAsynchronously = true
    layer.isWrapped = false
    layer.shouldRasterize = true
    layer.truncationMode = .end
}

@MainActor
func updateTileTextLayer(
    _ layer: CATextLayer,
    text: String,
    preparedStyle: PreparedTileTextStyle,
    displayScale: CGFloat,
    state: inout TileTextLayerState?
) {
    let nextState = TileTextLayerState(
        text: text,
        styleKey: preparedStyle.styleKey,
        displayScale: displayScale
    )
    guard state != nextState else { return }

    state = nextState
    layer.contentsScale = displayScale
    layer.rasterizationScale = displayScale
    layer.string = preparedStyle.attributedString(text)
}

@MainActor
func updateTileTextLayer(
    _ layer: CATextLayer,
    text: String,
    style: LayerTextStyle,
    displayScale: CGFloat,
    state: inout TileTextLayerState?
) {
    let nextState = TileTextLayerState(
        text: text,
        styleKey: LayerTextStyleKey(style: style),
        displayScale: displayScale
    )
    guard state != nextState else { return }

    state = nextState
    layer.contentsScale = displayScale
    layer.rasterizationScale = displayScale
    layer.string = style.attributedString(text)
}

@MainActor
func updateTileSymbolView(
    _ imageView: NSImageView,
    systemName: String,
    tintColor: NSColor,
    state: inout TileSymbolState?
) {
    updateTileSymbolView(
        imageView,
        systemName: systemName,
        tintColor: tintColor,
        tintKey: TileTintKey(color: tintColor),
        state: &state
    )
}

@MainActor
func updateTileSymbolView(
    _ imageView: NSImageView,
    systemName: String,
    tintColor: NSColor,
    tintKey: TileTintKey,
    state: inout TileSymbolState?
) {
    let nextState = TileSymbolState(systemName: systemName, tintKey: tintKey)
    guard state != nextState else { return }

    state = nextState
    imageView.image = makeTileSymbolImage(systemName: systemName)
    imageView.contentTintColor = tintColor
}

extension LayerTextStyle {
    @MainActor
    func attributedString(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: textAttributes())
    }
}
