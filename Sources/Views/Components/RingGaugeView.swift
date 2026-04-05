import SwiftUI
import AppKit

/// A ring / arc gauge showing a single normalised value in [0, 1].
///
/// The animation runs inside Core Animation so SwiftUI only updates when the
/// metric value changes, not on every in-between animation frame.
struct RingGaugeView: View {
    let value: Double
    let color: LayerColorComponents
    let accessibilityLabel: String
    let accessibilityValue: String

    var body: some View {
        RingGaugeRepresentable(value: value, color: color)
            .equatable()
            .frame(width: RingGaugeGeometry.displayDiameter, height: RingGaugeGeometry.displayDiameter)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }
}

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
}

private struct RingGaugeRepresentable: NSViewRepresentable, Equatable {
    let value: Double
    let color: LayerColorComponents

    func makeNSView(context: Context) -> RingGaugeHostingView {
        RingGaugeHostingView()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: RingGaugeHostingView,
        context: Context
    ) -> CGSize? {
        CGSize(width: RingGaugeGeometry.displayDiameter, height: RingGaugeGeometry.displayDiameter)
    }

    func updateNSView(_ nsView: RingGaugeHostingView, context: Context) {
        nsView.update(
            value: value,
            style: RingGaugeStyle(
                color: color,
                displayScale: context.environment.displayScale
            )
        )
    }
}

#Preview {
    RingGaugeView(
        value: 0.72,
        color: .warning,
        accessibilityLabel: "CPU gauge",
        accessibilityValue: "72.0%"
    )
        .padding()
}
