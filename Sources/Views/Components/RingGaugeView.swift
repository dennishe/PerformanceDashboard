import AppKit

enum RingGaugeGeometry {
    static let displayDiameter: CGFloat = 34

    private static let renderDiameter: CGFloat = 42
    private static let renderStrokeWidth: CGFloat = 5
    private static let renderShadowRadius: CGFloat = 4

    private static let scale = displayDiameter / renderDiameter

    static let strokeWidth = renderStrokeWidth * scale
    static let shadowRadius = renderShadowRadius * scale
}

struct RingGaugeStyle: Hashable {
    let color: LayerColorComponents
    let displayScale: CGFloat
    let profile: GaugeColorProfile
}
