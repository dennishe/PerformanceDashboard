import AppKit

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
