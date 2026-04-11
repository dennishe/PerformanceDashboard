import AppKit

struct RingGaugeAtlasKey: Hashable {
    let displayScaleKey: Int
    let profile: GaugeColorProfile

    init(style: RingGaugeStyle) {
        self.displayScaleKey = Int((style.displayScale * 100).rounded())
        self.profile = style.profile
    }

    var scale: CGFloat {
        CGFloat(displayScaleKey) / 100
    }
}

struct RingGaugeAtlas {
    static let frameCount = 361

    let image: CGImage
    let columns: Int
    let rows: Int

    func frameIndex(for value: CGFloat) -> Int {
        let clamped = min(max(value, 0), 1)
        return min(Int((clamped * 360).rounded()), Self.frameCount - 1)
    }

    func contentsRect(for frameIndex: Int) -> CGRect {
        let column = frameIndex % columns
        let row = frameIndex / columns

        return CGRect(
            x: CGFloat(column) / CGFloat(columns),
            y: CGFloat(row) / CGFloat(rows),
            width: 1 / CGFloat(columns),
            height: 1 / CGFloat(rows)
        )
    }
}

@MainActor
final class RingGaugeAtlasCache {
    static let shared = RingGaugeAtlasCache()

    private let cache = NSCache<NSString, AtlasBox>()

    private init() {
        cache.countLimit = 16
    }

    func atlas(for key: RingGaugeAtlasKey) -> RingGaugeAtlas {
        let cacheKey = cacheKey(for: key)
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached.atlas
        }

        let atlas = RingGaugeAtlasRenderer.renderAtlas(for: key)
        cache.setObject(AtlasBox(atlas: atlas), forKey: cacheKey as NSString)
        return atlas
    }
}

private extension RingGaugeAtlasCache {
    final class AtlasBox: NSObject {
        let atlas: RingGaugeAtlas

        init(atlas: RingGaugeAtlas) {
            self.atlas = atlas
        }
    }

    func cacheKey(for key: RingGaugeAtlasKey) -> String {
        "\(key.displayScaleKey)-\(key.profile)"
    }
}
