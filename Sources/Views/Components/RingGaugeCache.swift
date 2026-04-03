import SwiftUI

// Renders and caches ring gauge images lazily: each (quantised value, color) pair
// is rasterised at most once, then served as a bitmap blit.
// Per-frame cost drops to a dictionary lookup — zero drawing work.
@MainActor
final class RingGaugeCache {
    static let shared = RingGaugeCache()
    private init() {}

    // MARK: - Geometry constants

    // Render at 42 pt so the 4 pt glow shadow fits without clipping.
    // Displayed at 34 pt via .resizable() → scales uniformly with the shadow.
    static let renderDiameter: CGFloat = 42
    static let displayDiameter: CGFloat = 34

    private static let strokeWidth: CGFloat = 5
    // Ring radius: (renderDiameter/2) − (strokeWidth/2) − shadowRadius = 21 − 2.5 − 4 = 14.5 pt
    // Shadow outer extent: 14.5 + 2.5 + 4 = 21 pt = render half-width  ✓ no clipping
    private static let ringRadius: CGFloat = renderDiameter / 2 - strokeWidth / 2 - 4

    // MARK: - Cache key

    private struct Key: Hashable {
        let quantized: Int      // 0 – 360  (value × 360, rounded to nearest 1°)
        let resolved: Color.Resolved  // component-based (stable RGBA), unlike Color whose
                                      // platform-backed Hashable can use internal references
                                      // that differ between call sites → 90 % miss rate.
    }

    private var storage: [Key: CGImage] = [:]

    // MARK: - Public API

    /// Returns a cached `CGImage` for the given `resolved` color and quantised `value`.
    /// Accepts a pre-resolved color so callers avoid `EnvironmentValues()` allocations
    /// on every animation frame — resolution should happen once per data tick upstream.
    func image(for value: Double, resolved: Color.Resolved) -> CGImage? {
        let quantized = Int((min(max(value, 0), 1) * 360).rounded())
        let key = Key(quantized: quantized, resolved: resolved)
        if let hit = storage[key] { return hit }
        guard let rendered = render(quantized: quantized, resolved: resolved) else { return nil }
        storage[key] = rendered
        return rendered
    }

    // MARK: - Rendering

    private func render(quantized: Int, resolved: Color.Resolved) -> CGImage? {
        let diameter = Self.renderDiameter
        let sw = Self.strokeWidth
        let radius = Self.ringRadius
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let fraction = Double(quantized) / 360.0
        // Reconstruct a SwiftUI Color from the resolved value for Canvas drawing.
        let color = Color(resolved)

        let content = Canvas { ctx, _ in
            var track = Path()
            track.addArc(center: center, radius: radius,
                         startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(track, with: .color(color.opacity(0.13)),
                       style: StrokeStyle(lineWidth: sw))

            guard fraction > 0 else { return }

            var arc = Path()
            arc.addArc(center: center, radius: radius,
                       startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + fraction * 360),
                       clockwise: false)

            var glow = ctx
            glow.addFilter(.shadow(color: color.opacity(0.6), radius: 4))
            glow.stroke(arc, with: .color(color),
                        style: StrokeStyle(lineWidth: sw, lineCap: .round))
        }
        .frame(width: diameter, height: diameter)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer.cgImage
    }
}
