import AppKit

struct TileTextLayerState: Equatable {
    let text: String
    let style: LayerTextStyle
    let displayScale: CGFloat
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
        "position": NSNull(),
        "string": NSNull()
    ]
    layer.alignmentMode = .left
    layer.isWrapped = false
    layer.truncationMode = .end
}

@MainActor
func updateTileTextLayer(
    _ layer: CATextLayer,
    text: String,
    style: LayerTextStyle,
    displayScale: CGFloat,
    state: inout TileTextLayerState?
) {
    let nextState = TileTextLayerState(text: text, style: style, displayScale: displayScale)
    guard state != nextState else { return }

    state = nextState
    layer.contentsScale = displayScale
    layer.string = style.attributedString(text)
}

@MainActor
func updateTileSymbolView(
    _ imageView: NSImageView,
    systemName: String,
    tintColor: NSColor,
    state: inout TileSymbolState?
) {
    let nextState = TileSymbolState(systemName: systemName, tintKey: TileTintKey(color: tintColor))
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

@MainActor
func makeTileSymbolImage(systemName: String) -> NSImage? {
    TileSymbolImageCache.shared.image(for: systemName)
}

@MainActor
private final class TileSymbolImageCache {
    static let shared = TileSymbolImageCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 32
    }

    func image(for systemName: String) -> NSImage? {
        if let cachedImage = cache.object(forKey: systemName as NSString) {
            return cachedImage
        }

        let configuration = NSImage.SymbolConfiguration(
            pointSize: DashboardDesign.FontSize.tileSubtitle,
            weight: .semibold
        )
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration),
            let templateImage = image.copy() as? NSImage else {
            return nil
        }

        templateImage.isTemplate = true
        cache.setObject(templateImage, forKey: systemName as NSString)
        return templateImage
    }
}
