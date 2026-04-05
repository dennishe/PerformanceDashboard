import SwiftUI
import AppKit

enum SparklineGeometry {
    static let displayHeight: CGFloat = 38
}

/// Reusable sparkline rendered with layers so updates only change vector paths.
struct SparklineView: View {
    let history: [Double]
    let color: LayerColorComponents
    let accessibilityLabel: String
    let accessibilityValue: String

    var body: some View {
        SparklineRepresentable(history: history, color: color)
            .equatable()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }
}

private struct SparklineRepresentable: NSViewRepresentable, Equatable {
    let history: [Double]
    let color: LayerColorComponents

    func makeNSView(context: Context) -> SparklineHostingView {
        SparklineHostingView()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: SparklineHostingView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? nsView.bounds.width
        return CGSize(width: width, height: proposal.height ?? SparklineGeometry.displayHeight)
    }

    func updateNSView(_ nsView: SparklineHostingView, context: Context) {
        nsView.update(
            history: history,
            style: SparklineStyle(
                color: color,
                displayScale: context.environment.displayScale
            )
        )
    }
}

#Preview {
    SparklineView(
        history: (0..<60).map { _ in Double.random(in: 0...1) },
        color: .normal,
        accessibilityLabel: "CPU history",
        accessibilityValue: "42.0%"
    )
        .frame(width: 200, height: 60)
        .padding()
}
